import Foundation
import Testing

@testable import LifeOSMenubarCore

@MainActor
struct SettingsViewModelTests {
  @Test
  func loadsTokenAndLaunchAtLoginState() {
    let tokenStore = TokenStoreSpy(storedToken: "saved-token")
    let launchController = LaunchAtLoginControllerSpy(isEnabled: true)

    let viewModel = makeViewModel(
      tokenStore: tokenStore,
      launchController: launchController
    )

    #expect(viewModel.token == "saved-token")
    #expect(viewModel.isLaunchAtLoginEnabled)
  }

  @Test
  func saveDelegatesTokenPersistenceExclusivelyToTokenStore() {
    let tokenStore = TokenStoreSpy()
    let launchController = LaunchAtLoginControllerSpy()
    let viewModel = makeViewModel(
      tokenStore: tokenStore,
      launchController: launchController
    )

    viewModel.token = "  new-token  "
    let didSave = viewModel.saveToken()

    #expect(didSave)
    #expect(tokenStore.savedTokens == ["new-token"])
  }

  @Test
  func saveAndValidateReportsAuthenticatedLogin() async {
    let tokenStore = TokenStoreSpy()
    let validator = TokenValidatorStub(result: .success("octocat"))
    let viewModel = makeViewModel(
      tokenStore: tokenStore,
      validator: validator
    )
    viewModel.token = "valid-token"

    await viewModel.saveAndValidateToken()

    #expect(viewModel.validationState == .valid(login: "octocat"))
    #expect(tokenStore.savedTokens == ["valid-token"])
  }

  @Test
  func olderValidationCannotOverwriteNewerResult() async {
    let validator = ControlledTokenValidator()
    let viewModel = makeViewModel(validator: validator)

    viewModel.token = "first-token"
    let firstValidation = Task { @MainActor in
      await viewModel.validateToken()
    }
    await validator.waitUntilPending(token: "first-token")

    viewModel.token = "second-token"
    let secondValidation = Task { @MainActor in
      await viewModel.validateToken()
    }
    await validator.waitUntilPending(token: "second-token")

    await validator.succeed(token: "second-token", login: "newest-result")
    await secondValidation.value
    #expect(viewModel.validationState == .valid(login: "newest-result"))

    await validator.succeed(token: "first-token", login: "stale-result")
    await firstValidation.value
    #expect(viewModel.validationState == .valid(login: "newest-result"))
  }

  @Test
  func signOutDeletesKeychainTokenAndResetsValidation() async {
    let tokenStore = TokenStoreSpy(storedToken: "saved-token")
    let validator = TokenValidatorStub(result: .success("octocat"))
    let viewModel = makeViewModel(
      tokenStore: tokenStore,
      validator: validator
    )
    await viewModel.validateToken()
    #expect(viewModel.validationState == .valid(login: "octocat"))
    #expect(viewModel.isSignedIn)

    viewModel.signOut()

    #expect(tokenStore.deleteCallCount == 1)
    #expect(viewModel.token.isEmpty)
    #expect(viewModel.validationState == .idle)
    #expect(viewModel.deviceFlowState == .idle)
    #expect(!viewModel.isSignedIn)
  }

  @Test
  func deviceFlowSignInKeepsTheTokenOnlyInTheKeychainAndReportsTheLogin() async {
    // A value unlikely to collide with anything already in the shared defaults,
    // so the "no other persistence" assertion below means something.
    let issuedToken = "gho_device_flow_only_in_keychain_18"
    let tokenStore = TokenStoreSpy()
    let authorizer = DeviceFlowAuthorizerStub(tokenResult: .success(issuedToken))
    let viewModel = makeViewModel(
      tokenStore: tokenStore,
      validator: TokenValidatorStub(result: .success("octocat")),
      deviceFlow: authorizer
    )

    await viewModel.signInWithDeviceFlow()

    #expect(viewModel.token == issuedToken)
    #expect(tokenStore.savedTokens == [issuedToken])
    #expect(viewModel.validationState == .valid(login: "octocat"))
    #expect(viewModel.deviceFlowState == .idle)
    // The Keychain store is the only persistence path: nothing reached the
    // user defaults the app otherwise writes preferences to.
    #expect(!userDefaultsHoldsAnyValue(containing: issuedToken))
  }

