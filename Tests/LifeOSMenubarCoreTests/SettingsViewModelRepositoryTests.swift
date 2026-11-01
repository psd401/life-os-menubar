import Foundation
import Testing

@testable import LifeOSMenubarCore

/// The task-repository half of Settings. Kept in its own suite so the existing
/// token tests stay readable.
@MainActor
struct SettingsViewModelRepositoryTests {
  @Test
  func startsUnconfiguredWhenNoRepositoryHasEverBeenSaved() {
    let viewModel = makeViewModel()

    #expect(viewModel.repositorySlug.isEmpty)
    #expect(!viewModel.isRepositoryConfigured)
    #expect(viewModel.repositoryState == .idle)
  }

  @Test
  func loadsThePreviouslyConfiguredRepository() {
    let viewModel = makeViewModel(
      repositoryStore: InMemoryTaskRepositoryStore(
        repository: TaskRepository(owner: "acme", name: "work-tasks")
      )
    )

    #expect(viewModel.repositorySlug == "acme/work-tasks")
    #expect(viewModel.isRepositoryConfigured)
  }

  @Test
  func savesAndReportsAConformingRepository() async throws {
    let store = InMemoryTaskRepositoryStore()
    let validator = TaskRepositoryValidatorStub(missingLabels: [])
    var changes: [TaskRepository?] = []
    let viewModel = makeViewModel(
      repositoryStore: store,
      repositoryValidator: validator,
      onRepositoryChange: { changes.append($0) }
    )
    viewModel.repositorySlug = "  acme/work-tasks \n"

    await viewModel.saveAndValidateRepository()

    #expect(viewModel.repositoryState == .valid(slug: "acme/work-tasks"))
    #expect(viewModel.repositorySlug == "acme/work-tasks")
    #expect(viewModel.isRepositoryConfigured)
    #expect(try store.loadRepository() == TaskRepository(owner: "acme", name: "work-tasks"))
    #expect(changes == [TaskRepository(owner: "acme", name: "work-tasks")])
  }

  @Test
  func namesEveryMissingLabelAndRefusesToSaveTheRepository() async throws {
    let store = InMemoryTaskRepositoryStore()
    let validator = TaskRepositoryValidatorStub(
      missingLabels: ["status:done", "priority:p0"]
    )
    let viewModel = makeViewModel(repositoryStore: store, repositoryValidator: validator)
    viewModel.repositorySlug = "acme/work-tasks"

    await viewModel.saveAndValidateRepository()

    guard case .invalid(let message) = viewModel.repositoryState else {
      Issue.record("Expected an invalid repository state, got \(viewModel.repositoryState).")
      return
    }
    #expect(message.contains("status:done"))
    #expect(message.contains("priority:p0"))
    #expect(try store.loadRepository() == nil)
    #expect(!viewModel.isRepositoryConfigured)
  }

  @Test
  func reportsAParseFailureWithoutCallingGitHub() async throws {
    let store = InMemoryTaskRepositoryStore()
    let validator = TaskRepositoryValidatorStub(missingLabels: [])
    let viewModel = makeViewModel(repositoryStore: store, repositoryValidator: validator)
    viewModel.repositorySlug = "not a slug"

    await viewModel.saveAndValidateRepository()

    #expect(
      viewModel.repositoryState
        == .invalid(
          message: TaskRepositorySlugError.malformed("not a slug").localizedDescription
        )
    )
    #expect(validator.callCount == 0)
    #expect(try store.loadRepository() == nil)
  }

  @Test
  func refusesToValidateBeforeATokenIsSaved() async {
    let validator = TaskRepositoryValidatorStub(missingLabels: [])
    let viewModel = makeViewModel(
      tokenStore: TokenStoreStub(storedToken: nil),
      repositoryValidator: validator
    )
    viewModel.repositorySlug = "acme/work-tasks"

    await viewModel.saveAndValidateRepository()

    #expect(
      viewModel.repositoryState
        == .invalid(message: TaskRepositoryValidationError.emptyToken.localizedDescription)
    )
    #expect(validator.callCount == 0)
  }

  @Test
  func surfacesAValidationErrorAndKeepsThePreviousRepository() async throws {
    let store = InMemoryTaskRepositoryStore(
      repository: TaskRepository(owner: "acme", name: "work-tasks")
    )
    let validator = TaskRepositoryValidatorStub(
      error: .repositoryNotFound(repository: "acme/typo")
    )
    let viewModel = makeViewModel(repositoryStore: store, repositoryValidator: validator)
    viewModel.repositorySlug = "acme/typo"

    await viewModel.saveAndValidateRepository()

    #expect(
      viewModel.repositoryState
        == .invalid(
          message: TaskRepositoryValidationError.repositoryNotFound(repository: "acme/typo")
            .localizedDescription
        )
    )
    #expect(try store.loadRepository() == TaskRepository(owner: "acme", name: "work-tasks"))
  }

  @Test
  func clearingTheRepositoryReturnsTheAppToItsFirstRunState() throws {
    let store = InMemoryTaskRepositoryStore(
      repository: TaskRepository(owner: "acme", name: "work-tasks")
    )
    var changes: [TaskRepository?] = []
    let viewModel = makeViewModel(
      repositoryStore: store,
      onRepositoryChange: { changes.append($0) }
    )

    viewModel.clearRepository()

    #expect(viewModel.repositorySlug.isEmpty)
    #expect(!viewModel.isRepositoryConfigured)
    #expect(viewModel.repositoryState == .idle)
    #expect(try store.loadRepository() == nil)
    #expect(changes == [TaskRepository?.none])
  }

  @Test
  func anOlderRepositoryValidationCannotOverwriteANewerResult() async throws {
    let validator = ControlledTaskRepositoryValidator()
    let viewModel = makeViewModel(repositoryValidator: validator)

    viewModel.repositorySlug = "acme/first"
    let firstValidation = Task { @MainActor in
      await viewModel.saveAndValidateRepository()
    }
    await validator.waitUntilPending(slug: "acme/first")

    viewModel.repositorySlug = "acme/second"
    let secondValidation = Task { @MainActor in
      await viewModel.saveAndValidateRepository()
    }
    await validator.waitUntilPending(slug: "acme/second")

    try await validator.succeed(slug: "acme/second")
    await secondValidation.value
    #expect(viewModel.repositoryState == .valid(slug: "acme/second"))

    try await validator.succeed(slug: "acme/first")
    await firstValidation.value
    #expect(viewModel.repositoryState == .valid(slug: "acme/second"))
  }

  private func makeViewModel(
    tokenStore: TokenStoreStub = TokenStoreStub(storedToken: "repo-token"),
    repositoryStore: any TaskRepositoryStoring = InMemoryTaskRepositoryStore(),
    repositoryValidator: any TaskRepositoryValidating = TaskRepositoryValidatorStub(
      missingLabels: []
    ),
    onRepositoryChange: @escaping @MainActor (TaskRepository?) -> Void = { _ in }
  ) -> SettingsViewModel {
    SettingsViewModel(
      tokenStore: tokenStore,
      validator: AlwaysValidTokenValidator(),
      launchAtLoginController: NoopLaunchAtLoginController(),
      badgePreferenceStore: InMemoryBadgePreferenceStore(),
      repositoryStore: repositoryStore,
      repositoryValidator: repositoryValidator,
      onRepositoryChange: onRepositoryChange
    )
  }
}

