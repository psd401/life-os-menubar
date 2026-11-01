import Foundation
import Testing

@testable import LifeOSMenubarCore

@Suite(.serialized)
struct GitHubIssueDetailClientTests {
  @Test
  func fetchesEveryCommentPageAndReturnsChronologicalThread() async throws {
    DetailURLProtocolStub.handler = { request in
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer detail-token")

      let payload = try JSONDecoder().decode(
        DetailRequest.self,
        from: try detailRequestBody(from: request)
      )
      #expect(payload.variables.number == 42)
      #expect(payload.query.contains("comments(first: 100"))

      if payload.variables.cursor == nil {
        return try detailResponse(
          for: request,
          json: issueDetailJSON(
            comments: """
              [{
                "id": "C_later",
                "author": {"login": "octocat"},
                "body": "Later",
                "createdAt": "2026-07-28T02:00:00Z",
                "updatedAt": "2026-07-28T02:00:00Z"
              }]
              """,
            hasNextPage: true,
            endCursor: "\"comment-page-2\""
          )
        )
      }

      #expect(payload.variables.cursor == "comment-page-2")
      return try detailResponse(
        for: request,
        json: issueDetailJSON(
          comments: """
            [{
              "id": "C_earlier",
              "author": null,
              "body": "Earlier",
              "createdAt": "2026-07-28T01:00:00.123Z",
              "updatedAt": "2026-07-28T01:00:00.123Z"
            }]
            """,
          hasNextPage: false,
          endCursor: "null"
        )
      )
    }

    let detail = try await makeDetailClient().fetchIssueDetail(
      token: " detail-token ",
      number: 42
    )

    #expect(detail.issue.number == 42)
    #expect(detail.issue.body == "# Heading")
    #expect(detail.issue.labels.map(\.name) == ["status:next", "priority:p1"])
    #expect(detail.comments.map(\.body) == ["Earlier", "Later"])
    #expect(detail.comments.first?.authorLogin == "ghost")
  }

  @Test
  func rejectsCommentContinuationWithoutCursor() async {
    DetailURLProtocolStub.handler = { request in
      try detailResponse(
        for: request,
        json: issueDetailJSON(
          comments: "[]",
          hasNextPage: true,
          endCursor: "null"
        )
      )
    }

    await #expect(throws: GitHubIssueDetailClientError.missingPageCursor) {
      try await makeDetailClient().fetchIssueDetail(token: "token", number: 42)
    }
  }

  @Test
  func sendsTheConfiguredRepositoryRatherThanAnyBuiltInDefault() async throws {
    DetailURLProtocolStub.handler = { request in
      let payload = try JSONDecoder().decode(
        DetailRequest.self,
        from: try detailRequestBody(from: request)
      )
      #expect(payload.variables.owner == "acme")
      #expect(payload.variables.repository == "work-tasks")
      return try detailResponse(
        for: request,
        json: issueDetailJSON(comments: "[]", hasNextPage: false, endCursor: "null")
      )
    }

    let client = makeDetailClient(
      repositoryStore: InMemoryTaskRepositoryStore(
        repository: TaskRepository(owner: "acme", name: "work-tasks")
      )
    )
    _ = try await client.fetchIssueDetail(token: "detail-token", number: 42)
  }

  @Test
  func refusesToGuessARepositoryWhenNoneIsConfigured() async {
    DetailURLProtocolStub.handler = { _ in
      Issue.record("An unconfigured install must not reach GitHub.")
      throw URLError(.badURL)
    }

    await #expect(throws: TaskRepositoryConfigurationError.notConfigured) {
      try await makeDetailClient(repositoryStore: InMemoryTaskRepositoryStore())
        .fetchIssueDetail(token: "detail-token", number: 42)
    }
  }

  private func makeDetailClient(
    repositoryStore: any TaskRepositoryStoring = TaskRepositoryFixture.store
  ) -> GitHubGraphQLIssueDetailClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DetailURLProtocolStub.self]
    return GitHubGraphQLIssueDetailClient(
      session: URLSession(configuration: configuration),
      endpoint: URL(string: "https://example.test/graphql")!,
      repositoryStore: repositoryStore
    )
  }
}

private struct DetailRequest: Decodable {
  struct Variables: Decodable {
    let owner: String
    let repository: String
    let number: Int
    let cursor: String?
  }

  let query: String
  let variables: Variables
}

private func issueDetailJSON(
  comments: String,
  hasNextPage: Bool,
  endCursor: String
) -> String {
  """
  {
    "data": {
      "repository": {
        "issue": {
          "number": 42,
          "title": "Task",
          "body": "# Heading",
          "updatedAt": "2026-07-28T03:00:00Z",
          "state": "OPEN",
          "labels": {"nodes": [
            {"name": "status:next", "color": "ffffff"},
            {"name": "priority:p1", "color": "ff0000"}
          ]},
          "comments": {
            "nodes": \(comments),
            "pageInfo": {
              "hasNextPage": \(hasNextPage),
              "endCursor": \(endCursor)
            }
          }
        }
      }
    }
  }
  """
}

private func detailRequestBody(from request: URLRequest) throws -> Data {
  if let body = request.httpBody {
    return body
  }

  let stream = try #require(request.httpBodyStream)
  stream.open()
  defer {
    stream.close()
  }

  var data = Data()
  var buffer = [UInt8](repeating: 0, count: 1_024)
  while stream.hasBytesAvailable {
    let byteCount = stream.read(&buffer, maxLength: buffer.count)
    if byteCount < 0 {
      throw try #require(stream.streamError)
    }
    if byteCount == 0 {
      break
    }
    data.append(buffer, count: byteCount)
  }
  return data
}

private func detailResponse(
  for request: URLRequest,
  statusCode: Int = 200,
  json: String
) throws -> (HTTPURLResponse, Data) {
  let response = try #require(
    HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )
  )
  return (response, Data(json.utf8))
}

private final class DetailURLProtocolStub: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler:
    @Sendable (URLRequest) throws -> (
      HTTPURLResponse, Data
    ) = { request in
      throw URLError(.badServerResponse, userInfo: ["url": request.url as Any])
    }

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    do {
      let (response, data) = try Self.handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