  @Test
  func deviceFlowPublishesTheUserCodeAndOpensTheVerificationPage() async {
    let authorizer = ControlledDeviceFlowAuthorizer()
    let opener = VerificationPageOpenerSpy()
    let viewModel = makeViewModel(
      deviceFlow: authorizer,
      verificationPageOpener: { url in
        opener.record(url)
      }
    )

    let signIn = Task { @MainActor in
      await viewModel.signInWithDeviceFlow()
    }
    await authorizer.waitUntilPolling()

    #expect(
      viewModel.deviceFlowState == .awaitingApproval(ControlledDeviceFlowAuthorizer.authorization))
    #expect(opener.openedURLs == [ControlledDeviceFlowAuthorizer.authorization.verificationURL])

    await authorizer.finish(.success("gho_test"))
    await signIn.value

    #expect(viewModel.deviceFlowState == .idle)
  }

  @Test
  func deviceFlowFailureSurfacesTheErrorAndLeavesTheStoredTokenAlone() async {
    let tokenStore = TokenStoreSpy(storedToken: "legacy-token")
    let authorizer = DeviceFlowAuthorizerStub(tokenResult: .failure(DeviceFlowError.accessDenied))
    let viewModel = makeViewModel(tokenStore: tokenStore, deviceFlow: authorizer)

    await viewModel.signInWithDeviceFlow()

    #expect(
      viewModel.deviceFlowState
        == .failed(message: DeviceFlowError.accessDenied.localizedDescription)
    )
    // Retryable: a failed attempt leaves the previous credential in place.
    #expect(tokenStore.savedTokens.isEmpty)
    #expect(tokenStore.deleteCallCount == 0)
    #expect(viewModel.token == "legacy-token")
  }

  @Test
  func cancellingDeviceFlowReturnsToIdleRatherThanShowingAnError() async {
    let authorizer = DeviceFlowAuthorizerStub(tokenResult: .failure(CancellationError()))
    let viewModel = makeViewModel(deviceFlow: authorizer)

    await viewModel.signInWithDeviceFlow()

    #expect(viewModel.deviceFlowState == .idle)
  }

  @Test
  func deviceFlowIsUnavailableWithoutAnOAuthClientIDWhileTokenEntryStillWorks() async {
    let tokenStore = TokenStoreSpy()
    let authorizer = DeviceFlowAuthorizerStub(
      isAvailable: false,
      tokenResult: .success("never-issued")
    )
    let viewModel = makeViewModel(tokenStore: tokenStore, deviceFlow: authorizer)

    #expect(!viewModel.isDeviceFlowAvailable)
    #expect(viewModel.deviceFlowUnavailableReason != nil)

    await viewModel.signInWithDeviceFlow()

    #expect(
      viewModel.deviceFlowState
        == .failed(message: DeviceFlowError.clientIDMissing.localizedDescription)
    )
    #expect(await authorizer.authorizationRequestCount == 0)

    // The advanced path is unaffected.
    viewModel.token = "fine-grained-token"
    await viewModel.saveAndValidateToken()

    #expect(tokenStore.savedTokens == ["fine-grained-token"])
    #expect(viewModel.validationState == .valid(login: "octocat"))
  }

  @Test
  func aLegacyStoredTokenStaysSignedInWithoutAnyDeviceFlowCall() async {
    let authorizer = DeviceFlowAuthorizerStub(tokenResult: .success("never-issued"))
    let viewModel = makeViewModel(
      tokenStore: TokenStoreSpy(storedToken: "ghp_legacy_v1_pat"),
      validator: TokenValidatorStub(result: .success("octocat")),
      deviceFlow: authorizer
    )

    #expect(viewModel.isSignedIn)
    #expect(viewModel.token == "ghp_legacy_v1_pat")

    await viewModel.refreshSignInState()

    #expect(viewModel.validationState == .valid(login: "octocat"))
    #expect(await authorizer.authorizationRequestCount == 0)
  }

  @Test
  func refreshSignInStateStaysIdleWhenNoTokenIsStored() async {
    let viewModel = makeViewModel()

    await viewModel.refreshSignInState()

    #expect(viewModel.validationState == .idle)
    #expect(!viewModel.isSignedIn)
  }

  @Test
  func launchAtLoginToggleReflectsServiceState() {
    let launchController = LaunchAtLoginControllerSpy()
    let viewModel = makeViewModel(launchController: launchController)

    viewModel.setLaunchAtLoginEnabled(true)

    #expect(launchController.requestedStates == [true])
    #expect(viewModel.isLaunchAtLoginEnabled)
  }

  @Test
  func loadsAndPersistsTodayBadgePreference() {
    let badgeStore = BadgePreferenceStoreSpy(isEnabled: false)
    let viewModel = makeViewModel(badgeStore: badgeStore)

    #expect(!viewModel.isTodayBadgeEnabled)

    viewModel.setTodayBadgeEnabled(true)

    #expect(viewModel.isTodayBadgeEnabled)
    #expect(badgeStore.savedValues == [true])
  }

  private func makeViewModel(
    tokenStore: TokenStoreSpy = TokenStoreSpy(),
    validator: any GitHubTokenValidating = TokenValidatorStub(result: .success("octocat")),
    launchController: LaunchAtLoginControllerSpy = LaunchAtLoginControllerSpy(),
    badgeStore: BadgePreferenceStoreSpy = BadgePreferenceStoreSpy(),
    deviceFlow: any DeviceFlowAuthorizing = DeviceFlowAuthorizerStub(
      tokenResult: .success("gho_test")
    ),
    verificationPageOpener: @escaping (URL) -> Void = { _ in }
  ) -> SettingsViewModel {
    SettingsViewModel(
      tokenStore: tokenStore,
      validator: validator,
      launchAtLoginController: launchController,
      badgePreferenceStore: badgeStore,
      deviceFlow: deviceFlow,
      verificationPageOpener: verificationPageOpener
    )
  }

  /// True when any value in the shared user defaults mentions `token`. The
  /// Keychain-only rule is only meaningful if something checks the obvious
  /// alternative, and the app does write other preferences there.
  private func userDefaultsHoldsAnyValue(containing token: String) -> Bool {
    UserDefaults.standard.dictionaryRepresentation().values.contains { value in
      String(describing: value).contains(token)
    }
  }
}

