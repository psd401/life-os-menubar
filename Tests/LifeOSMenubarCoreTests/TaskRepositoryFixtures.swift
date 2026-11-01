import Foundation

@testable import LifeOSMenubarCore

/// The fixture task repo every client test points at. Deliberately not the
/// maintainer's own repo: a hardcoded `krishagel/life-os` in a test would be the
/// same string the app just stopped shipping, and reviewers could not tell the
/// fixture from a leftover default.
enum TaskRepositoryFixture {
  static let owner = "octocat"
  static let name = "tasks"
  static let slug = "\(owner)/\(name)"

  static var repository: TaskRepository {
    TaskRepository(owner: owner, name: name)
  }

  static var store: InMemoryTaskRepositoryStore {
    InMemoryTaskRepositoryStore(repository: repository)
  }
}

/// A `TaskRepositoryStoring` double. Reference semantics on purpose: a test can
/// change the configured repo, or clear it, after handing the store to a client.
final class InMemoryTaskRepositoryStore: TaskRepositoryStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var repository: TaskRepository?

  init(repository: TaskRepository? = nil) {
    self.repository = repository
  }

  func loadRepository() throws -> TaskRepository? {
    lock.withLock { repository }
  }

  func saveRepository(_ repository: TaskRepository) throws {
    lock.withLock { self.repository = repository }
  }

  func clearRepository() throws {
    lock.withLock { repository = nil }
  }
}
