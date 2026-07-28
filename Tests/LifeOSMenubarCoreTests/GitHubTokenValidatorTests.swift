import Foundation
import Testing

@testable import LifeOSMenubarCore

@Suite(.serialized)
struct GitHubTokenValidatorTests {
  @Test
  func sendsViewerQueryAndReturnsLogin() async throws {
    URLProtocolStub.handler = { request in
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")

      let body = try requestBody(from: request)
      let requestPayload = try JSONDecoder().decode(RequestPayload.self, from: body)
      #expect(requestPayload.query.contains("viewer"))

      let response = try #require(
        HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      let data = Data(#"{"data":{"viewer":{"login":"octocat"}}}"#.utf8)
      return (response, data)
    }

    let validator = GitHubTokenValidator(
      session: makeStubbedSession(),
      endpoint: URL(string: "https://example.test/graphql")!
    )

    let login = try await validator.validate(token: " test-token ")

    #expect(login == "octocat")
  }

  @Test
  func mapsUnauthorizedResponseToRejectedError() async {
    URLProtocolStub.handler = { request in
      let response = try #require(
        HTTPURLResponse(
          url: request.url!,
          statusCode: 401,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (response, Data())
    }

    let validator = GitHubTokenValidator(
      session: makeStubbedSession(),
      endpoint: URL(string: "https://example.test/graphql")!
    )

    await #expect(throws: GitHubTokenValidationError.rejected) {
      try await validator.validate(token: "invalid-token")
    }
  }

  @Test
  func preservesForbiddenStatusForPermissionOrRateLimitFailures() async {
    URLProtocolStub.handler = { request in
      let response = try #require(
        HTTPURLResponse(
          url: request.url!,
          statusCode: 403,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (response, Data())
    }

    let validator = GitHubTokenValidator(
      session: makeStubbedSession(),
      endpoint: URL(string: "https://example.test/graphql")!
    )

    await #expect(throws: GitHubTokenValidationError.requestFailed(statusCode: 403)) {
      try await validator.validate(token: "valid-but-forbidden-token")
    }
  }

  private func makeStubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSession(configuration: configuration)
  }
}

private struct RequestPayload: Decodable {
  let query: String
}

private func requestBody(from request: URLRequest) throws -> Data {
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

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data) =
    { request in
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