@MainActor
private final class VerificationPageOpenerSpy {
  private(set) var openedURLs: [URL] = []

  func record(_ url: URL) {
    openedURLs.append(url)
  }
}

private actor DeviceFlowAuthorizerStub: DeviceFlowAuthorizing {
  private let available: Bool
  private let tokenResult: Result<String, any Error>
  private(set) var authorizationRequestCount = 0

  init(isAvailable: Bool = true, tokenResult: Result<String, any Error>) {
    self.available = isAvailable
    self.tokenResult = tokenResult
  }

  nonisolated var isAvailable: Bool {
    available
  }

  func requestAuthorization() async throws -> DeviceAuthorization {
    authorizationRequestCount += 1
    return ControlledDeviceFlowAuthorizer.authorization
  }

  func waitForAccessToken(authorization: DeviceAuthorization) async throws -> String {
    try tokenResult.get()
  }
}

/// Suspends in `waitForAccessToken` so a test can inspect the view model while
/// the user is still approving the code on GitHub.
private actor ControlledDeviceFlowAuthorizer: DeviceFlowAuthorizing {
  static let authorization = DeviceAuthorization(
    deviceCode: "dc-1",
    userCode: "WDJB-MJHT",
    verificationURL: URL(string: "https://github.com/login/device")!,
    expiresInSeconds: 900,
    pollIntervalSeconds: 5
  )

  private var pending: CheckedContinuation<String, any Error>?
  private var pollingWaiters: [CheckedContinuation<Void, Never>] = []

  nonisolated var isAvailable: Bool {
    true
  }

  func requestAuthorization() async throws -> DeviceAuthorization {
    Self.authorization
  }

  func waitForAccessToken(authorization: DeviceAuthorization) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      pending = continuation
      for waiter in pollingWaiters {
        waiter.resume()
      }
      pollingWaiters.removeAll()
    }
  }

  func waitUntilPolling() async {
    guard pending == nil else {
      return
    }
    await withCheckedContinuation { continuation in
      pollingWaiters.append(continuation)
    }
  }

  func finish(_ result: Result<String, any Error>) {
    guard let continuation = pending else {
      preconditionFailure("No pending device-flow poll")
    }
    pending = nil
    continuation.resume(with: result)
  }
}

