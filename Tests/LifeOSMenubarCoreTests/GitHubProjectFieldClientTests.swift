import Foundation
import Testing

@testable import LifeOSMenubarCore

@Suite(.serialized)
struct GitHubProjectFieldClientTests {
  @Test
  func fetchesDateFieldsForEveryPageOfOpenIssues() async throws {
    ProjectFieldURLProtocolStub.handler = { request in
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")

      let payload = try JSONDecoder().decode(
        ProjectFieldRequestPayload.self,
        from: try projectFieldRequestBody(from: request)
      )
      #expect(payload.query.contains("fieldValueByName(name: \"Due Date\")"))
      #expect(payload.query.contains("fieldValueByName(name: \"Defer Until\")"))
      #expect(!payload.query.lowercased().contains("mutation"))

      if payload.variables.cursor == nil {
        return try projectFieldResponse(
          for: request,
          json: """
            {
              "data": {
                "repository": {
                  "issues": {
                    "nodes": [{
                      "number": 41,
                      "projectItems": {
                        "nodes": [{
                          "dueDate": {"date": "2026-07-28"},
                          "deferUntil": {"date": "2026-07-27"}
                        }]
                      }
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
      return try projectFieldResponse(
        for: request,
        json: """
          {
            "data": {
              "repository": {
                "issues": {
                  "nodes": [
                    {
                      "number": 42,
                      "projectItems": {
                        "nodes": [{
                          "dueDate": {"date": "2026-07-29"},
                          "deferUntil": null
                        }]
                      }
                    },
                    {
                      "number": 43,
                      "projectItems": {"nodes": []}
                    }
                  ],
                  "pageInfo": {"hasNextPage": false, "endCursor": null}
                }
              }
            }
          }
          """
      )
    }

    let result = try await makeProjectFieldClient().fetchProjectFields(
      token: " test-token "
    )

    #expect(result.access == .available)
    #expect(result.fieldsByIssueNumber.keys.sorted() == [41, 42, 43])
    #expect(
      result.fieldsByIssueNumber[41]
        == IssueProjectFields(
          dueDate: ProjectDate(githubDate: "2026-07-28"),
          deferUntil: ProjectDate(githubDate: "2026-07-27")
        )
    )
    #expect(
      result.fieldsByIssueNumber[42]
        == IssueProjectFields(dueDate: ProjectDate(githubDate: "2026-07-29"))
    )
    #expect(result.fieldsByIssueNumber[43] == IssueProjectFields())
  }

  @Test
  func missingReadProjectScopeIsANonFatalCapabilityResult() async throws {
    ProjectFieldURLProtocolStub.handler = { request in
      try projectFieldResponse(
        for: request,
        json: """
          {
            "data": null,
            "errors": [{
              "message": "The projectItems field requires the read:project scope."
            }]
          }
          """
      )
    }

    let result = try await makeProjectFieldClient().fetchProjectFields(token: "token")

    #expect(result == .missingScope)
  }

  @Test
  func rejectsInvalidProjectDate() async {
    ProjectFieldURLProtocolStub.handler = { request in
      try projectFieldResponse(
        for: request,
        json: """
          {
            "data": {
              "repository": {
                "issues": {
                  "nodes": [{
                    "number": 41,
                    "projectItems": {
                      "nodes": [{
                        "dueDate": {"date": "2026-02-30"},
                        "deferUntil": null
                      }]
                    }
                  }],
                  "pageInfo": {"hasNextPage": false, "endCursor": null}
                }
              }
            }
          }
          """
      )
    }

    await #expect(throws: GitHubProjectFieldClientError.invalidDate("2026-02-30")) {
      try await makeProjectFieldClient().fetchProjectFields(token: "token")
    }
  }

  @Test
  func rejectsBlankTokenBeforeStartingARequest() async {
    await #expect(throws: GitHubProjectFieldClientError.emptyToken) {
      try await makeProjectFieldClient().fetchProjectFields(token: " \n ")
    }
  }

  private func makeProjectFieldClient() -> GitHubGraphQLProjectFieldClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ProjectFieldURLProtocolStub.self]
    return GitHubGraphQLProjectFieldClient(
      session: URLSession(configuration: configuration),
      endpoint: URL(string: "https://example.test/graphql")!
    )
  }
}

private struct ProjectFieldRequestPayload: Decodable {
  struct Variables: Decodable {
    let cursor: String?
  }

  let query: String
  let variables: Variables
}

private func projectFieldRequestBody(from request: URLRequest) throws -> Data {
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

private func projectFieldResponse(
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

private final class ProjectFieldURLProtocolStub: URLProtocol, @unchecked Sendable {
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
