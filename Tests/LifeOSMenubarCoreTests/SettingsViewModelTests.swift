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
  func clearDeletesKeychainTokenAndResetsValidation() async {
    let tokenStore = TokenStoreSpy(storedToken: "saved-token")
    let validator = TokenValidatorStub(result: .success("octocat"))
    let viewModel = makeViewModel(
      tokenStore: tokenStore,
      validator: validator
    )
    await viewModel.validateToken()
    #expect(viewModel.validationState == .valid(login: "octocat"))

    viewModel.clearToken()

    #expect(tokenStore.deleteCallCount == 1)
    #expect(viewModel.token.isEmpty)
    #expect(viewModel.validationState == .idle)
  }

  @Test
  func launchAtLoginToggleReflectsServiceState() {
    let launchController = LaunchAtLoginControllerSpy()
    let viewModel = makeViewModel(launchController: launchController)

    viewModel.setLaunchAtLoginEnabled(true)

    #expect(launchController.requestedStates == [true])
    #expect(viewModel.isLaunchAtLoginEnabled)
  }

  private func makeViewModel(
    tokenStore: TokenStoreSpy = TokenStoreSpy(),
    validator: any GitHubTokenValidating = TokenValidatorStub(result: .success("octocat")),
    launchController: LaunchAtLoginControllerSpy = LaunchAtLoginControllerSpy()
  ) -> SettingsViewModel {
    SettingsViewModel(
      tokenStore: tokenStore,
      validator: validator,
      launchAtLoginController: launchController
    )
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
