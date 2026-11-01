import Foundation
import Testing

@testable import LifeOSMenubarCore

@Suite(.serialized)
struct GitHubIssueClientTests {
  @Test
  func fetchesEveryPageOfOpenIssues() async throws {
    GraphQLIssueURLProtocolStub.handler = { request in
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")

      let payload = try JSONDecoder().decode(
        TestIssueRequest.self,
        from: try graphQLRequestBody(from: request)
      )
      #expect(payload.query.contains("first: 100"))
      #expect(payload.variables.states == ["OPEN"])
      #expect(payload.variables.updatedAfter == nil)

      if payload.variables.cursor == nil {
        return try graphQLResponse(
          for: request,
          json: """
            {
              "data": {
                "repository": {
                  "issues": {
                    "nodes": [{
                      "number": 41,
                      "title": "First task",
                      "body": "First body",
                      "updatedAt": "2026-07-27T20:00:00Z",
                      "state": "OPEN",
                      "labels": {"nodes": [
                        {"name": "status:inbox", "color": "ffffff"}
                      ]}
                    }],
                    "pageInfo": {"hasNextPage": true, "endCursor": "next-page"}
                  }
                }
              }
            }
            """
        )
      }

      #expect(payload.variables.cursor == "next-page")
      return try graphQLResponse(
        for: request,
        json: """
          {
            "data": {
              "repository": {
                "issues": {
                  "nodes": [{
                    "number": 42,
                    "title": "Second task",
                    "body": null,
                    "updatedAt": "2026-07-27T21:00:00.123Z",
                    "state": "OPEN",
                    "labels": {"nodes": [
                      {"name": "status:next", "color": "000000"},
                      {"name": "priority:p1", "color": "ff0000"}
                    ]}
                  }],
                  "pageInfo": {"hasNextPage": false, "endCursor": null}
                }
              }
            }
          }
          """
      )
    }

    let client = makeClient()
    let issues = try await client.fetchIssues(token: " test-token ", updatedAfter: nil)

    #expect(issues.map(\.number) == [41, 42])
    #expect(issues[0].body == "First body")
    #expect(issues[1].body.isEmpty)
    #expect(issues[1].labels.map(\.name) == ["status:next", "priority:p1"])
  }

  @Test
  func deltaQuerySendsWatermarkAndIncludesClosedIssues() async throws {
    GraphQLIssueURLProtocolStub.handler = { request in
      let payload = try JSONDecoder().decode(
        TestIssueRequest.self,
        from: try graphQLRequestBody(from: request)
      )
      #expect(payload.variables.states == ["OPEN", "CLOSED"])
      #expect(payload.variables.updatedAfter == "2026-07-27T19:30:00.000Z")

      return try graphQLResponse(
        for: request,
        json: """
          {
            "data": {
              "repository": {
                "issues": {
                  "nodes": [{
                    "number": 41,
                    "title": "Closed task",
                    "body": "",
                    "updatedAt": "2026-07-27T20:00:00Z",
                    "state": "CLOSED",
                    "labels": {"nodes": []}
                  }],
                  "pageInfo": {"hasNextPage": false, "endCursor": null}
                }
              }
            }
          }
          """
      )
    }

    let watermark = try #require(
      ISO8601DateFormatter().date(from: "2026-07-27T19:30:00Z")
    )
    let issues = try await makeClient().fetchIssues(
      token: "test-token",
      updatedAfter: watermark
    )

    #expect(issues.count == 1)
    #expect(issues[0].state == .closed)
  }

  @Test
  func rejectsAContinuationPageWithoutACursor() async {
    GraphQLIssueURLProtocolStub.handler = { request in
      try graphQLResponse(
        for: request,
        json: """
          {
            "data": {
              "repository": {
                "issues": {
                  "nodes": [],
                  "pageInfo": {"hasNextPage": true, "endCursor": null}
                }
              }
            }
          }
          """
      )
    }

    await #expect(throws: GitHubIssueClientError.missingPageCursor) {
      try await makeClient().fetchIssues(token: "test-token", updatedAfter: nil)
    }
  }

  @Test
  func rejectsBlankTokenBeforeStartingARequest() async {
    await #expect(throws: GitHubIssueClientError.emptyToken) {
      try await makeClient().fetchIssues(token: " \n ", updatedAfter: nil)
    }
  }

  @Test
  func mapsUnauthorizedResponseToRejectedError() async {
    GraphQLIssueURLProtocolStub.handler = { request in
      try graphQLResponse(for: request, statusCode: 401, json: "")
    }

    await #expect(throws: GitHubIssueClientError.rejected) {
      try await makeClient().fetchIssues(token: "test-token", updatedAfter: nil)
    }
  }

  @Test
  func preservesNonUnauthorizedHTTPStatus() async {
    GraphQLIssueURLProtocolStub.handler = { request in
      try graphQLResponse(for: request, statusCode: 403, json: "")
    }

    await #expect(throws: GitHubIssueClientError.requestFailed(statusCode: 403)) {
      try await makeClient().fetchIssues(token: "test-token", updatedAfter: nil)
    }
  }

  @Test
  func surfacesTopLevelGraphQLError() async {
    GraphQLIssueURLProtocolStub.handler = { request in
      try graphQLResponse(
        for: request,
        json: """
          {
            "data": null,
            "errors": [{"message": "API rate limit exceeded"}]
          }
          """
      )
    }

    await #expect(
      throws: GitHubIssueClientError.graphQLError(message: "API rate limit exceeded")
    ) {
      try await makeClient().fetchIssues(token: "test-token", updatedAfter: nil)
    }
  }

  @Test
  func rejectsIssueWithInvalidUpdatedAt() async {
    GraphQLIssueURLProtocolStub.handler = { request in
      try graphQLResponse(
        for: request,
        json: """
          {
            "data": {
              "repository": {
                "issues": {
                  "nodes": [{
                    "number": 41,
                    "title": "Task",
                    "body": "",
                    "updatedAt": "not-a-date",
                    "state": "OPEN",
                    "labels": {"nodes": []}
                  }],
                  "pageInfo": {"hasNextPage": false, "endCursor": null}
                }
              }
            }
          }
          """
      )
    }

    await #expect(throws: GitHubIssueClientError.invalidUpdatedAt("not-a-date")) {
      try await makeClient().fetchIssues(token: "test-token", updatedAfter: nil)
    }
  }

  @Test
  func reportsMissingRepository() async {
    GraphQLIssueURLProtocolStub.handler = { request in
      try graphQLResponse(
        for: request,
        json: """
          {
            "data": {
              "repository": null
            }
          }
          """
      )
    }

    await #expect(throws: GitHubIssueClientError.missingRepository) {
      try await makeClient().fetchIssues(token: "test-token", updatedAfter: nil)
    }
  }

  private func makeClient() -> GitHubGraphQLIssueClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GraphQLIssueURLProtocolStub.self]
    return GitHubGraphQLIssueClient(
      session: URLSession(configuration: configuration),
      endpoint: URL(string: "https://example.test/graphql")!
    )
  }
}

private struct TestIssueRequest: Decodable {
  struct Variables: Decodable {
    let cursor: String?
    let updatedAfter: String?
    let states: [String]
  }

  let query: String
  let variables: Variables
}

private func graphQLRequestBody(from request: URLRequest) throws -> Data {
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

private func graphQLResponse(
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

private final class GraphQLIssueURLProtocolStub: URLProtocol, @unchecked Sendable {
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
