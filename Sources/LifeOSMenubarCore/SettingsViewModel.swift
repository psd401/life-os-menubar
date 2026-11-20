import Combine
import Foundation

public enum TokenValidationState: Equatable, Sendable {
  case idle
  case validating
  case valid(login: String)
  case invalid(message: String)
}

/// Where a device-flow sign-in has got to. `awaitingApproval` is the only state
/// that carries anything the user has to act on: the code to type.
public enum DeviceFlowState: Equatable, Sendable {
  case idle
  case requestingCode
  case awaitingApproval(DeviceAuthorization)
  case failed(message: String)
}

public enum TaskRepositoryState: Equatable, Sendable {
  case idle
  case validating
  case valid(slug: String)
  case invalid(message: String)
}

@MainActor
public final class SettingsViewModel: ObservableObject {
  @Published public var token: String
  @Published public private(set) var validationState: TokenValidationState = .idle
  @Published public var repositorySlug: String
  @Published public private(set) var repositoryState: TaskRepositoryState = .idle
  @Published public private(set) var isRepositoryConfigured: Bool
  @Published public private(set) var isLaunchAtLoginEnabled: Bool
  @Published public private(set) var menuBarCount: MenuBarCount
  @Published public private(set) var persistenceError: String?
  @Published public private(set) var launchAtLoginError: String?
  @Published public private(set) var badgePreferenceError: String?
  @Published public private(set) var deviceFlowState: DeviceFlowState = .idle
  /// True once GitHub has refused to renew the stored credential. Only a new
  /// sign-in, a saved token, or signing out ends it.
  @Published public private(set) var isSignInExpired = false

  /// How early an expiring access token is renewed. It is longer than the
  /// five-minute background refresh, so while the app is awake the background
  /// loop renews the token before any request can find it expired.
  public static let accessTokenRefreshMargin: TimeInterval = 15 * 60

  private let tokenStore: any TokenStoring
  private let validator: any GitHubTokenValidating
  private let launchAtLoginController: any LaunchAtLoginControlling
  private let badgePreferenceStore: any MenuBarCountPreferenceStoring
  private let deviceFlow: any DeviceFlowAuthorizing
  private let tokenRefresher: any GitHubTokenRefreshing
  private let now: @Sendable () -> Date
  private let verificationPageOpener: @MainActor @Sendable (URL) -> Void
  private let onSignOut: @MainActor () -> Void
  private let repositoryStore: any TaskRepositoryStoring
  private let repositoryValidator: any TaskRepositoryValidating
  private let onRepositoryChange: @MainActor (TaskRepository?) -> Void
  private var validationGeneration = 0
  private var deviceFlowGeneration = 0
  private var repositoryValidationGeneration = 0
  /// What the Keychain holds. `token` mirrors its access token, except while
  /// the user types a replacement into the advanced field.
  private var credential: GitHubCredential?
  /// Bumped whenever the stored credential is replaced or removed, so a
  /// refresh started for the old one cannot write its result over the new.
  private var credentialGeneration = 0
  private var credentialRefresh: Task<Void, Never>?

  public init(
    tokenStore: any TokenStoring,
    validator: any GitHubTokenValidating,
    launchAtLoginController: any LaunchAtLoginControlling,
    badgePreferenceStore: any MenuBarCountPreferenceStoring =
      UserDefaultsMenuBarCountPreferenceStore(),
    deviceFlow: any DeviceFlowAuthorizing = GitHubDeviceFlowAuthorizer(),
    tokenRefresher: any GitHubTokenRefreshing = GitHubDeviceFlowAuthorizer(),
    now: @escaping @Sendable () -> Date = Date.init,
    // Opening a URL is AppKit's job, and Core has no AppKit, so the app target
    // injects the opener.
    verificationPageOpener: @escaping @MainActor @Sendable (URL) -> Void = { _ in },
    // Signing out has to reach beyond this view model: tasks synced by the
    // account being signed out of must not stay on screen or on disk. The
    // composition root wires this to the task list.
    onSignOut: @escaping @MainActor () -> Void = {},
    repositoryStore: any TaskRepositoryStoring = UserDefaultsTaskRepositoryStore(),
    repositoryValidator: any TaskRepositoryValidating = TaskRepositoryValidator(),
    onRepositoryChange: @escaping @MainActor (TaskRepository?) -> Void = { _ in }
  ) {
    self.tokenStore = tokenStore
    self.validator = validator
    self.launchAtLoginController = launchAtLoginController
    self.badgePreferenceStore = badgePreferenceStore
    self.deviceFlow = deviceFlow
    self.tokenRefresher = tokenRefresher
    self.now = now
    self.verificationPageOpener = verificationPageOpener
    self.onSignOut = onSignOut
    self.repositoryStore = repositoryStore
    self.repositoryValidator = repositoryValidator
    self.onRepositoryChange = onRepositoryChange
    self.isLaunchAtLoginEnabled = launchAtLoginController.isEnabled

    do {
      let storedCredential = try tokenStore.loadCredential()
      self.credential = storedCredential
      self.token = storedCredential?.accessToken ?? ""
    } catch {
      self.token = ""
      self.persistenceError = error.localizedDescription
    }

    do {
      self.menuBarCount = try badgePreferenceStore.loadCount()
    } catch {
      self.menuBarCount = .today
      self.badgePreferenceError = error.localizedDescription
    }

    let configuredRepository = try? repositoryStore.loadRepository()
    self.repositorySlug = configuredRepository?.slug ?? ""
    self.isRepositoryConfigured = configuredRepository != nil
  }

