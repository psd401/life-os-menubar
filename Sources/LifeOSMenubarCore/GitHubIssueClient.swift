import Foundation

public protocol GitHubIssueFetching: Sendable {
  func fetchIssues(token: String, updatedAfter: Date?) async throws -> [LifeOSIssue]
}

public enum GitHubIssueClientError: LocalizedError, Equatable, Sendable {
  case emptyToken
  case invalidResponse
  case missingRepository(repository: String)
  case missingPageCursor
  case rejected
  case requestFailed(statusCode: Int)
  case graphQLError(message: String)
  case invalidUpdatedAt(String)

  public var errorDescription: String? {
    switch self {
    case .emptyToken:
      "Add a GitHub token in Settings before refreshing."
    case .invalidResponse:
      "GitHub returned an invalid issue response."
    case .missingRepository(let repository):
      "The GitHub token cannot read \(repository). Check the task repository in Settings."
    case .missingPageCursor:
      "GitHub returned an invalid pagination cursor."
    case .rejected:
      "GitHub rejected this token. Check that it is active and can read the repository."
    case .requestFailed(let statusCode):
      "GitHub issue refresh failed with HTTP status \(statusCode)."
    case .graphQLError(let message):
      "GitHub issue refresh failed: \(message)"
    case .invalidUpdatedAt(let value):
      "GitHub returned an invalid issue timestamp: \(value)."
    }
  }
}

public struct GitHubGraphQLIssueClient: GitHubIssueFetching {
  private let session: URLSession
  private let endpoint: URL
  private let repositoryStore: any TaskRepositoryStoring

  public init(
    session: URLSession = .shared,
    endpoint: URL = URL(string: "https://api.github.com/graphql")!,
    repositoryStore: any TaskRepositoryStoring = UserDefaultsTaskRepositoryStore()
  ) {
    self.session = session
    self.endpoint = endpoint
    self.repositoryStore = repositoryStore
  }

  public func fetchIssues(token: String, updatedAfter: Date?) async throws -> [LifeOSIssue] {
    let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedToken.isEmpty else {
      throw GitHubIssueClientError.emptyToken
    }

    let taskRepository = try repositoryStore.requireRepository()
    var cursor: String?
    var issuesByNumber: [Int: LifeOSIssue] = [:]

    repeat {
      let variables = IssueQueryVariables(
        owner: taskRepository.owner,
        repository: taskRepository.name,
        cursor: cursor,
        updatedAfter: updatedAfter.map(Self.githubTimestamp),
        states: updatedAfter == nil ? ["OPEN"] : ["OPEN", "CLOSED"]
      )
      let request = try makeRequest(token: trimmedToken, variables: variables)
      let response = try await perform(request)
      guard let repository = response.data?.repository else {
        throw GitHubIssueClientError.missingRepository(repository: taskRepository.slug)
      }

      for node in repository.issues.nodes {
        let issue = try Self.makeIssue(from: node)
        issuesByNumber[issue.number] = issue
      }

      guard repository.issues.pageInfo.hasNextPage else {
        cursor = nil
        break
      }
      guard let nextCursor = repository.issues.pageInfo.endCursor else {
        throw GitHubIssueClientError.missingPageCursor
      }
      cursor = nextCursor
    } while cursor != nil

    return issuesByNumber.values.sorted { $0.number < $1.number }
  }

  private func makeRequest(
    token: String,
    variables: IssueQueryVariables
  ) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.httpBody = try JSONEncoder().encode(
      GraphQLRequest(query: Self.issueQuery, variables: variables)
    )
    return request
  }

  private func perform(_ request: URLRequest) async throws -> IssueQueryResponse {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubIssueClientError.invalidResponse
    }
    guard httpResponse.statusCode == 200 else {
      if httpResponse.statusCode == 401 {
        throw GitHubIssueClientError.rejected
      }
      throw GitHubIssueClientError.requestFailed(statusCode: httpResponse.statusCode)
    }

    let payload = try JSONDecoder().decode(IssueQueryResponse.self, from: data)
    if let error = payload.errors?.first {
      throw GitHubIssueClientError.graphQLError(message: error.message)
    }
    return payload
  }

  private static func makeIssue(from node: IssueQueryResponse.IssueNode) throws -> LifeOSIssue {
    guard let updatedAt = parseGitHubTimestamp(node.updatedAt) else {
      throw GitHubIssueClientError.invalidUpdatedAt(node.updatedAt)
    }
    return LifeOSIssue(
      number: node.number,
      title: node.title,
      body: node.body ?? "",
      labels: node.labels.nodes.map { GitHubLabel(name: $0.name, color: $0.color) },
      updatedAt: updatedAt,
      state: node.state
    )
  }

  private static func githubTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private static func parseGitHubTimestamp(_ value: String) -> Date? {
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractionalFormatter.date(from: value) {
      return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }

  private static let issueQuery = """
    query LifeOSIssues(
      $owner: String!
      $repository: String!
      $cursor: String
      $updatedAfter: DateTime
      $states: [IssueState!]!
    ) {
      repository(owner: $owner, name: $repository) {
        issues(
          first: 100
          after: $cursor
          states: $states
          filterBy: { since: $updatedAfter }
          orderBy: { field: UPDATED_AT, direction: ASC }
        ) {
          nodes {
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
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    }
    """
}

private struct GraphQLRequest<Variables: Encodable>: Encodable {
  let query: String
  let variables: Variables
}

private struct IssueQueryVariables: Encodable {
  let owner: String
  let repository: String
  let cursor: String?
  let updatedAfter: String?
  let states: [String]
}

private struct IssueQueryResponse: Decodable {
  struct ResponseData: Decodable {
    let repository: Repository?
  }

  struct Repository: Decodable {
    let issues: IssueConnection
  }

  struct IssueConnection: Decodable {
    let nodes: [IssueNode]
    let pageInfo: PageInfo
  }

  struct IssueNode: Decodable {
    struct LabelConnection: Decodable {
      let nodes: [LabelNode]
    }

    struct LabelNode: Decodable {
      let name: String
      let color: String
    }

    let number: Int
    let title: String
    let body: String?
    let updatedAt: String
    let state: GitHubIssueState
    let labels: LabelConnection
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
