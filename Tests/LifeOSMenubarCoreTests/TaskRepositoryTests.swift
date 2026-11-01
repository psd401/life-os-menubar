import Foundation
import Testing

@testable import LifeOSMenubarCore

struct TaskRepositoryTests {
  @Test
  func parsesTrimmedOwnerAndName() throws {
    let repository = try TaskRepository.parse("  octocat/task-list \n")

    #expect(repository.owner == "octocat")
    #expect(repository.name == "task-list")
    #expect(repository.slug == "octocat/task-list")
  }

  @Test
  func parsesAFullGitHubURL() throws {
    let repository = try TaskRepository.parse("https://github.com/octocat/task-list")

    #expect(repository.slug == "octocat/task-list")
  }

  @Test
  func rejectsAnEmptySlug() {
    #expect(throws: TaskRepositorySlugError.empty) {
      try TaskRepository.parse("   ")
    }
  }

  @Test
  func rejectsASlugWithoutExactlyOneSeparator() {
    #expect(throws: TaskRepositorySlugError.malformed("octocat")) {
      try TaskRepository.parse("octocat")
    }
    #expect(throws: TaskRepositorySlugError.malformed("octocat/tasks/extra")) {
      try TaskRepository.parse("octocat/tasks/extra")
    }
    #expect(throws: TaskRepositorySlugError.malformed("/tasks")) {
      try TaskRepository.parse("/tasks")
    }
  }

  @Test
  func rejectsCharactersGitHubDoesNotAllow() {
    #expect(throws: TaskRepositorySlugError.invalidCharacters("octo cat/tasks")) {
      try TaskRepository.parse("octo cat/tasks")
    }
    #expect(throws: TaskRepositorySlugError.invalidCharacters("octocat/ta sks")) {
      try TaskRepository.parse("octocat/ta sks")
    }
  }

  @Test
  func acceptsDotsAndUnderscoresInTheRepositoryName() throws {
    let repository = try TaskRepository.parse("octo-cat/my_tasks.v2")

    #expect(repository.name == "my_tasks.v2")
  }

  @Test
  func everyErrorDescribesItselfWithoutNamingAnyParticularRepository() {
    let messages = [
      TaskRepositorySlugError.empty,
      .malformed("x"),
      .invalidCharacters("x"),
    ].compactMap(\.errorDescription)

    #expect(messages.count == 3)
    #expect(messages.allSatisfy { !$0.isEmpty })
    #expect(messages.allSatisfy { !$0.contains("krishagel") })
  }

  @Test
  func requiredLabelsCoverEveryStatusSectionPlusDoneAndTheContractExtras() {
    let required = Set(LabelRules.requiredLabelNames)

    for section in TaskStatusSection.allCases {
      #expect(required.contains(section.labelName))
    }
    #expect(required.contains("status:done"))
    #expect(required.isSuperset(of: ["priority:p0", "priority:p1", "priority:p2", "priority:p3"]))
    #expect(required.contains("type:task"))
    #expect(required.contains("source:manual"))
    #expect(required.count == LabelRules.requiredLabelNames.count)
  }
}

struct UserDefaultsTaskRepositoryStoreTests {
  @Test
  func returnsNilWhenNothingHasBeenConfigured() throws {
    let store = makeStore()

    #expect(try store.loadRepository() == nil)
  }

  @Test
  func roundTripsASavedRepository() throws {
    let store = makeStore()

    try store.saveRepository(TaskRepository(owner: "octocat", name: "tasks"))

    #expect(try store.loadRepository() == TaskRepository(owner: "octocat", name: "tasks"))
  }

  @Test
  func clearingRemovesTheConfiguration() throws {
    let store = makeStore()
    try store.saveRepository(TaskRepository(owner: "octocat", name: "tasks"))

    try store.clearRepository()

    #expect(try store.loadRepository() == nil)
  }

  @Test
  func treatsAStoredValueThatIsNoLongerParseableAsUnconfigured() throws {
    let defaults = makeDefaults()
    let store = UserDefaultsTaskRepositoryStore(userDefaults: defaults)
    defaults.set("not a slug", forKey: "taskRepository")

    #expect(try store.loadRepository() == nil)
  }

  @Test
  func requiringAnUnconfiguredRepositoryThrowsTheNotConfiguredError() {
    let store = makeStore()

    #expect(throws: TaskRepositoryConfigurationError.notConfigured) {
      try store.requireRepository()
    }
  }

  private func makeStore() -> UserDefaultsTaskRepositoryStore {
    UserDefaultsTaskRepositoryStore(userDefaults: makeDefaults())
  }

  /// A throwaway suite per test: the store reads `UserDefaults`, and the real
  /// `.standard` domain belongs to the developer's own installed app.
  private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "life-os-menubar-issue-21-\(UUID().uuidString)")!
  }
}

/// The bootstrap script and the validator must require exactly the same labels.
/// A label the script forgets is one the app will reject forever; a label the
/// script creates and nothing needs is noise in the user's repo.
struct BootstrapScriptContractTests {
  @Test
  func bootstrapScriptCreatesExactlyTheRequiredLabels() throws {
    let scriptURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // LifeOSMenubarCoreTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // repo root
      .appendingPathComponent("scripts/bootstrap-task-repo.sh")
    let script = try String(contentsOf: scriptURL, encoding: .utf8)

    let declared =
      script
      .split(separator: "\n")
      .compactMap { line -> String? in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.contains("|") else {
          return nil
        }
        return String(trimmed.dropFirst().split(separator: "|")[0])
      }

    #expect(Set(declared) == Set(LabelRules.requiredLabelNames))
    #expect(declared.count == LabelRules.requiredLabelNames.count)
  }
}
