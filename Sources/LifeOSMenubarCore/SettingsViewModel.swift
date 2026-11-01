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
  private let verificationPageOpener: (URL) -> Void
  private var validationGeneration = 0

  public init(
    tokenStore: any TokenStoring,
    validator: any GitHubTokenValidating,
    launchAtLoginController: any LaunchAtLoginControlling,
    badgePreferenceStore: any TodayBadgePreferenceStoring =
      UserDefaultsTodayBadgePreferenceStore(),
    deviceFlow: any DeviceFlowAuthorizing = GitHubDeviceFlowAuthorizer(),
    // Opening a URL is AppKit's job, and Core has no AppKit, so the app target
    // injects the opener.
    verificationPageOpener: @escaping (URL) -> Void = { _ in }
  ) {
    self.tokenStore = tokenStore
    self.validator = validator
    self.launchAtLoginController = launchAtLoginController
    self.badgePreferenceStore = badgePreferenceStore
    self.deviceFlow = deviceFlow
    self.verificationPageOpener = verificationPageOpener
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
  /// model to `.idle` rather than reporting a failure.
  public func signInWithDeviceFlow() async {
    guard isDeviceFlowAvailable else {
      deviceFlowState = .failed(message: DeviceFlowError.clientIDMissing.localizedDescription)
      return
    }

    deviceFlowState = .requestingCode
    do {
      let authorization = try await deviceFlow.requestAuthorization()
      deviceFlowState = .awaitingApproval(authorization)
      verificationPageOpener(authorization.verificationURL)

      let issuedToken = try await deviceFlow.waitForAccessToken(authorization: authorization)
      let previousToken = token
      token = issuedToken
      guard saveToken() else {
        // The Keychain write failed, so nothing was stored: put the previous
        // credential back rather than leaving the field holding a token the
        // app cannot persist.
        token = previousToken
        deviceFlowState = .failed(
          message: persistenceError ?? DeviceFlowError.invalidResponse.localizedDescription
        )
        return
      }

      deviceFlowState = .idle
      await validateToken()
    } catch is CancellationError {
      deviceFlowState = .idle
    } catch {
      deviceFlowState = .failed(message: error.localizedDescription)
    }
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
      persistenceError = "Enter a GitHub personal access token."
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
      validationState = .invalid(message: "Enter a GitHub personal access token.")
      return
    }

    validationState = .validating
    do {
      let login = try await validator.validate(token: candidate)
      guard generation == validationGeneration,
        token.trimmingCharacters(in: .whitespacesAndNewlines) == candidate
      else {
        return
      }
      validationState = .valid(login: login)
    } catch {
      guard generation == validationGeneration,
        token.trimmingCharacters(in: .whitespacesAndNewlines) == candidate
      else {
        return
      }
      validationState = .invalid(message: error.localizedDescription)
    }
  }

  /// Signs out by removing the Keychain item. Both sign-in paths end here.
  public func signOut() {
    do {
      try tokenStore.deleteToken()
      token = ""
      validationState = .idle
      deviceFlowState = .idle
      persistenceError = nil
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
