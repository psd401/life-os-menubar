import Foundation
import Security
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
  func aCancelledNetworkCallIsTreatedAsCancellationNotAFailure() async {
    // Cancelling a task mid-request makes URLSession throw URLError.cancelled,
    // not CancellationError, and the user should not see that as an error.
    let authorizer = DeviceFlowAuthorizerStub(
      tokenResult: .failure(URLError(.cancelled))
    )
    let viewModel = makeViewModel(deviceFlow: authorizer)

    await viewModel.signInWithDeviceFlow()

    #expect(viewModel.deviceFlowState == .idle)
  }

  @Test
  func aSignInThatLandsAfterSignOutIsDiscardedInsteadOfStoringItsToken() async {
    let tokenStore = TokenStoreSpy(storedToken: "saved-token")
    let authorizer = ControlledDeviceFlowAuthorizer()
    let viewModel = makeViewModel(tokenStore: tokenStore, deviceFlow: authorizer)

    let signIn = Task { @MainActor in
      await viewModel.signInWithDeviceFlow()
    }
    await authorizer.waitUntilPolling()

    // Signing out supersedes the attempt in flight.
    viewModel.signOut()
    #expect(viewModel.token.isEmpty)

    // GitHub approves anyway, a moment too late.
    await authorizer.finish(.success("gho_too_late"))
    await signIn.value

    // The stale result is dropped: no token stored, and the signed-out state
    // stands rather than being overwritten by a sign-in the user abandoned.
    #expect(tokenStore.savedTokens.isEmpty)
    #expect(viewModel.token.isEmpty)
    #expect(viewModel.deviceFlowState == .idle)
    #expect(!viewModel.isSignedIn)
  }

  @Test
  func aFailureThatLandsAfterSignOutDoesNotResurrectAnErrorBanner() async {
    let authorizer = ControlledDeviceFlowAuthorizer()
    let viewModel = makeViewModel(deviceFlow: authorizer)

    let signIn = Task { @MainActor in
      await viewModel.signInWithDeviceFlow()
    }
    await authorizer.waitUntilPolling()

    viewModel.signOut()
    await authorizer.finish(.failure(DeviceFlowError.accessDenied))
    await signIn.value

    #expect(viewModel.deviceFlowState == .idle)
  }

  @Test
  func aFailedKeychainWriteRestoresTheCredentialTheAttemptStartedFrom() async {
    let tokenStore = TokenStoreSpy(storedToken: "legacy-token", failsToSave: true)
    let authorizer = DeviceFlowAuthorizerStub(tokenResult: .success("gho_never_stored"))
    let viewModel = makeViewModel(tokenStore: tokenStore, deviceFlow: authorizer)

    await viewModel.signInWithDeviceFlow()

    #expect(tokenStore.savedTokens.isEmpty)
    #expect(viewModel.token == "legacy-token")
    if case .failed = viewModel.deviceFlowState {
    } else {
      Issue.record("Expected a failed device-flow state, got \(viewModel.deviceFlowState)")
    }
  }

  @Test
  func signOutClearsTheTasksSyncedByTheAccountBeingSignedOutOf() {
    let signOutSpy = SignOutSpy()
    let viewModel = makeViewModel(
      tokenStore: TokenStoreSpy(storedToken: "saved-token"),
      onSignOut: {
        signOutSpy.record()
      }
    )

    viewModel.signOut()

    #expect(signOutSpy.callCount == 1)
  }

  @Test
  func aFailedSignOutDoesNotClearTasksBecauseTheTokenIsStillStored() {
    let signOutSpy = SignOutSpy()
    let viewModel = makeViewModel(
      tokenStore: TokenStoreSpy(storedToken: "saved-token", failsToDelete: true),
      onSignOut: {
        signOutSpy.record()
      }
    )

    viewModel.signOut()

    #expect(signOutSpy.callCount == 0)
    #expect(viewModel.token == "saved-token")
    #expect(viewModel.persistenceError != nil)
  }

  @Test
  func anAbandonedValidationDoesNotLeaveTheSpinnerRunningForever() async {
    let validator = ControlledTokenValidator()
    let viewModel = makeViewModel(validator: validator)

    viewModel.token = "first-token"
    let validation = Task { @MainActor in
      await viewModel.validateToken()
    }
    await validator.waitUntilPending(token: "first-token")
    #expect(viewModel.validationState == .validating)

    // The user edits the field but does not validate again, so no newer
    // validation exists to replace this one's state.
    viewModel.token = "edited-token"
    await validator.succeed(token: "first-token", login: "stale-result")
    await validation.value

    #expect(viewModel.validationState == .idle)
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
  func loadsAndPersistsTheMenuBarCountChoice() {
    let badgeStore = BadgePreferenceStoreSpy(count: .off)
    let viewModel = makeViewModel(badgeStore: badgeStore)

    #expect(viewModel.menuBarCount == .off)

    viewModel.setMenuBarCount(.inbox)

    #expect(viewModel.menuBarCount == .inbox)
    #expect(badgeStore.savedValues == [.inbox])
  }

  // MARK: - Expiring tokens

  /// The clock every view model in this suite reads.
  nonisolated private static let now = Date(timeIntervalSince1970: 1_793_000_000)

  private static let renewedGrant = GitHubTokenGrant(
    accessToken: "gho_new",
    accessTokenLifetimeSeconds: 28_800,
    refreshToken: "ghr_new"
  )

  private static func expiringCredential(expiresIn seconds: TimeInterval) -> GitHubCredential {
    GitHubCredential(
      accessToken: "gho_old",
      accessTokenExpiresAt: now.addingTimeInterval(seconds),
      refreshToken: "ghr_old"
    )
  }

  @Test
  func deviceFlowSignInStoresTheRefreshTokenAndExpiryGitHubIssued() async {
    // The regression: sign-in kept only the access token, so eight hours
    // later GitHub rejected it and nothing could renew it.
    let tokenStore = TokenStoreSpy()
    let viewModel = makeViewModel(
      tokenStore: tokenStore,
      deviceFlow: DeviceFlowAuthorizerStub(
        grantResult: .success(
          GitHubTokenGrant(
            accessToken: "gho_issued",
            accessTokenLifetimeSeconds: 28_800,
            refreshToken: "ghr_issued"
          )
        )
      )
    )

    await viewModel.signInWithDeviceFlow()

    #expect(
      tokenStore.savedCredentials == [
        GitHubCredential(
          accessToken: "gho_issued",
          accessTokenExpiresAt: Self.now.addingTimeInterval(28_800),
          refreshToken: "ghr_issued"
        )
      ]
    )
    #expect(viewModel.token == "gho_issued")
  }

  @Test
  func anExpiringTokenIsRenewedBeforeUseAndTheRotatedPairIsStored() async {
    let tokenStore = TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: 300))
    let refresher = TokenRefresherStub([.success(Self.renewedGrant)])
    let viewModel = makeViewModel(tokenStore: tokenStore, tokenRefresher: refresher)

    let accessToken = await viewModel.freshAccessToken()

    #expect(accessToken == "gho_new")
    #expect(viewModel.token == "gho_new")
    #expect(viewModel.isSignedIn)
    #expect(await refresher.refreshedTokens == ["ghr_old"])
    #expect(tokenStore.savedCredentials == [Self.renewedGrant.credential(issuedAt: Self.now)])
  }

  @Test
  func aTokenWellBeforeExpiryIsUsedWithoutARefresh() async {
    let refresher = TokenRefresherStub()
    let viewModel = makeViewModel(
      tokenStore: TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: 7_200)),
      tokenRefresher: refresher
    )

    #expect(await viewModel.freshAccessToken() == "gho_old")
    #expect(await refresher.refreshedTokens.isEmpty)
  }

  @Test
  func aPastedPersonalAccessTokenIsNeverRefreshed() async {
    let refresher = TokenRefresherStub()
    let viewModel = makeViewModel(
      tokenStore: TokenStoreSpy(storedToken: "github_pat_fine_grained"),
      tokenRefresher: refresher
    )

    #expect(await viewModel.freshAccessToken() == "github_pat_fine_grained")
    #expect(await refresher.refreshedTokens.isEmpty)
  }

  @Test
  func concurrentRequestsShareOneRefreshBecauseARefreshTokenWorksOnlyOnce() async {
    let refresher = ControlledTokenRefresher()
    let viewModel = makeViewModel(
      tokenStore: TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: 60)),
      tokenRefresher: refresher
    )

    let first = Task { @MainActor in
      await viewModel.freshAccessToken()
    }
    await refresher.waitUntilPending()
    let second = Task { @MainActor in
      await viewModel.freshAccessToken()
    }
    // Let the second request reach the refresh before the first one ends.
    for _ in 0..<10 {
      await Task.yield()
    }
    #expect(await refresher.refreshedTokens == ["ghr_old"])

    await refresher.finish(.success(Self.renewedGrant))

    #expect(await first.value == "gho_new")
    #expect(await second.value == "gho_new")
    #expect(await refresher.refreshedTokens == ["ghr_old"])
  }

  @Test
  func aRejectedRefreshTokenAsksForSignInAgainAndStopsRetrying() async {
    let tokenStore = TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: -60))
    let refresher = TokenRefresherStub([.failure(DeviceFlowError.badRefreshToken)])
    let viewModel = makeViewModel(tokenStore: tokenStore, tokenRefresher: refresher)

    _ = await viewModel.freshAccessToken()
    _ = await viewModel.freshAccessToken()

    #expect(viewModel.isSignInExpired)
    #expect(
      viewModel.validationState
        == .invalid(message: DeviceFlowError.badRefreshToken.localizedDescription)
    )
    // One request: a refused refresh token is refused every time.
    #expect(await refresher.refreshedTokens == ["ghr_old"])
    // Signing out stays the user's decision; nothing is deleted for them.
    #expect(tokenStore.deleteCallCount == 0)
    #expect(viewModel.isSignedIn)
  }

  @Test
  func signingInAgainEndsAnExpiredSignIn() async {
    let tokenStore = TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: -60))
    let viewModel = makeViewModel(
      tokenStore: tokenStore,
      deviceFlow: DeviceFlowAuthorizerStub(grantResult: .success(Self.renewedGrant)),
      tokenRefresher: TokenRefresherStub([.failure(DeviceFlowError.badRefreshToken)])
    )
    _ = await viewModel.freshAccessToken()
    #expect(viewModel.isSignInExpired)

    await viewModel.signInWithDeviceFlow()

    #expect(!viewModel.isSignInExpired)
    #expect(viewModel.validationState == .valid(login: "octocat"))
    #expect(await viewModel.freshAccessToken() == "gho_new")
  }

  @Test
  func aNetworkFailureDuringRefreshKeepsTheCredentialAndTriesAgainNextTime() async {
    let refresher = TokenRefresherStub([
      .failure(URLError(.notConnectedToInternet)),
      .success(Self.renewedGrant),
    ])
    let viewModel = makeViewModel(
      tokenStore: TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: 60)),
      tokenRefresher: refresher
    )

    #expect(await viewModel.freshAccessToken() == "gho_old")
    #expect(!viewModel.isSignInExpired)

    #expect(await viewModel.freshAccessToken() == "gho_new")
    #expect(await refresher.refreshedTokens == ["ghr_old", "ghr_old"])
  }

  @Test
  func aRefreshThatLandsAfterSignOutIsDiscarded() async {
    let tokenStore = TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: 60))
    let refresher = ControlledTokenRefresher()
    let viewModel = makeViewModel(tokenStore: tokenStore, tokenRefresher: refresher)

    let refresh = Task { @MainActor in
      await viewModel.freshAccessToken()
    }
    await refresher.waitUntilPending()
    viewModel.signOut()
    await refresher.finish(.success(Self.renewedGrant))

    #expect(await refresh.value.isEmpty)
    #expect(tokenStore.savedCredentials.isEmpty)
    #expect(viewModel.token.isEmpty)
    #expect(!viewModel.isSignedIn)
  }

  @Test
  func adoptsACredentialAnotherCopyOfTheAppAlreadyRenewed() async {
    // An installed build and a development build share one Keychain item.
    // Spending the refresh token the other copy already spent would be
    // refused and look like an expired sign-in.
    let tokenStore = TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: 60))
    let refresher = TokenRefresherStub()
    let viewModel = makeViewModel(tokenStore: tokenStore, tokenRefresher: refresher)
    tokenStore.replaceStoredCredential(
      GitHubCredential(
        accessToken: "gho_other_copy",
        accessTokenExpiresAt: Self.now.addingTimeInterval(28_800),
        refreshToken: "ghr_other_copy"
      )
    )

    #expect(await viewModel.freshAccessToken() == "gho_other_copy")
    #expect(viewModel.token == "gho_other_copy")
    #expect(await refresher.refreshedTokens.isEmpty)
  }

  @Test
  func aFailedKeychainWriteAfterARefreshStillUsesTheRenewedToken() async {
    // GitHub retires the old pair the moment it issues the new one, so falling
    // back to the old token would fail every request until relaunch.
    let tokenStore = TokenStoreSpy(
      storedCredential: Self.expiringCredential(expiresIn: 60),
      failsToSave: true
    )
    let viewModel = makeViewModel(
      tokenStore: tokenStore,
      tokenRefresher: TokenRefresherStub([.success(Self.renewedGrant)])
    )

    #expect(await viewModel.freshAccessToken() == "gho_new")
    #expect(viewModel.persistenceError != nil)
  }

  @Test
  func aRefreshLeavesAReplacementTokenTheUserIsTypingAlone() async {
    let viewModel = makeViewModel(
      tokenStore: TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: 60)),
      tokenRefresher: TokenRefresherStub([.success(Self.renewedGrant)])
    )
    viewModel.token = "github_pat_half_typ"

    // Requests use the stored credential, never an unsaved draft.
    #expect(await viewModel.freshAccessToken() == "gho_new")
    #expect(viewModel.token == "github_pat_half_typ")
  }

  @Test
  func openingSettingsWithAnExpiredSignInSaysSoInsteadOfAGenericRejection() async {
    let viewModel = makeViewModel(
      tokenStore: TokenStoreSpy(storedCredential: Self.expiringCredential(expiresIn: -60)),
      validator: TokenValidatorStub(result: .success("octocat")),
      tokenRefresher: TokenRefresherStub([.failure(DeviceFlowError.badRefreshToken)])
    )

    await viewModel.refreshSignInState()

    #expect(
      viewModel.validationState
        == .invalid(message: DeviceFlowError.badRefreshToken.localizedDescription)
    )
  }

  private func makeViewModel(
    tokenStore: TokenStoreSpy = TokenStoreSpy(),
    validator: any GitHubTokenValidating = TokenValidatorStub(result: .success("octocat")),
    launchController: LaunchAtLoginControllerSpy = LaunchAtLoginControllerSpy(),
    badgeStore: BadgePreferenceStoreSpy = BadgePreferenceStoreSpy(),
    deviceFlow: any DeviceFlowAuthorizing = DeviceFlowAuthorizerStub(
      tokenResult: .success("gho_test")
    ),
    tokenRefresher: any GitHubTokenRefreshing = TokenRefresherStub(),
    verificationPageOpener: @escaping @MainActor @Sendable (URL) -> Void = { _ in },
    onSignOut: @escaping @MainActor () -> Void = {}
  ) -> SettingsViewModel {
    SettingsViewModel(
      tokenStore: tokenStore,
      validator: validator,
      launchAtLoginController: launchController,
      badgePreferenceStore: badgeStore,
      deviceFlow: deviceFlow,
      tokenRefresher: tokenRefresher,
      now: { Self.now },
      verificationPageOpener: verificationPageOpener,
      onSignOut: onSignOut
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
  private let grantResult: Result<GitHubTokenGrant, any Error>
  private(set) var authorizationRequestCount = 0

  /// A grant with a bare token: what an OAuth App without token expiration issues.
  init(isAvailable: Bool = true, tokenResult: Result<String, any Error>) {
    self.init(
      isAvailable: isAvailable,
      grantResult: tokenResult.map { GitHubTokenGrant(accessToken: $0) }
    )
  }

  init(isAvailable: Bool = true, grantResult: Result<GitHubTokenGrant, any Error>) {
    self.available = isAvailable
    self.grantResult = grantResult
  }

  nonisolated var isAvailable: Bool {
    available
  }

  func requestAuthorization() async throws -> DeviceAuthorization {
    authorizationRequestCount += 1
    return ControlledDeviceFlowAuthorizer.authorization
  }

  func waitForAccessToken(authorization: DeviceAuthorization) async throws -> GitHubTokenGrant {
    try grantResult.get()
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

  private var pending: CheckedContinuation<GitHubTokenGrant, any Error>?
  private var pollingWaiters: [CheckedContinuation<Void, Never>] = []

  nonisolated var isAvailable: Bool {
    true
  }

  func requestAuthorization() async throws -> DeviceAuthorization {
    Self.authorization
  }

  func waitForAccessToken(authorization: DeviceAuthorization) async throws -> GitHubTokenGrant {
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
    continuation.resume(with: result.map { GitHubTokenGrant(accessToken: $0) })
  }
}

@MainActor
private final class SignOutSpy {
  private(set) var callCount = 0

  func record() {
    callCount += 1
  }
}

private final class TokenStoreSpy: TokenStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var storedCredential: GitHubCredential?
  private var mutableSavedCredentials: [GitHubCredential] = []
  private var mutableDeleteCallCount = 0
  private let failsToSave: Bool
  private let failsToDelete: Bool

  convenience init(storedToken: String?, failsToSave: Bool = false, failsToDelete: Bool = false) {
    self.init(
      storedCredential: storedToken.map { GitHubCredential(accessToken: $0) },
      failsToSave: failsToSave,
      failsToDelete: failsToDelete
    )
  }

  init(
    storedCredential: GitHubCredential? = nil,
    failsToSave: Bool = false,
    failsToDelete: Bool = false
  ) {
    self.storedCredential = storedCredential
    self.failsToSave = failsToSave
    self.failsToDelete = failsToDelete
  }

  var savedCredentials: [GitHubCredential] {
    lock.withLock {
      mutableSavedCredentials
    }
  }

  var savedTokens: [String] {
    savedCredentials.map(\.accessToken)
  }

  var deleteCallCount: Int {
    lock.withLock {
      mutableDeleteCallCount
    }
  }

  /// Stands in for another copy of the app writing the shared Keychain item.
  func replaceStoredCredential(_ credential: GitHubCredential?) {
    lock.withLock {
      storedCredential = credential
    }
  }

  func loadCredential() throws -> GitHubCredential? {
    lock.withLock {
      storedCredential
    }
  }

  func saveCredential(_ credential: GitHubCredential) throws {
    if failsToSave {
      throw KeychainError(status: errSecIO)
    }
    lock.withLock {
      storedCredential = credential
      mutableSavedCredentials.append(credential)
    }
  }

  func deleteCredential() throws {
    if failsToDelete {
      throw KeychainError(status: errSecIO)
    }
    lock.withLock {
      storedCredential = nil
      mutableDeleteCallCount += 1
    }
  }
}

private actor TokenRefresherStub: GitHubTokenRefreshing {
  private var results: [Result<GitHubTokenGrant, any Error>]
  private(set) var refreshedTokens: [String] = []

  init(_ results: [Result<GitHubTokenGrant, any Error>] = []) {
    self.results = results
  }

  func refreshAccessToken(refreshToken: String) async throws -> GitHubTokenGrant {
    refreshedTokens.append(refreshToken)
    guard !results.isEmpty else {
      Issue.record("Unexpected refresh with \(refreshToken)")
      throw DeviceFlowError.invalidResponse
    }
    return try results.removeFirst().get()
  }
}

/// Holds every refresh open until the test finishes them, so a test can act
/// while a refresh is in flight.
private actor ControlledTokenRefresher: GitHubTokenRefreshing {
  private(set) var refreshedTokens: [String] = []
  private var pending: [CheckedContinuation<GitHubTokenGrant, any Error>] = []
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func refreshAccessToken(refreshToken: String) async throws -> GitHubTokenGrant {
    refreshedTokens.append(refreshToken)
    return try await withCheckedThrowingContinuation { continuation in
      pending.append(continuation)
      for waiter in waiters {
        waiter.resume()
      }
      waiters = []
    }
  }

  func waitUntilPending() async {
    guard pending.isEmpty else {
      return
    }
    await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  func finish(_ result: Result<GitHubTokenGrant, any Error>) {
    precondition(!pending.isEmpty, "No pending refresh")
    for continuation in pending {
      continuation.resume(with: result)
    }
    pending = []
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

private final class BadgePreferenceStoreSpy: MenuBarCountPreferenceStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var count: MenuBarCount
  private var mutableSavedValues: [MenuBarCount] = []

  init(count: MenuBarCount = .today) {
    self.count = count
  }

  var savedValues: [MenuBarCount] {
    lock.withLock {
      mutableSavedValues
    }
  }

  func loadCount() throws -> MenuBarCount {
    lock.withLock {
      count
    }
  }

  func saveCount(_ count: MenuBarCount) throws {
    lock.withLock {
      self.count = count
      mutableSavedValues.append(count)
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
