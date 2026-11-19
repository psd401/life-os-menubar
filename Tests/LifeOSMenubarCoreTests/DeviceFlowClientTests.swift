import Foundation
import Testing

@testable import LifeOSMenubarCore

@Suite(.serialized)
struct DeviceFlowClientTests {
  @Test
  func requestsDeviceCodeWithClientIDAndScopes() async throws {
    URLProtocolStub.handler = { request in
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")

      let form = try formFields(from: request)
      #expect(form["client_id"] == "test-client-id")
      #expect(form["scope"] == "repo read:project")

      return (
        try response(for: request, statusCode: 200),
        Data(
          """
          {"device_code":"dc-1","user_code":"WDJB-MJHT",\
          "verification_uri":"https://github.com/login/device",\
          "expires_in":900,"interval":5}
          """.utf8)
      )
    }

    let client = makeClient()

    let authorization = try await client.requestDeviceAuthorization(
      clientID: "test-client-id",
      scopes: ["repo", "read:project"]
    )

    #expect(authorization.deviceCode == "dc-1")
    #expect(authorization.userCode == "WDJB-MJHT")
    #expect(authorization.verificationURL == URL(string: "https://github.com/login/device")!)
    #expect(authorization.expiresInSeconds == 900)
    #expect(authorization.pollIntervalSeconds == 5)
  }

  @Test
  func redeemSendsDeviceCodeGrantAndReturnsAccessToken() async throws {
    URLProtocolStub.handler = { request in
      let form = try formFields(from: request)
      #expect(form["client_id"] == "test-client-id")
      #expect(form["device_code"] == "dc-1")
      #expect(form["grant_type"] == "urn:ietf:params:oauth:grant-type:device_code")

      return (
        try response(for: request, statusCode: 200),
        Data(
          #"{"access_token":"gho_test","token_type":"bearer","scope":"repo,read:project"}"#.utf8
        )
      )
    }

    let outcome = try await makeClient().redeemAccessToken(
      clientID: "test-client-id",
      deviceCode: "dc-1"
    )

    // No expires_in and no refresh_token: a token that does not expire.
    #expect(outcome == .authorized(GitHubTokenGrant(accessToken: "gho_test")))
  }

