import Foundation

/// The result of checking a candidate task repo: it exists, this token can read
/// it, and these required label definitions are missing from it.
public struct TaskRepositoryValidationReport: Equatable, Sendable {
  public let repository: TaskRepository
  /// Missing required labels, in the contract's own order rather than the order
  /// GitHub happened to return — the list is read by a human who then creates
  /// them, so `status:*` before `priority:*` before the extras.
  public let missingLabels: [String]

  public var isConforming: Bool {
    missingLabels.isEmpty
  }

  public init(repository: TaskRepository, missingLabels: [String]) {
    self.repository = repository
    self.missingLabels = missingLabels
  }
}

public protocol TaskRepositoryValidating: Sendable {
  func validate(
    token: String,
    repository: TaskRepository
  ) async throws -> TaskRepositoryValidationReport
}

public enum TaskRepositoryValidationError: LocalizedError, Equatable, Sendable {
  case emptyToken
  case invalidResponse
  case invalidRequestURL(repository: String)
  case rejected
  case forbidden(repository: String)
  case repositoryNotFound(repository: String)
  case requestFailed(statusCode: Int)

  public var errorDescription: String? {
    switch self {
    case .emptyToken:
      "Save a GitHub token before validating the task repository."
    case .invalidResponse:
      "GitHub returned an invalid label response."
    case .invalidRequestURL(let repository):
      "\(repository) cannot be turned into a GitHub API address."
    case .rejected:
      "GitHub rejected this token. Check that it is active."
    case .forbidden(let repository):
      "This token is not allowed to read \(repository). Grant it access to that repository."
    case .repositoryNotFound(let repository):
      "\(repository) does not exist, or this token cannot see it."
    case .requestFailed(let statusCode):
      "Reading the repository's labels failed with HTTP status \(statusCode)."
    }
  }
}

/// Checks a candidate task repo against the standard in
/// `docs/life-os-repo-standard.md` by listing its labels over REST.
///
/// Listing labels is the one call that proves both halves at once: a 404 or 403
/// means the token cannot reach the repo, and the body says whether the repo was
/// bootstrapped. The app never creates the labels itself — see
/// [decision 0005](../../openwiki/decisions/0005-configurable-task-repo.md).
public struct TaskRepositoryValidator: TaskRepositoryValidating {
  /// GitHub's maximum page size for the labels endpoint.
  private static let pageSize = 100
  /// A guard against an endless pagination loop, not a real repository limit:
  /// 100 pages is 10,000 labels.
  private static let pageLimit = 100

  private let session: URLSession
  private let endpoint: URL

  public init(
    session: URLSession = .shared,
    endpoint: URL = URL(string: "https://api.github.com")!
  ) {
    self.session = session
    self.endpoint = endpoint
  }

  public func validate(
    token: String,
    repository: TaskRepository
  ) async throws -> TaskRepositoryValidationReport {
    let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else {
      throw TaskRepositoryValidationError.emptyToken
    }

    var presentLabels: Set<String> = []
    var page = 1
    while page <= Self.pageLimit {
      let labels = try await fetchLabelPage(
        token: candidate,
        repository: repository,
        page: page
      )
      for label in labels {
        presentLabels.insert(label.name.lowercased())
      }
      guard labels.count == Self.pageSize else {
        break
      }
      page += 1
    }

    return TaskRepositoryValidationReport(
      repository: repository,
      missingLabels: LabelRules.requiredLabelNames.filter {
        !presentLabels.contains($0.lowercased())
      }
    )
  }

  private func fetchLabelPage(
    token: String,
    repository: TaskRepository,
    page: Int
  ) async throws -> [LabelResponse] {
    let labelsURL =
      endpoint
      .appendingPathComponent("repos")
      .appendingPathComponent(repository.owner)
      .appendingPathComponent(repository.name)
      .appendingPathComponent("labels")
    guard var components = URLComponents(url: labelsURL, resolvingAgainstBaseURL: false) else {
      throw TaskRepositoryValidationError.invalidRequestURL(repository: repository.slug)
    }
    components.queryItems = [
      URLQueryItem(name: "per_page", value: String(Self.pageSize)),
      URLQueryItem(name: "page", value: String(page)),
    ]
    guard let url = components.url else {
      throw TaskRepositoryValidationError.invalidRequestURL(repository: repository.slug)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw TaskRepositoryValidationError.invalidResponse
    }
    switch httpResponse.statusCode {
    case 200..<300:
      break
    case 401:
      throw TaskRepositoryValidationError.rejected
    case 403:
      throw TaskRepositoryValidationError.forbidden(repository: repository.slug)
    case 404:
      throw TaskRepositoryValidationError.repositoryNotFound(repository: repository.slug)
    default:
      throw TaskRepositoryValidationError.requestFailed(statusCode: httpResponse.statusCode)
    }

    do {
      return try JSONDecoder().decode([LabelResponse].self, from: data)
    } catch {
      throw TaskRepositoryValidationError.invalidResponse
    }
  }
}

private struct LabelResponse: Decodable {
  let name: String
}
