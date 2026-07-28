import Foundation

public protocol GitHubTokenValidating: Sendable {
  func validate(token: String) async throws -> String
}

public enum GitHubTokenValidationError: LocalizedError, Equatable, Sendable {
  case emptyToken
  case invalidResponse
  case rejected
  case requestFailed(statusCode: Int)
  case graphQLError(message: String)

  public var errorDescription: String? {
    switch self {
    case .emptyToken:
      "Enter a GitHub personal access token."
    case .invalidResponse:
      "GitHub returned an invalid response."
    case .rejected:
      "GitHub rejected this token. Check that it is active and can read the repository."
    case .requestFailed(let statusCode):
      "GitHub validation failed with HTTP status \(statusCode)."
    case .graphQLError(let message):
      "GitHub validation failed: \(message)"
    }
  }
}

public struct GitHubTokenValidator: GitHubTokenValidating {
  private let session: URLSession
  private let endpoint: URL

  public init(
    session: URLSession = .shared,
    endpoint: URL = URL(string: "https://api.github.com/graphql")!
  ) {
    self.session = session
    self.endpoint = endpoint
  }

  public func validate(token: String) async throws -> String {
    let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedToken.isEmpty else {
      throw GitHubTokenValidationError.emptyToken
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.httpBody = try JSONEncoder().encode(
      GraphQLRequest(query: "query ViewerLogin { viewer { login } }")
    )

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubTokenValidationError.invalidResponse
    }
    guard httpResponse.statusCode == 200 else {
      if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
        throw GitHubTokenValidationError.rejected
      }
      throw GitHubTokenValidationError.requestFailed(statusCode: httpResponse.statusCode)
    }

    let payload = try JSONDecoder().decode(ViewerResponse.self, from: data)
    if let error = payload.errors?.first {
      throw GitHubTokenValidationError.graphQLError(message: error.message)
    }
    guard let login = payload.data?.viewer.login, !login.isEmpty else {
      throw GitHubTokenValidationError.invalidResponse
    }
    return login
  }
}

private struct GraphQLRequest: Encodable {
  let query: String
}

private struct ViewerResponse: Decodable {
  struct ResponseData: Decodable {
    struct Viewer: Decodable {
      let login: String
    }

    let viewer: Viewer
  }

  struct ResponseError: Decodable {
    let message: String
  }

  let data: ResponseData?
  let errors: [ResponseError]?
}
