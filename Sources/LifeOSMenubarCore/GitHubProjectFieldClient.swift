import Foundation

public enum GitHubProjectFieldClientError: LocalizedError, Equatable, Sendable {
  case emptyToken
  case invalidResponse
  case missingRepository
  case missingPageCursor
  case rejected
  case requestFailed(statusCode: Int)
  case graphQLError(message: String)
  case invalidDate(String)

  public var errorDescription: String? {
    switch self {
    case .emptyToken:
      "Add a GitHub token in Settings before refreshing project dates."
    case .invalidResponse:
      "GitHub returned an invalid Project v2 response."
    case .missingRepository:
      "The GitHub token cannot read krishagel/life-os."
    case .missingPageCursor:
      "GitHub returned an invalid Project v2 pagination cursor."
    case .rejected:
      "GitHub rejected this token. Check that it is active and can read the repository."
    case .requestFailed(let statusCode):
      "GitHub Project v2 refresh failed with HTTP status \(statusCode)."
    case .graphQLError(let message):
      "GitHub Project v2 refresh failed: \(message)"
    case .invalidDate(let value):
      "GitHub returned an invalid Project v2 date: \(value)."
    }
  }
}

public struct GitHubGraphQLProjectFieldClient: GitHubProjectFieldFetching {
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

  public func fetchProjectFields(token: String) async throws -> ProjectFieldFetchResult {
    let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedToken.isEmpty else {
      throw GitHubProjectFieldClientError.emptyToken
    }

    var cursor: String?
    var fieldsByIssueNumber: [Int: IssueProjectFields] = [:]

    repeat {
      let request = try makeRequest(
        token: trimmedToken,
        variables: ProjectFieldQueryVariables(
          owner: owner,
          repository: repository,
          cursor: cursor
        )
      )
      let response = try await perform(request)
      if response.errors?.contains(where: { Self.isMissingProjectScope($0.message) }) == true {
        return .missingScope
      }
      if let error = response.errors?.first {
        throw GitHubProjectFieldClientError.graphQLError(message: error.message)
      }
      guard let repository = response.data?.repository else {
        throw GitHubProjectFieldClientError.missingRepository
      }

      for node in repository.issues.nodes {
        fieldsByIssueNumber[node.number] = try Self.makeFields(from: node)
      }

      guard repository.issues.pageInfo.hasNextPage else {
        cursor = nil
        break
      }
      guard let nextCursor = repository.issues.pageInfo.endCursor else {
        throw GitHubProjectFieldClientError.missingPageCursor
      }
      cursor = nextCursor
    } while cursor != nil

    return ProjectFieldFetchResult(
      fieldsByIssueNumber: fieldsByIssueNumber,
      access: .available
    )
  }

  private func makeRequest(
    token: String,
    variables: ProjectFieldQueryVariables
  ) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.httpBody = try JSONEncoder().encode(
      ProjectGraphQLRequest(query: Self.projectFieldQuery, variables: variables)
    )
    return request
  }

  private func perform(_ request: URLRequest) async throws -> ProjectFieldQueryResponse {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubProjectFieldClientError.invalidResponse
    }
    guard httpResponse.statusCode == 200 else {
      if httpResponse.statusCode == 401 {
        throw GitHubProjectFieldClientError.rejected
      }
      throw GitHubProjectFieldClientError.requestFailed(statusCode: httpResponse.statusCode)
    }
    return try JSONDecoder().decode(ProjectFieldQueryResponse.self, from: data)
  }

  private static func makeFields(
    from node: ProjectFieldQueryResponse.IssueNode
  ) throws -> IssueProjectFields {
    var dueDate: ProjectDate?
    var deferUntil: ProjectDate?

    for projectItem in node.projectItems?.nodes ?? [] {
      if dueDate == nil, let value = projectItem.dueDate?.date {
        guard let parsedDate = ProjectDate(githubDate: value) else {
          throw GitHubProjectFieldClientError.invalidDate(value)
        }
        dueDate = parsedDate
      }
      if deferUntil == nil, let value = projectItem.deferUntil?.date {
        guard let parsedDate = ProjectDate(githubDate: value) else {
          throw GitHubProjectFieldClientError.invalidDate(value)
        }
        deferUntil = parsedDate
      }
    }

    return IssueProjectFields(dueDate: dueDate, deferUntil: deferUntil)
  }

  private static func isMissingProjectScope(_ message: String) -> Bool {
    let normalized = message.lowercased()
    return normalized.contains("read:project")
      || (normalized.contains("project") && normalized.contains("scope"))
  }

  private static let projectFieldQuery = """
    query LifeOSProjectFields(
      $owner: String!
      $repository: String!
      $cursor: String
    ) {
      repository(owner: $owner, name: $repository) {
        issues(
          first: 100
          after: $cursor
          states: OPEN
          orderBy: { field: UPDATED_AT, direction: ASC }
        ) {
          nodes {
            number
            projectItems(first: 100) {
              nodes {
                dueDate: fieldValueByName(name: "Due Date") {
                  ... on ProjectV2ItemFieldDateValue {
                    date
                  }
                }
                deferUntil: fieldValueByName(name: "Defer Until") {
                  ... on ProjectV2ItemFieldDateValue {
                    date
                  }
                }
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

private struct ProjectGraphQLRequest<Variables: Encodable>: Encodable {
  let query: String
  let variables: Variables
}

private struct ProjectFieldQueryVariables: Encodable {
  let owner: String
  let repository: String
  let cursor: String?
}

private struct ProjectFieldQueryResponse: Decodable {
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
    struct ProjectItemConnection: Decodable {
      let nodes: [ProjectItem]
    }

    struct ProjectItem: Decodable {
      struct DateValue: Decodable {
        let date: String?
      }

      let dueDate: DateValue?
      let deferUntil: DateValue?
    }

    let number: Int
    let projectItems: ProjectItemConnection?
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