private final class TokenStoreSpy: TokenStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var storedToken: String?
  private var mutableSavedTokens: [String] = []
  private var mutableDeleteCallCount = 0

  init(storedToken: String? = nil) {
    self.storedToken = storedToken
  }

  var savedTokens: [String] {
    lock.withLock {
      mutableSavedTokens
    }
  }

  var deleteCallCount: Int {
    lock.withLock {
      mutableDeleteCallCount
    }
  }

  func loadToken() throws -> String? {
    lock.withLock {
      storedToken
    }
  }

  func saveToken(_ token: String) throws {
    lock.withLock {
      storedToken = token
      mutableSavedTokens.append(token)
    }
  }

  func deleteToken() throws {
    lock.withLock {
      storedToken = nil
      mutableDeleteCallCount += 1
    }
  }
}

private struct TokenValidatorStub: GitHubTokenValidating {
  let result: Result<String, ValidationStubError>

  func validate(token: String) async throws -> String {
    try result.get()
  }
}

private actor ControlledTokenValidator: GitHubTokenValidating {
  private var pendingValidations: [String: CheckedContinuation<String, any Error>] = [:]
  private var registrationWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

  func validate(token: String) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      pendingValidations[token] = continuation
      for waiter in registrationWaiters.removeValue(forKey: token) ?? [] {
        waiter.resume()
      }
    }
  }

  func waitUntilPending(token: String) async {
    guard pendingValidations[token] == nil else {
      return
    }

    await withCheckedContinuation { continuation in
      registrationWaiters[token, default: []].append(continuation)
    }
  }

  func succeed(token: String, login: String) {
    guard let continuation = pendingValidations.removeValue(forKey: token) else {
      preconditionFailure("No pending validation for \(token)")
    }
    continuation.resume(returning: login)
  }
}

private struct ValidationStubError: LocalizedError {
  var errorDescription: String? {
    "Validation failed."
  }
}

private final class BadgePreferenceStoreSpy: TodayBadgePreferenceStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var isEnabled: Bool
  private var mutableSavedValues: [Bool] = []

  init(isEnabled: Bool = true) {
    self.isEnabled = isEnabled
  }

  var savedValues: [Bool] {
    lock.withLock {
      mutableSavedValues
    }
  }

  func loadIsEnabled() throws -> Bool {
    lock.withLock {
      isEnabled
    }
  }

  func saveIsEnabled(_ isEnabled: Bool) throws {
    lock.withLock {
      self.isEnabled = isEnabled
      mutableSavedValues.append(isEnabled)
    }
  }
}

@MainActor
private final class LaunchAtLoginControllerSpy: LaunchAtLoginControlling {
  private(set) var isEnabled: Bool
  private(set) var requestedStates: [Bool] = []

  init(isEnabled: Bool = false) {
    self.isEnabled = isEnabled
  }

  func setEnabled(_ isEnabled: Bool) throws {
    requestedStates.append(isEnabled)
    self.isEnabled = isEnabled
  }
}