  /// True while a credential is stored, whichever path produced it — including a
  /// v1 personal access token saved by an earlier version of the app.
  public var isSignedIn: Bool {
    !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// False when this build has no OAuth App client ID.
  public var isDeviceFlowAvailable: Bool {
    deviceFlow.isAvailable
  }

  /// What to tell the user when sign-in is unavailable, or nil when it is not.
  public var deviceFlowUnavailableReason: String? {
    isDeviceFlowAvailable ? nil : DeviceFlowError.clientIDMissing.localizedDescription
  }

  /// Runs a whole device-flow sign-in: get a code, send the user to GitHub,
  /// wait for the grant, then store and validate the token.
  ///
  /// Cancel it by cancelling the task that called it; that returns the view
  /// model to `.idle` rather than reporting a failure. A later attempt wins:
  /// an earlier one that is still unwinding cannot write state back over it.
  public func signInWithDeviceFlow() async {
    guard isDeviceFlowAvailable else {
      deviceFlowState = .failed(message: DeviceFlowError.clientIDMissing.localizedDescription)
      return
    }

    deviceFlowGeneration += 1
    let generation = deviceFlowGeneration

    deviceFlowState = .requestingCode
    do {
      let authorization = try await deviceFlow.requestAuthorization()
      guard generation == deviceFlowGeneration else {
        return
      }
      deviceFlowState = .awaitingApproval(authorization)
      verificationPageOpener(authorization.verificationURL)

      let grant = try await deviceFlow.waitForAccessToken(authorization: authorization)
      guard generation == deviceFlowGeneration else {
        return
      }

      // The whole grant is stored, refresh token included: with token
      // expiration on, the access token alone stops working after 8 hours.
      guard store(grant.credential(issuedAt: now())) else {
        // The Keychain write failed, so nothing was stored and the previous
        // credential is still the one in use.
        deviceFlowState = .failed(
          message: persistenceError ?? DeviceFlowError.invalidResponse.localizedDescription
        )
        return
      }

      deviceFlowState = .idle
      await validateToken()
    } catch {
      guard generation == deviceFlowGeneration else {
        return
      }
      if Self.isCancellation(error) {
        deviceFlowState = .idle
      } else {
        deviceFlowState = .failed(message: error.localizedDescription)
      }
    }
  }

  /// Cancelling a task mid-flight throws `CancellationError` out of
  /// `Task.sleep`, but `URLSession` cancels its own task and throws
  /// `URLError.cancelled` instead. Both mean "the user abandoned this attempt",
  /// and neither should be shown as a failure.
  private static func isCancellation(_ error: any Error) -> Bool {
    if error is CancellationError {
      return true
    }
    return (error as? URLError)?.code == .cancelled
  }

  /// Validates whatever credential is already stored so Settings can show the
  /// signed-in login without the user retyping anything.
  public func refreshSignInState() async {
    guard isSignedIn else {
      return
    }
    await refreshCredentialIfNeeded()
    // Validating a token GitHub would not renew only replaces "sign in again"
    // with a vaguer "GitHub rejected this token".
    guard !isSignInExpired else {
      return
    }
    await validateToken()
  }

  /// Saves the token typed into the advanced field. A pasted token is a
  /// personal access token: no refresh token comes with it, and the app does
  /// not know when it expires.
  @discardableResult
  public func saveToken() -> Bool {
    let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedToken.isEmpty else {
      persistenceError = GitHubTokenValidationError.emptyToken.localizedDescription
      return false
    }
    return store(GitHubCredential(accessToken: trimmedToken))
  }

  /// Replaces the stored credential. Both sign-in paths end here.
  private func store(_ newCredential: GitHubCredential) -> Bool {
    do {
      try tokenStore.saveCredential(newCredential)
    } catch {
      persistenceError = error.localizedDescription
      return false
    }
    credentialGeneration += 1
    credential = newCredential
    token = newCredential.accessToken
    isSignInExpired = false
    persistenceError = nil
    validationState = .idle
    return true
  }

  // MARK: - Expiring tokens

  /// The access token to send to GitHub now: the stored one, renewed first if
  /// it expires within `accessTokenRefreshMargin`. Empty when signed out.
  ///
  /// Every request path goes through this rather than reading `token`, which
  /// can hold an unsaved draft from the advanced field.
  public func freshAccessToken() async -> String {
    await refreshCredentialIfNeeded()
    return credential?.accessToken ?? ""
  }

  /// Renews the stored credential if it is about to expire.
  ///
  /// One refresh at a time: a refresh token works once, so a second request
  /// spending it concurrently would be refused and read as an expired
  /// sign-in. Callers that arrive mid-refresh wait for that one.
  public func refreshCredentialIfNeeded() async {
    if let credentialRefresh {
      await credentialRefresh.value
      return
    }
    guard
      !isSignInExpired,
      let expiring = credential,
      expiring.needsRefresh(at: now(), margin: Self.accessTokenRefreshMargin)
    else {
      return
    }

    // Unstructured, so cancelling a caller cannot abandon a refresh GitHub has
    // already answered: its new pair has to be stored either way.
    let refresh = Task {
      await renew(expiring, generation: credentialGeneration)
    }
    credentialRefresh = refresh
    await refresh.value
    credentialRefresh = nil
  }

  private func renew(_ expiring: GitHubCredential, generation: Int) async {
    // A sign-out or new sign-in can land between scheduling this and running it.
    guard generation == credentialGeneration else {
      return
    }
    var expiring = expiring
    // An installed build and a development build share this Keychain item.
    // If the other copy renewed first, its refresh token has already spent
    // this one, so use what it stored instead of asking GitHub again. Tokens,
    // not whole credentials, are compared: a stored expiry can differ from the
    // in-memory one by a rounding step without meaning anything changed.
    if let stored = try? tokenStore.loadCredential(),
      stored.accessToken != expiring.accessToken
    {
      adopt(stored)
      guard stored.needsRefresh(at: now(), margin: Self.accessTokenRefreshMargin) else {
        return
      }
      expiring = stored
    }
    guard let refreshToken = expiring.refreshToken else {
      return
    }

    do {
      let grant = try await tokenRefresher.refreshAccessToken(refreshToken: refreshToken)
      guard generation == credentialGeneration else {
        return
      }
      let renewed = grant.credential(issuedAt: now())
      do {
        try tokenStore.saveCredential(renewed)
      } catch {
        // GitHub retired the old pair when it issued this one, so the new
        // token is used regardless; only the next launch is affected.
        persistenceError = error.localizedDescription
      }
      adopt(renewed)
    } catch {
      guard generation == credentialGeneration else {
        return
      }
      // Offline, or GitHub failing: keep the credential and try on the next
      // request. Only GitHub refusing the refresh token ends the sign-in.
      guard Self.isRefusal(error) else {
        return
      }
      // Two copies of the app that spend one refresh token within a round
      // trip: GitHub refuses the second, but the first has already stored a
      // valid pair. Adopt it rather than report an expired sign-in.
      if let stored = try? tokenStore.loadCredential(),
        stored.accessToken != expiring.accessToken
      {
        adopt(stored)
        return
      }
      isSignInExpired = true
      validationState = .invalid(message: error.localizedDescription)
    }
  }

  /// Makes `newCredential` the one in use. The advanced field follows it only
  /// if it was showing the previous token, so a half-typed replacement is
  /// never overwritten.
  private func adopt(_ newCredential: GitHubCredential) {
    if token.trimmingCharacters(in: .whitespacesAndNewlines) == (credential?.accessToken ?? "") {
      token = newCredential.accessToken
    }
    credential = newCredential
  }

  /// True when GitHub answered the refresh with an OAuth error, such as
  /// `bad_refresh_token`, rather than failing to answer at all.
  private static func isRefusal(_ error: any Error) -> Bool {
    switch error as? DeviceFlowError {
    case nil, .requestFailed, .invalidResponse:
      false
    case .some:
      true
    }
  }

  public func saveAndValidateToken() async {
    guard saveToken() else {
      return
    }
    await validateToken()
  }

  public func validateToken() async {
    validationGeneration += 1
    let generation = validationGeneration
    let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else {
      validationState = .invalid(
        message: GitHubTokenValidationError.emptyToken.localizedDescription
      )
      return
    }

    validationState = .validating
    do {
      let login = try await validator.validate(token: candidate)
      guard isResultStillWanted(generation: generation, candidate: candidate) else {
        return
      }
      validationState = .valid(login: login)
    } catch {
      guard isResultStillWanted(generation: generation, candidate: candidate) else {
        return
      }
      validationState = .invalid(message: error.localizedDescription)
    }
  }

  /// Whether a finished validation may still write its result.
  ///
  /// A newer validation supersedes this one and will set the state itself. But
  /// if the token text simply changed underneath with no newer validation
  /// running, nobody else will clear `.validating`, and the spinner would spin
  /// for the rest of the session — so that case resets the state here.
  private func isResultStillWanted(generation: Int, candidate: String) -> Bool {
    guard generation == validationGeneration else {
      return false
    }
    guard token.trimmingCharacters(in: .whitespacesAndNewlines) == candidate else {
      validationState = .idle
      return false
    }
    return true
  }

  /// Signs out by removing the Keychain item. Both sign-in paths end here.
  ///
  /// Any sign-in still in flight is abandoned (its generation is stale), and
  /// `onSignOut` clears the tasks the signed-out account synced — leaving them
  /// on screen after a sign-out, or showing them to whoever signs in next,
  /// would be a data leak on a shared Mac.
  public func signOut() {
    deviceFlowGeneration += 1
    validationGeneration += 1
    do {
      try tokenStore.deleteCredential()
      credentialGeneration += 1
      credential = nil
      token = ""
      isSignInExpired = false
      validationState = .idle
      deviceFlowState = .idle
      persistenceError = nil
      onSignOut()
    } catch {
      persistenceError = error.localizedDescription
    }
  }

  /// Validates the typed `owner/repo` against GitHub and saves it only if the
  /// repo exists, the token can read it, and every required label definition is
  /// already there. A repo that fails any of those is never written to the
  /// store, so the app cannot start syncing against something it will misread —
  /// see [decision 0005](../../openwiki/decisions/0005-configurable-task-repo.md).
  public func saveAndValidateRepository() async {
    repositoryValidationGeneration += 1
    let generation = repositoryValidationGeneration

    let candidate: TaskRepository
    do {
      candidate = try TaskRepository.parse(repositorySlug)
    } catch {
      repositoryState = .invalid(message: error.localizedDescription)
      return
    }

    let candidateToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidateToken.isEmpty else {
      repositoryState = .invalid(
        message: TaskRepositoryValidationError.emptyToken.localizedDescription
      )
      return
    }

    repositoryState = .validating
    let report: TaskRepositoryValidationReport
    do {
      report = try await repositoryValidator.validate(
        token: candidateToken,
        repository: candidate
      )
    } catch {
      guard generation == repositoryValidationGeneration else {
        return
      }
      repositoryState = .invalid(message: error.localizedDescription)
      return
    }

    guard generation == repositoryValidationGeneration else {
      return
    }
    guard report.isConforming else {
      repositoryState = .invalid(message: Self.missingLabelsMessage(report.missingLabels))
      return
    }

    do {
      try repositoryStore.saveRepository(candidate)
    } catch {
      repositoryState = .invalid(message: error.localizedDescription)
      return
    }

    repositorySlug = candidate.slug
    isRepositoryConfigured = true
    repositoryState = .valid(slug: candidate.slug)
    onRepositoryChange(candidate)
  }

  public func clearRepository() {
    do {
      try repositoryStore.clearRepository()
    } catch {
      repositoryState = .invalid(message: error.localizedDescription)
      return
    }

    repositoryValidationGeneration += 1
    repositorySlug = ""
    isRepositoryConfigured = false
    repositoryState = .idle
    onRepositoryChange(nil)
  }

  private static func missingLabelsMessage(_ missingLabels: [String]) -> String {
    "This repository is missing \(missingLabels.count) required "
      + (missingLabels.count == 1 ? "label" : "labels")
      + ": \(missingLabels.joined(separator: ", ")). "
      + "Run the bootstrap in docs/life-os-repo-standard.md, then validate again."
  }

  public func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
    do {
      try launchAtLoginController.setEnabled(isEnabled)
      isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
      launchAtLoginError = nil
    } catch {
      isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
      launchAtLoginError = error.localizedDescription
    }
  }

  public func setMenuBarCount(_ count: MenuBarCount) {
    do {
      try badgePreferenceStore.saveCount(count)
      menuBarCount = count
      badgePreferenceError = nil
    } catch {
      badgePreferenceError = error.localizedDescription
    }
  }
}
