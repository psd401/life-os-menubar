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

@MainActor
public final class SettingsViewModel: ObservableObject {
  @Published public var token: String
  @Published public private(set) var validationState: TokenValidationState = .idle
  @Published public private(set) var isLaunchAtLoginEnabled: Bool
  @Published public private(set) var isTodayBadgeEnabled: Bool
  @Published public private(set) var persistenceError: String?
  @Published public private(set) var launchAtLoginError: String?
  @Published public private(set) var badgePreferenceError: String?
  @Published public private(set) var deviceFlowState: DeviceFlowState = .idle

  private let tokenStore: any TokenStoring
  private let validator: any GitHubTokenValidating
  private let launchAtLoginController: any LaunchAtLoginControlling
  private let badgePreferenceStore: any TodayBadgePreferenceStoring
  private let deviceFlow: any DeviceFlowAuthorizing
  private let verificationPageOpener: @MainActor @Sendable (URL) -> Void
  private let onSignOut: @MainActor () -> Void
  private var validationGeneration = 0
  private var deviceFlowGeneration = 0

  public init(
    tokenStore: any TokenStoring,
    validator: any GitHubTokenValidating,
    launchAtLoginController: any LaunchAtLoginControlling,
    badgePreferenceStore: any TodayBadgePreferenceStoring =
      UserDefaultsTodayBadgePreferenceStore(),
    deviceFlow: any DeviceFlowAuthorizing = GitHubDeviceFlowAuthorizer(),
    // Opening a URL is AppKit's job, and Core has no AppKit, so the app target
    // injects the opener.
    verificationPageOpener: @escaping @MainActor @Sendable (URL) -> Void = { _ in },
    // Signing out has to reach beyond this view model: tasks synced by the
    // account being signed out of must not stay on screen or on disk. The
    // composition root wires this to the task list.
    onSignOut: @escaping @MainActor () -> Void = {}
  ) {
    self.tokenStore = tokenStore
    self.validator = validator
    self.launchAtLoginController = launchAtLoginController
    self.badgePreferenceStore = badgePreferenceStore
    self.deviceFlow = deviceFlow
    self.verificationPageOpener = verificationPageOpener
    self.onSignOut = onSignOut
    self.isLaunchAtLoginEnabled = launchAtLoginController.isEnabled

    do {
      self.token = try tokenStore.loadToken() ?? ""
    } catch {
      self.token = ""
      self.persistenceError = error.localizedDescription
    }

    do {
      self.isTodayBadgeEnabled = try badgePreferenceStore.loadIsEnabled()
    } catch {
      self.isTodayBadgeEnabled = true
      self.badgePreferenceError = error.localizedDescription
    }
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
    // Captured now, not after the wait: the advanced field writes to `token`
    // too, so reading it minutes later could pick up a half-typed draft and
    // then "restore" that instead of the real previous credential.
    let tokenBeforeSignIn = token

    deviceFlowState = .requestingCode
    do {
      let authorization = try await deviceFlow.requestAuthorization()
      guard generation == deviceFlowGeneration else {
        return
      }
      deviceFlowState = .awaitingApproval(authorization)
      verificationPageOpener(authorization.verificationURL)

      let issuedToken = try await deviceFlow.waitForAccessToken(authorization: authorization)
      guard generation == deviceFlowGeneration else {
        return
      }

      token = issuedToken
      guard saveToken() else {
        // The Keychain write failed, so nothing was stored: put back the
        // credential this attempt started from rather than leaving the field
        // holding a token the app cannot persist.
        token = tokenBeforeSignIn
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
    await validateToken()
  }

  @discardableResult
  public func saveToken() -> Bool {
    let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedToken.isEmpty else {
      persistenceError = GitHubTokenValidationError.emptyToken.localizedDescription
      return false
    }

    do {
      try tokenStore.saveToken(trimmedToken)
      token = trimmedToken
      persistenceError = nil
      validationState = .idle
      return true
    } catch {
      persistenceError = error.localizedDescription
      return false
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
      try tokenStore.deleteToken()
      token = ""
      validationState = .idle
      deviceFlowState = .idle
      persistenceError = nil
      onSignOut()
    } catch {
      persistenceError = error.localizedDescription
    }
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

  public func setTodayBadgeEnabled(_ isEnabled: Bool) {
    do {
      try badgePreferenceStore.saveIsEnabled(isEnabled)
      isTodayBadgeEnabled = isEnabled
      badgePreferenceError = nil
    } catch {
      badgePreferenceError = error.localizedDescription
    }
  }
}