  @Test
  func redeemKeepsTheRefreshTokenAndLifetimeOfAnExpiringToken() async throws {
    // What GitHub sends once the OAuth App has token expiration on, which is
    // the default for every OAuth App registered since 2026-08-14. Dropping
    // the refresh token here is what made every sign-in last eight hours.
    URLProtocolStub.handler = { request in
      (
        try response(for: request, statusCode: 200),
        Data(
          """
          {"access_token":"gho_test","expires_in":28800,"refresh_token":"ghr_test",\
          "refresh_token_expires_in":15897600,"token_type":"bearer",\
          "scope":"repo,read:project"}
          """.utf8)
      )
    }

    let outcome = try await makeClient().redeemAccessToken(
      clientID: "test-client-id",
      deviceCode: "dc-1"
    )

    #expect(
      outcome
        == .authorized(
          GitHubTokenGrant(
            accessToken: "gho_test",
            accessTokenLifetimeSeconds: 28_800,
            refreshToken: "ghr_test"
          )
        )
    )
  }

  @Test
  func refreshSendsTheRefreshTokenGrantWithoutAClientSecret() async throws {
    URLProtocolStub.handler = { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.path == "/login/oauth/access_token")
      #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")

      let form = try formFields(from: request)
      #expect(form["client_id"] == "test-client-id")
      #expect(form["grant_type"] == "refresh_token")
      #expect(form["refresh_token"] == "ghr_old")
      // A device-flow token is refreshed without the client secret, which a
      // native app has no way to keep secret anyway.
      #expect(form["client_secret"] == nil)

      return (
        try response(for: request, statusCode: 200),
        Data(
          """
          {"access_token":"gho_new","expires_in":28800,"refresh_token":"ghr_new",\
          "refresh_token_expires_in":15897600,"token_type":"bearer","scope":""}
          """.utf8)
      )
    }

    let grant = try await makeClient().refreshAccessToken(
      clientID: "test-client-id",
      refreshToken: "ghr_old"
    )

    #expect(
      grant
        == GitHubTokenGrant(
          accessToken: "gho_new",
          accessTokenLifetimeSeconds: 28_800,
          refreshToken: "ghr_new"
        )
    )
  }

  @Test(arguments: [200, 400])
  func refreshMapsARejectedRefreshTokenToAnExpiredSignIn(statusCode: Int) async {
    URLProtocolStub.handler = { request in
      (
        try response(for: request, statusCode: statusCode),
        Data(
          #"{"error":"bad_refresh_token","error_description":"The refresh token is invalid."}"#
            .utf8
        )
      )
    }

    await #expect(throws: DeviceFlowError.badRefreshToken) {
      try await makeClient().refreshAccessToken(
        clientID: "test-client-id",
        refreshToken: "ghr_spent"
      )
    }
  }

  @Test
  func refreshReportsAServerErrorWithoutAnOAuthErrorAsAFailedRequest() async {
    URLProtocolStub.handler = { request in
      (try response(for: request, statusCode: 502), Data("<html>Bad gateway</html>".utf8))
    }

    await #expect(throws: DeviceFlowError.requestFailed(statusCode: 502)) {
      try await makeClient().refreshAccessToken(
        clientID: "test-client-id",
        refreshToken: "ghr_old"
      )
    }
  }

  @Test
  func refreshRejectsASuccessResponseWithNoAccessToken() async {
    URLProtocolStub.handler = { request in
      (try response(for: request, statusCode: 200), Data(#"{"token_type":"bearer"}"#.utf8))
    }

    await #expect(throws: DeviceFlowError.invalidResponse) {
      try await makeClient().refreshAccessToken(
        clientID: "test-client-id",
        refreshToken: "ghr_old"
      )
    }
  }

  @Test
  func treatsAuthorizationPendingAsAPendingOutcomeNotAFailure() async throws {
    URLProtocolStub.handler = { request in
      (
        try response(for: request, statusCode: 200),
        Data(
          #"{"error":"authorization_pending","error_description":"Still waiting."}"#.utf8
        )
      )
    }

    let outcome = try await makeClient().redeemAccessToken(
      clientID: "test-client-id",
      deviceCode: "dc-1"
    )

    #expect(outcome == .authorizationPending)
  }

  @Test
  func reportsTheNewIntervalWhenGitHubAsksTheAppToSlowDown() async throws {
    URLProtocolStub.handler = { request in
      (
        try response(for: request, statusCode: 200),
        Data(
          #"{"error":"slow_down","error_description":"Too fast.","interval":10}"#.utf8
        )
      )
    }

    let outcome = try await makeClient().redeemAccessToken(
      clientID: "test-client-id",
      deviceCode: "dc-1"
    )

    #expect(outcome == .slowDown(pollIntervalSeconds: 10))
  }

  @Test(arguments: [
    ("expired_token", DeviceFlowError.expiredCode),
    ("access_denied", DeviceFlowError.accessDenied),
    ("device_flow_disabled", DeviceFlowError.deviceFlowDisabled),
    ("incorrect_client_credentials", DeviceFlowError.incorrectClientCredentials),
    ("incorrect_device_code", DeviceFlowError.incorrectDeviceCode),
    ("unsupported_grant_type", DeviceFlowError.unsupportedGrantType),
  ])
  func mapsTerminalDeviceFlowErrorCodes(code: String, expected: DeviceFlowError) async {
    URLProtocolStub.handler = { request in
      (try response(for: request, statusCode: 200), Data(#"{"error":"\#(code)"}"#.utf8))
    }

    await #expect(throws: expected) {
      try await makeClient().redeemAccessToken(clientID: "test-client-id", deviceCode: "dc-1")
    }
  }

  @Test
  func surfacesAnUnrecognizedErrorCodeWithItsDescription() async {
    URLProtocolStub.handler = { request in
      (
        try response(for: request, statusCode: 200),
        Data(
          #"{"error":"teapot","error_description":"GitHub is a teapot."}"#.utf8
        )
      )
    }

    await #expect(
      throws: DeviceFlowError.unexpected(code: "teapot", description: "GitHub is a teapot.")
    ) {
      try await makeClient().redeemAccessToken(clientID: "test-client-id", deviceCode: "dc-1")
    }
  }

  @Test
  func mapsANonSuccessStatusToARequestFailure() async {
    URLProtocolStub.handler = { request in
      (try response(for: request, statusCode: 503), Data())
    }

    await #expect(throws: DeviceFlowError.requestFailed(statusCode: 503)) {
      try await makeClient().requestDeviceAuthorization(
        clientID: "test-client-id",
        scopes: ["repo"]
      )
    }
  }

  @Test(arguments: ["", "life-os-menubar://steal", "http://github.com/login/device"])
  func rejectsAVerificationURLThatIsNotHTTPS(verificationURI: String) async {
    URLProtocolStub.handler = { request in
      (
        try response(for: request, statusCode: 200),
        Data(
          """
          {"device_code":"dc-1","user_code":"WDJB-MJHT",\
          "verification_uri":"\(verificationURI)","expires_in":900,"interval":5}
          """.utf8)
      )
    }

    // The URL is handed to the system to open, so anything but https is refused.
    await #expect(throws: DeviceFlowError.invalidResponse) {
      try await makeClient().requestDeviceAuthorization(
        clientID: "test-client-id",
        scopes: ["repo"]
      )
    }
  }

  @Test
  func clampsAbsurdDurationsSoThePollArithmeticCannotOverflow() async throws {
    URLProtocolStub.handler = { request in
      (
        try response(for: request, statusCode: 200),
        Data(
          """
          {"device_code":"dc-1","user_code":"WDJB-MJHT",\
          "verification_uri":"https://github.com/login/device",\
          "expires_in":9223372036854775807,"interval":9223372036854775807}
          """.utf8)
      )
    }

    let authorization = try await makeClient().requestDeviceAuthorization(
      clientID: "test-client-id",
      scopes: ["repo"]
    )

    #expect(authorization.expiresInSeconds == DeviceFlowSeconds.maximum)
    #expect(authorization.pollIntervalSeconds == DeviceFlowSeconds.maximum)
  }

  @Test
  func clampsAnAbsurdSlowDownInterval() async throws {
    URLProtocolStub.handler = { request in
      (
        try response(for: request, statusCode: 200),
        Data(#"{"error":"slow_down","interval":9223372036854775807}"#.utf8)
      )
    }

    let outcome = try await makeClient().redeemAccessToken(
      clientID: "test-client-id",
      deviceCode: "dc-1"
    )

    #expect(outcome == .slowDown(pollIntervalSeconds: DeviceFlowSeconds.maximum))
  }

  @Test
  func rejectsADeviceCodeResponseMissingTheCodesThemselves() async {
    URLProtocolStub.handler = { request in
      (
        try response(for: request, statusCode: 200),
        Data(
          """
          {"user_code":"","verification_uri":"https://github.com/login/device",\
          "expires_in":900,"interval":5}
          """.utf8)
      )
    }

    await #expect(throws: DeviceFlowError.invalidResponse) {
      try await makeClient().requestDeviceAuthorization(
        clientID: "test-client-id",
        scopes: ["repo"]
      )
    }
  }

  private func makeClient() -> GitHubDeviceFlowClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return GitHubDeviceFlowClient(
      session: URLSession(configuration: configuration),
      deviceCodeEndpoint: URL(string: "https://example.test/login/device/code")!,
      accessTokenEndpoint: URL(string: "https://example.test/login/oauth/access_token")!
    )
  }
}

private func response(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
  try #require(
    HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )
  )
}

private func formFields(from request: URLRequest) throws -> [String: String] {
  let body = try requestBody(from: request)
  let encoded = try #require(String(data: body, encoding: .utf8))
  var components = URLComponents()
  components.percentEncodedQuery = encoded
  return Dictionary(
    (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
    uniquingKeysWith: { first, _ in first }
  )
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
