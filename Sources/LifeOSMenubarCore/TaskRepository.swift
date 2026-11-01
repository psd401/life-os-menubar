import Foundation

/// The GitHub repository whose issues are the task list.
///
/// There is deliberately no default value anywhere in the app. A build that
/// shipped one would point every new install at someone else's repo, so an
/// unconfigured install is an explicit state the UI has to handle — see
/// `TaskRepositoryConfigurationError.notConfigured`.
public struct TaskRepository: Equatable, Hashable, Sendable, Codable {
  public let owner: String
  public let name: String

  public var slug: String {
    "\(owner)/\(name)"
  }

  public init(owner: String, name: String) {
    self.owner = owner
    self.name = name
  }
}

public enum TaskRepositorySlugError: LocalizedError, Equatable, Sendable {
  case empty
  case malformed(String)
  case invalidCharacters(String)

  public var errorDescription: String? {
    switch self {
    case .empty:
      "Enter the task repository as owner/repo."
    case .malformed(let value):
      "\"\(value)\" is not an owner/repo pair. Enter it as owner/repo."
    case .invalidCharacters(let value):
      "\"\(value)\" uses characters GitHub does not allow in an owner or repository name."
    }
  }
}

extension TaskRepository {
  /// Characters GitHub allows in a user or organization login.
  private static let ownerCharacters = CharacterSet.alphanumerics
    .union(CharacterSet(charactersIn: "-"))
  /// Characters GitHub allows in a repository name.
  private static let nameCharacters = CharacterSet.alphanumerics
    .union(CharacterSet(charactersIn: "-._"))

  /// Parses `owner/repo`, also accepting a pasted `github.com` URL — pasting the
  /// repo's address is the obvious thing to try, and rejecting it would be a
  /// pointless error message.
  public static func parse(_ slug: String) throws -> TaskRepository {
    let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw TaskRepositorySlugError.empty
    }

    let candidate = stripGitHubURLPrefix(from: trimmed)
    let components = candidate.split(separator: "/", omittingEmptySubsequences: false)
    guard components.count == 2 else {
      throw TaskRepositorySlugError.malformed(trimmed)
    }
    let owner = String(components[0])
    let name = String(components[1])
    guard !owner.isEmpty, !name.isEmpty else {
      throw TaskRepositorySlugError.malformed(trimmed)
    }
    guard owner.unicodeScalars.allSatisfy(ownerCharacters.contains),
      name.unicodeScalars.allSatisfy(nameCharacters.contains),
      // GitHub never allows these names, and in an API path they'd act as
      // relative segments rather than a repository.
      name != ".", name != ".."
    else {
      throw TaskRepositorySlugError.invalidCharacters(trimmed)
    }

    return TaskRepository(owner: owner, name: name)
  }

  private static func stripGitHubURLPrefix(from value: String) -> String {
    var candidate = value
    for prefix in ["https://", "http://"] where candidate.hasPrefix(prefix) {
      candidate.removeFirst(prefix.count)
    }
    for prefix in ["www.github.com/", "github.com/"] where candidate.hasPrefix(prefix) {
      candidate.removeFirst(prefix.count)
    }
    if candidate.hasSuffix("/") {
      candidate.removeLast()
    }
    if candidate.hasSuffix(".git") {
      candidate.removeLast(".git".count)
    }
    return candidate
  }
}

public enum TaskRepositoryConfigurationError: LocalizedError, Equatable, Sendable {
  case notConfigured

  public var errorDescription: String? {
    switch self {
    case .notConfigured:
      "No task repository is configured. Open Settings and enter your task repo as owner/repo."
    }
  }
}

public protocol TaskRepositoryStoring: Sendable {
  func loadRepository() throws -> TaskRepository?
  func saveRepository(_ repository: TaskRepository) throws
  func clearRepository() throws
}

extension TaskRepositoryStoring {
  /// The repository, or the "not configured yet" error every caller surfaces
  /// verbatim. Clients call this per request rather than capturing a repository
  /// at construction, so changing the setting takes effect without rebuilding
  /// the app's composition root.
  public func requireRepository() throws -> TaskRepository {
    guard let repository = try loadRepository() else {
      throw TaskRepositoryConfigurationError.notConfigured
    }
    return repository
  }
}

/// Stores the configured repository in `UserDefaults` as an `owner/repo` string.
///
/// A repository slug is not a secret — it is in every API URL the app sends —
/// so it belongs with the other preferences, not in the Keychain beside the
/// token (standard 04, rule 15a).
public struct UserDefaultsTaskRepositoryStore: TaskRepositoryStoring, @unchecked Sendable {
  private let userDefaults: UserDefaults
  private let key: String

  public init(
    userDefaults: UserDefaults = .standard,
    key: String = "taskRepository"
  ) {
    self.userDefaults = userDefaults
    self.key = key
  }

  public func loadRepository() throws -> TaskRepository? {
    guard let slug = userDefaults.string(forKey: key) else {
      return nil
    }
    // A stored value that no longer parses is treated as unconfigured rather
    // than as an error: the app then shows the first-run state, which is the
    // one place that can actually fix it.
    return try? TaskRepository.parse(slug)
  }

  public func saveRepository(_ repository: TaskRepository) throws {
    userDefaults.set(repository.slug, forKey: key)
  }

  public func clearRepository() throws {
    userDefaults.removeObject(forKey: key)
  }
}
