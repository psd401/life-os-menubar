import Foundation

public protocol GitHubIssueMutating: Sendable {
  func addComment(token: String, issueNumber: Int, body: String) async throws -> GitHubComment
  func updateIssue(
    token: String,
    issueNumber: Int,
    labels: [String],
    state: GitHubIssueState?
  ) async throws -> LifeOSIssue
}

public enum GitHubIssueMutationClientError: LocalizedError, Equatable, Sendable {
  case emptyToken
  case emptyComment
  case invalidResponse
  case rejected
  case requestFailed(statusCode: Int)
  case invalidTimestamp(String)
  case invalidState(String)

  public var errorDescription: String? {
    switch self {
    case .emptyToken:
      "Add a GitHub token in Settings before changing a task."
    case .emptyComment:
      "Enter a comment before posting."
    case .invalidResponse:
      "GitHub returned an invalid mutation response."
    case .rejected:
      "GitHub rejected this token. Check that it can write to the repository."
    case .requestFailed(let statusCode):
      "GitHub rejected the task change with HTTP status \(statusCode)."
    case .invalidTimestamp(let value):
      "GitHub returned an invalid timestamp: \(value)."
    case .invalidState(let value):
      "GitHub returned an invalid issue state: \(value)."
    }
  }
}

public struct GitHubRESTIssueClient: GitHubIssueMutating {
  private let session: URLSession
  private let endpoint: URL
  private let owner: String
  private let repository: String

  public init(
    session: URLSession = .shared,
    endpoint: URL = URL(string: "https://api.github.com")!,
    owner: String = "krishagel",
    repository: String = "life-os"
  ) {
    self.session = session
    self.endpoint = endpoint
    self.owner = owner
    self.repository = repository
  }

  public func addComment(
    token: String,
    issueNumber: Int,
    body: String
  ) async throws -> GitHubComment {
    let comment = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !comment.isEmpty else {
      throw GitHubIssueMutationClientError.emptyComment
    }
    var request = try makeRequest(
      token: token,
      pathComponents: [
        "repos", owner, repository, "issues", String(issueNumber), "comments",
      ],
      method: "POST"
    )
    request.httpBody = try JSONEncoder().encode(CommentRequest(body: comment))
    let response: CommentResponse = try await perform(request)
    return try Self.makeComment(from: response)
  }

  public func updateIssue(
    token: String,
    issueNumber: Int,
    labels: [String],
    state: GitHubIssueState?
  ) async throws -> LifeOSIssue {
    var request = try makeRequest(
      token: token,
      pathComponents: ["repos", owner, repository, "issues", String(issueNumber)],
      method: "PATCH"
    )
    request.httpBody = try JSONEncoder().encode(
      UpdateIssueRequest(
        labels: labels,
        state: state.map { $0 == .open ? "open" : "closed" }
      )
    )
    let response: IssueResponse = try await perform(request)
    return try Self.makeIssue(from: response)
  }

  private func makeRequest(
    token: String,
    pathComponents: [String],
    method: String
  ) throws -> URLRequest {
    let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else {
      throw GitHubIssueMutationClientError.emptyToken
    }

    let url = pathComponents.reduce(endpoint) { partialURL, component in
      partialURL.appendingPathComponent(component)
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(candidate)", forHTTPHeaderField: "Authorization")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    return request
  }

  private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubIssueMutationClientError.invalidResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      if httpResponse.statusCode == 401 {
        throw GitHubIssueMutationClientError.rejected
      }
      throw GitHubIssueMutationClientError.requestFailed(statusCode: httpResponse.statusCode)
    }
    return try JSONDecoder().decode(Response.self, from: data)
  }

  private static func makeIssue(from response: IssueResponse) throws -> LifeOSIssue {
    let state: GitHubIssueState
    switch response.state {
    case "open":
      state = .open
    case "closed":
      state = .closed
    default:
      throw GitHubIssueMutationClientError.invalidState(response.state)
    }

    return LifeOSIssue(
      number: response.number,
      title: response.title,
      body: response.body ?? "",
      labels: response.labels.map { GitHubLabel(name: $0.name, color: $0.color) },
      updatedAt: try parseTimestamp(response.updatedAt),
      state: state
    )
  }

  private static func makeComment(from response: CommentResponse) throws -> GitHubComment {
    GitHubComment(
      id: response.nodeID,
      authorLogin: response.user?.login ?? "ghost",
      body: response.body,
      createdAt: try parseTimestamp(response.createdAt),
      updatedAt: try parseTimestamp(response.updatedAt)
    )
  }

  private static func parseTimestamp(_ value: String) throws -> Date {
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractionalFormatter.date(from: value) {
      return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let date = formatter.date(from: value) else {
      throw GitHubIssueMutationClientError.invalidTimestamp(value)
    }
    return date
  }
}

private struct CommentRequest: Encodable {
  let body: String
}

private struct UpdateIssueRequest: Encodable {
  let labels: [String]
  let state: String?
}

private struct CommentResponse: Decodable {
  struct User: Decodable {
    let login: String
  }

  let nodeID: String
  let user: User?
  let body: String
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case nodeID = "node_id"
    case user
    case body
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

private struct IssueResponse: Decodable {
  struct Label: Decodable {
    let name: String
    let color: String
  }

  let number: Int
  let title: String
  let body: String?
  let labels: [Label]
  let updatedAt: String
  let state: String

  enum CodingKeys: String, CodingKey {
    case number
    case title
    case body
    case labels
    case updatedAt = "updated_at"
    case state
  }
}
