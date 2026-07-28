import Foundation

public protocol GitHubIssueDetailFetching: Sendable {
  func fetchIssueDetail(token: String, number: Int) async throws -> LifeOSIssueDetail
}

public enum GitHubIssueDetailClientError: LocalizedError, Equatable, Sendable {
  case emptyToken
  case invalidResponse
  case missingIssue
  case missingPageCursor
  case rejected
  case requestFailed(statusCode: Int)
  case graphQLError(message: String)
  case invalidTimestamp(String)

  public var errorDescription: String? {
    switch self {
    case .emptyToken:
      "Add a GitHub token in Settings before loading task details."
    case .invalidResponse:
      "GitHub returned an invalid task detail response."
    case .missingIssue:
      "This task could not be found on GitHub."
    case .missingPageCursor:
      "GitHub returned an invalid comment pagination cursor."
    case .rejected:
      "GitHub rejected this token. Check that it can read the repository."
    case .requestFailed(let statusCode):
      "GitHub task detail loading failed with HTTP status \(statusCode)."
    case .graphQLError(let message):
      "GitHub task detail loading failed: \(message)"
    case .invalidTimestamp(let value):
      "GitHub returned an invalid timestamp: \(value)."
    }
  }
}

public struct GitHubGraphQLIssueDetailClient: GitHubIssueDetailFetching {
  private let session: URLSession
  private let endpoint: URL
  private let owner: String
  private let repository: String

  public init(
    session: URLSession = .shared,
    endpoint: URL = URL(string: "https://api.github.com/graphql")!,
    owner: String = "krishagel",
    repository: String = "life-os"
  ) {
    self.session = session
    self.endpoint = endpoint
    self.owner = owner
    self.repository = repository
  }

  public func fetchIssueDetail(token: String, number: Int) async throws -> LifeOSIssueDetail {
    let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else {
      throw GitHubIssueDetailClientError.emptyToken
    }

    var cursor: String?
    var issue: LifeOSIssue?
    var commentsByID: [String: GitHubComment] = [:]

    repeat {
      let variables = IssueDetailQueryVariables(
        owner: owner,
        repository: repository,
        number: number,
        cursor: cursor
      )
      let request = try makeRequest(token: candidate, variables: variables)
      let payload = try await perform(request)
      guard let node = payload.data?.repository?.issue else {
        throw GitHubIssueDetailClientError.missingIssue
      }

      issue = try Self.makeIssue(from: node)
      for commentNode in node.comments.nodes {
        let comment = try Self.makeComment(from: commentNode)
        commentsByID[comment.id] = comment
      }

      guard node.comments.pageInfo.hasNextPage else {
        cursor = nil
        break
      }
      guard let nextCursor = node.comments.pageInfo.endCursor else {
        throw GitHubIssueDetailClientError.missingPageCursor
      }
      cursor = nextCursor
    } while cursor != nil

    guard let issue else {
      throw GitHubIssueDetailClientError.missingIssue
    }
    let comments = commentsByID.values.sorted {
      if $0.createdAt != $1.createdAt {
        return $0.createdAt < $1.createdAt
      }
      return $0.id < $1.id
    }
    return LifeOSIssueDetail(issue: issue, comments: comments)
  }

  private func makeRequest(
    token: String,
    variables: IssueDetailQueryVariables
  ) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.httpBody = try JSONEncoder().encode(
      IssueDetailGraphQLRequest(query: Self.query, variables: variables)
    )
    return request
  }

  private func perform(_ request: URLRequest) async throws -> IssueDetailQueryResponse {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubIssueDetailClientError.invalidResponse
    }
    guard httpResponse.statusCode == 200 else {
      if httpResponse.statusCode == 401 {
        throw GitHubIssueDetailClientError.rejected
      }
      throw GitHubIssueDetailClientError.requestFailed(statusCode: httpResponse.statusCode)
    }

    let payload = try JSONDecoder().decode(IssueDetailQueryResponse.self, from: data)
    if let error = payload.errors?.first {
      throw GitHubIssueDetailClientError.graphQLError(message: error.message)
    }
    return payload
  }

  private static func makeIssue(
    from node: IssueDetailQueryResponse.IssueNode
  ) throws -> LifeOSIssue {
    let updatedAt = try parseTimestamp(node.updatedAt)
    return LifeOSIssue(
      number: node.number,
      title: node.title,
      body: node.body,
      labels: node.labels.nodes.map { GitHubLabel(name: $0.name, color: $0.color) },
      updatedAt: updatedAt,
      state: node.state
    )
  }

  private static func makeComment(
    from node: IssueDetailQueryResponse.CommentNode
  ) throws -> GitHubComment {
    GitHubComment(
      id: node.id,
      authorLogin: node.author?.login ?? "ghost",
      body: node.body,
      createdAt: try parseTimestamp(node.createdAt),
      updatedAt: try parseTimestamp(node.updatedAt)
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
      throw GitHubIssueDetailClientError.invalidTimestamp(value)
    }
    return date
  }

  private static let query = """
    query LifeOSIssueDetail(
      $owner: String!
      $repository: String!
      $number: Int!
      $cursor: String
    ) {
      repository(owner: $owner, name: $repository) {
        issue(number: $number) {
          number
          title
          body
          updatedAt
          state
          labels(first: 100) {
            nodes {
              name
              color
            }
          }
          comments(first: 100, after: $cursor) {
            nodes {
              id
              author {
                login
              }
              body
              createdAt
              updatedAt
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      }
    }
    """
}

private struct IssueDetailGraphQLRequest<Variables: Encodable>: Encodable {
  let query: String
  let variables: Variables
}

private struct IssueDetailQueryVariables: Encodable {
  let owner: String
  let repository: String
  let number: Int
  let cursor: String?
}

private struct IssueDetailQueryResponse: Decodable {
  struct ResponseData: Decodable {
    let repository: Repository?
  }

  struct Repository: Decodable {
    let issue: IssueNode?
  }

  struct IssueNode: Decodable {
    struct LabelConnection: Decodable {
      let nodes: [LabelNode]
    }

    struct LabelNode: Decodable {
      let name: String
      let color: String
    }

    struct CommentConnection: Decodable {
      let nodes: [CommentNode]
      let pageInfo: PageInfo
    }

    let number: Int
    let title: String
    let body: String
    let updatedAt: String
    let state: GitHubIssueState
    let labels: LabelConnection
    let comments: CommentConnection
  }

  struct CommentNode: Decodable {
    struct Author: Decodable {
      let login: String
    }

    let id: String
    let author: Author?
    let body: String
    let createdAt: String
    let updatedAt: String
  }

  struct PageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
  }

  struct ResponseError: Decodable {
    let message: String
  }

  let data: ResponseData?
  let errors: [ResponseError]?
}