private final class TaskRepositoryValidatorStub: TaskRepositoryValidating, @unchecked Sendable {
  private let lock = NSLock()
  private let missingLabels: [String]
  private let error: TaskRepositoryValidationError?
  private var mutableCallCount = 0

  init(missingLabels: [String] = [], error: TaskRepositoryValidationError? = nil) {
    self.missingLabels = missingLabels
    self.error = error
  }

  var callCount: Int {
    lock.withLock { mutableCallCount }
  }

  func validate(
    token: String,
    repository: TaskRepository
  ) async throws -> TaskRepositoryValidationReport {
    lock.withLock { mutableCallCount += 1 }
    if let error {
      throw error
    }
    return TaskRepositoryValidationReport(
      repository: repository,
      missingLabels: missingLabels
    )
  }
}

private actor ControlledTaskRepositoryValidator: TaskRepositoryValidating {
  private var pending: [String: CheckedContinuation<TaskRepositoryValidationReport, any Error>] =
    [:]
  private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

  func validate(
    token: String,
    repository: TaskRepository
  ) async throws -> TaskRepositoryValidationReport {
    try await withCheckedThrowingContinuation { continuation in
      pending[repository.slug] = continuation
      for waiter in waiters.removeValue(forKey: repository.slug) ?? [] {
        waiter.resume()
      }
    }
  }

  func waitUntilPending(slug: String) async {
    guard pending[slug] == nil else {
      return
    }
    await withCheckedContinuation { continuation in
      waiters[slug, default: []].append(continuation)
    }
  }

  func succeed(slug: String) throws {
    guard let continuation = pending.removeValue(forKey: slug) else {
      preconditionFailure("No pending validation for \(slug)")
    }
    continuation.resume(
      returning: TaskRepositoryValidationReport(
        repository: try TaskRepository.parse(slug),
        missingLabels: []
      )
    )
  }
}

private final class TokenStoreStub: TokenStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var storedToken: String?

  init(storedToken: String?) {
    self.storedToken = storedToken
  }

  func loadToken() throws -> String? {
    lock.withLock { storedToken }
  }

  func saveToken(_ token: String) throws {
    lock.withLock { storedToken = token }
  }

  func deleteToken() throws {
    lock.withLock { storedToken = nil }
  }
}

private struct AlwaysValidTokenValidator: GitHubTokenValidating {
  func validate(token: String) async throws -> String {
    "octocat"
  }
}

private struct InMemoryBadgePreferenceStore: MenuBarCountPreferenceStoring {
  func loadCount() throws -> MenuBarCount {
    .today
  }

  func saveCount(_ count: MenuBarCount) throws {}
}

@MainActor
private final class NoopLaunchAtLoginController: LaunchAtLoginControlling {
  private(set) var isEnabled = false

  func setEnabled(_ isEnabled: Bool) throws {
    self.isEnabled = isEnabled
  }
}
