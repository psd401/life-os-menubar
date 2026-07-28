import Foundation
import Testing

@testable import LifeOSMenubarCore

@Suite(.serialized)
struct GitHubIssueMutationClientTests {
  @Test
  func postsTrimmedCommentToExpectedRESTEndpoint() async throws {
    MutationURLProtocolStub.handler = { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.path == "/repos/krishagel/life-os/issues/42/comments")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer mutation-token")
      let body = try JSONDecoder().decode(
        CommentRequestPayload.self,
        from: try mutationRequestBody(from: request)
      )
      #expect(body.body == "Ship it")
      return try mutationResponse(
        for: request,
        statusCode: 201,
        json: """
          {
            "node_id": "IC_comment",
            "user": {"login": "octocat"},
            "body": "Ship it",
            "created_at": "2026-07-28T03:00:00Z",
            "updated_at": "2026-07-28T03:00:00Z"
          }
          """
      )
    }

    let comment = try await makeMutationClient().addComment(
      token: " mutation-token ",
      issueNumber: 42,
      body: "  Ship it\n"
    )

    #expect(comment.id == "IC_comment")
    #expect(comment.authorLogin == "octocat")
    #expect(comment.body == "Ship it")
  }

  @Test
  func closesIssueWithLabelsAndStateInOnePatch() async throws {
    MutationURLProtocolStub.handler = { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.url?.path == "/repos/krishagel/life-os/issues/42")
      let body = try JSONDecoder().decode(
        UpdateRequestPayload.self,
        from: try mutationRequestBody(from: request)
      )
      #expect(body.labels == ["status:done", "priority:p1", "area:work"])
      #expect(body.state == "closed")
      return try mutationResponse(
        for: request,
        json: issueMutationJSON(state: "closed")
      )
    }

    let issue = try await makeMutationClient().updateIssue(
      token: "token",
      issueNumber: 42,
      labels: ["status:done", "priority:p1", "area:work"],
      state: .closed
    )

    #expect(issue.state == .closed)
    #expect(issue.labels.map(\.name) == ["status:done", "priority:p1", "area:work"])
  }

  @Test
  func createsIssueWithTrimmedContentAndContractLabels() async throws {
    MutationURLProtocolStub.handler = { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.path == "/repos/krishagel/life-os/issues")
      let body = try JSONDecoder().decode(
        CreateRequestPayload.self,
        from: try mutationRequestBody(from: request)
      )
      #expect(body.title == "Captured task")
      #expect(body.body == "Remember the details")
      #expect(
        body.labels
          == ["status:inbox", "type:task", "source:manual", "priority:p2"]
      )
      return try mutationResponse(
        for: request,
        statusCode: 201,
        json: issueMutationJSON(state: "open")
      )
    }

    let issue = try await makeMutationClient().createIssue(
      token: "token",
      title: "  Captured task\n",
      body: "\nRemember the details  ",
      labels: ["status:inbox", "type:task", "source:manual", "priority:p2"]
    )

    #expect(issue.state == .open)
    #expect(issue.number == 42)
  }

  @Test
  func rejectsEmptyIssueTitleBeforeSendingRequest() async {
    await #expect(throws: GitHubIssueMutationClientError.emptyTitle) {
      try await makeMutationClient().createIssue(
        token: "token",
        title: " \n ",
        body: "",
        labels: []
      )
    }
  }

  @Test
  func labelOnlyUpdateOmitsState() async throws {
    MutationURLProtocolStub.handler = { request in
      let bodyData = try mutationRequestBody(from: request)
      let bodyObject = try #require(
        JSONSerialization.jsonObject(with: bodyData) as? [String: NSObject]
      )
      #expect(bodyObject["labels"] != nil)
      #expect(bodyObject["state"] == nil)
      return try mutationResponse(
        for: request,
        json: issueMutationJSON(state: "open")
      )
    }

    _ = try await makeMutationClient().updateIssue(
      token: "token",
      issueNumber: 42,
      labels: ["status:done", "priority:p1", "area:work"],
      state: nil
    )
  }

  @Test
  func surfacesValidationFailureWithoutReturningAnIssue() async {
    MutationURLProtocolStub.handler = { request in
      try mutationResponse(for: request, statusCode: 422, json: "{}")
    }

    await #expect(
      throws: GitHubIssueMutationClientError.requestFailed(statusCode: 422)
    ) {
      try await makeMutationClient().updateIssue(
        token: "token",
        issueNumber: 42,
        labels: ["missing-label"],
        state: nil
      )
    }
  }

  private func makeMutationClient() -> GitHubRESTIssueClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MutationURLProtocolStub.self]
    return GitHubRESTIssueClient(
      session: URLSession(configuration: configuration),
      endpoint: URL(string: "https://example.test")!
    )
  }
}

private struct CommentRequestPayload: Decodable {
  let body: String
}

private struct UpdateRequestPayload: Decodable {
  let labels: [String]
  let state: String?
}

private struct CreateRequestPayload: Decodable {
  let title: String
  let body: String?
  let labels: [String]
}

private func issueMutationJSON(state: String) -> String {
  """
  {
    "number": 42,
    "title": "Task",
    "body": "# Body",
    "labels": [
      {"name": "status:done", "color": "ffffff"},
      {"name": "priority:p1", "color": "ff0000"},
      {"name": "area:work", "color": "000000"}
    ],
    "updated_at": "2026-07-28T03:00:00Z",
    "state": "\(state)"
  }
  """
}

private func mutationRequestBody(from request: URLRequest) throws -> Data {
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

private func mutationResponse(
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

private final class MutationURLProtocolStub: URLProtocol, @unchecked Sendable {
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
