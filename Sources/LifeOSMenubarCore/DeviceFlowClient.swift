import Foundation

/// The OAuth App the device flow authenticates against.
///
/// A device-flow client ID is **not** a secret: the flow exists precisely
/// because a native app cannot keep a client secret, and the ID on its own
/// authorizes nothing without a user approving a code on github.com. So it
/// ships as a plain constant here rather than through the Keychain or Secrets
/// Manager that standard 04 rule 15a requires for real secrets. This constant
/// is the only credential in the codebase.
public enum GitHubOAuthApp {
  /// Empty until the OAuth App is registered under the psd401 org (see the
  /// README). While it is empty, `GitHubDeviceFlowAuthorizer.isAvailable` is
  /// false, Settings disables "Sign in with GitHub" and says why, and the
  /// advanced token path is the only way to authenticate.
  public static let clientID = ""

  /// Classic OAuth scopes. `read:project` is what lights up the Today view:
  /// user-owned Projects v2 is unreachable with a fine-grained token's
  /// org-only Projects permission. `repo` is the narrowest classic scope that
  /// can read and write issues on a private repo — and it is broad, which the
  /// README states next to both sign-in paths.
  public static let scopes = ["repo", "read:project"]
}

/// Bounds every duration GitHub sends before it reaches any arithmetic.
///
/// `expires_in` and `interval` arrive as untrusted integers. Swift's `Int`
/// addition traps on overflow, so an absurd value — whether from a tampered
/// response or a GitHub bug — would crash the app inside the poll loop rather
/// than fail politely. Clamping at the decode boundary removes that whole class
/// of problem in one place instead of hardening each addition.
enum DeviceFlowSeconds {
  /// One day is far beyond anything the device flow legitimately asks for; the
  /// real values are 900 seconds and 5 seconds.
  static let maximum = 86_400

  static func clamped(_ seconds: Int) -> Int {
    min(max(seconds, 0), maximum)
  }
}

/// A device authorization as returned by `POST https://github.com/login/device/code`.
public struct DeviceAuthorization: Equatable, Sendable {
  /// The app's half of the grant. Never shown to the user.
  public let deviceCode: String
  /// The short code the user types into the verification page.
  public let userCode: String
  public let verificationURL: URL
  public let expiresInSeconds: Int
  public let pollIntervalSeconds: Int

  public init(
    deviceCode: String,
    userCode: String,
    verificationURL: URL,
    expiresInSeconds: Int,
    pollIntervalSeconds: Int
  ) {
    self.deviceCode = deviceCode
    self.userCode = userCode
    self.verificationURL = verificationURL
    self.expiresInSeconds = expiresInSeconds
    self.pollIntervalSeconds = pollIntervalSeconds
  }
}

/// One non-terminal result of polling the access-token endpoint. Every other
/// documented response is a `DeviceFlowError`.
public enum DeviceAccessTokenOutcome: Equatable, Sendable {
  case authorized(token: String)
  case authorizationPending
  case slowDown(pollIntervalSeconds: Int)
}

public enum DeviceFlowError: LocalizedError, Equatable, Sendable {
  case clientIDMissing
  case expiredCode
  case accessDenied
  case deviceFlowDisabled
  case incorrectClientCredentials
  case incorrectDeviceCode
  case unsupportedGrantType
  case invalidResponse
  case requestFailed(statusCode: Int)
  case unexpected(code: String, description: String?)

  public var errorDescription: String? {
    switch self {
    case .clientIDMissing:
      "This build has no GitHub OAuth App client ID, so sign-in is unavailable. "
        + "Add a token below instead."
    case .expiredCode:
      "The sign-in code expired before it was approved. Sign in again to get a new code."
    case .accessDenied:
      "Sign-in was declined on GitHub. Sign in again to retry."
    case .deviceFlowDisabled:
      "This GitHub OAuth App does not have device flow enabled. Enable it on GitHub, "
        + "then sign in again."
    case .incorrectClientCredentials:
      "GitHub did not recognize this build's OAuth App client ID."
    case .incorrectDeviceCode:
      "GitHub rejected this sign-in code. Sign in again to get a new code."
    case .unsupportedGrantType:
      "GitHub rejected the device-flow grant type."
    case .invalidResponse:
      "GitHub returned an invalid response."
    case .requestFailed(let statusCode):
      "GitHub sign-in failed with HTTP status \(statusCode)."
    case .unexpected(let code, let description):
      "GitHub sign-in failed: \(description ?? code)"
    }
  }

  /// Maps a documented `error` code from either device-flow endpoint.
  static func forCode(_ code: String, description: String?) -> DeviceFlowError {
    switch code {
    case "expired_token": .expiredCode
    case "access_denied": .accessDenied
    case "device_flow_disabled": .deviceFlowDisabled
    case "incorrect_client_credentials": .incorrectClientCredentials
    case "incorrect_device_code": .incorrectDeviceCode
    case "unsupported_grant_type": .unsupportedGrantType
    default: .unexpected(code: code, description: description)
    }
  }
}

/// The two device-flow HTTP calls, behind a protocol so the authorizer can be
/// tested without a network.
public protocol DeviceFlowRequesting: Sendable {
  func requestDeviceAuthorization(
    clientID: String,
    scopes: [String]
  ) async throws -> DeviceAuthorization

  func redeemAccessToken(
    clientID: String,
    deviceCode: String
  ) async throws -> DeviceAccessTokenOutcome
}

public struct GitHubDeviceFlowClient: DeviceFlowRequesting {
  private let session: URLSession
  private let deviceCodeEndpoint: URL
  private let accessTokenEndpoint: URL

  public init(
    session: URLSession = .shared,
    deviceCodeEndpoint: URL = URL(string: "https://github.com/login/device/code")!,
    accessTokenEndpoint: URL = URL(string: "https://github.com/login/oauth/access_token")!
  ) {
    self.session = session
    self.deviceCodeEndpoint = deviceCodeEndpoint
    self.accessTokenEndpoint = accessTokenEndpoint
  }

  public func requestDeviceAuthorization(
    clientID: String,
    scopes: [String]
  ) async throws -> DeviceAuthorization {
    let payload: DeviceCodeResponse = try await post(
      to: deviceCodeEndpoint,
      fields: [
        "client_id": clientID,
        // GitHub takes the scope list space-delimited.
        "scope": scopes.joined(separator: " "),
      ]
    )

    if let code = payload.error {
      throw DeviceFlowError.forCode(code, description: payload.errorDescription)
    }
    guard
      let deviceCode = payload.deviceCode, !deviceCode.isEmpty,
      let userCode = payload.userCode, !userCode.isEmpty,
      let verificationURI = payload.verificationURI,
      let verificationURL = URL(string: verificationURI),
      // Only https. This URL is handed to the system to open, and the one check
      // standing between a tampered response and NSWorkspace opening an
      // arbitrary scheme's handler is this one.
      verificationURL.scheme?.lowercased() == "https",
      let expiresIn = payload.expiresIn,
      let interval = payload.interval
    else {
      throw DeviceFlowError.invalidResponse
    }

    return DeviceAuthorization(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationURL: verificationURL,
      expiresInSeconds: DeviceFlowSeconds.clamped(expiresIn),
      pollIntervalSeconds: DeviceFlowSeconds.clamped(interval)
    )
  }

  public func redeemAccessToken(
    clientID: String,
    deviceCode: String
  ) async throws -> DeviceAccessTokenOutcome {
    let payload: AccessTokenResponse = try await post(
      to: accessTokenEndpoint,
      fields: [
        "client_id": clientID,
        "device_code": deviceCode,
        "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
      ]
    )

    // GitHub answers 200 even while the grant is pending, so the body decides.
    if let code = payload.error {
      switch code {
      case "authorization_pending":
        return .authorizationPending
      case "slow_down":
        // The response carries the interval GitHub now wants.
        return .slowDown(pollIntervalSeconds: DeviceFlowSeconds.clamped(payload.interval ?? 0))
      default:
        throw DeviceFlowError.forCode(code, description: payload.errorDescription)
      }
    }

    guard let token = payload.accessToken, !token.isEmpty else {
      throw DeviceFlowError.invalidResponse
    }
    return .authorized(token: token)
  }

  private func post<Response: Decodable>(
    to endpoint: URL,
    fields: [String: String]
  ) async throws -> Response {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    // Without this header GitHub answers with a form-encoded body.
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(
      "application/x-www-form-urlencoded",
      forHTTPHeaderField: "Content-Type"
    )
    request.httpBody = Data(Self.formEncoded(fields).utf8)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw DeviceFlowError.invalidResponse
    }
    guard httpResponse.statusCode == 200 else {
      throw DeviceFlowError.requestFailed(statusCode: httpResponse.statusCode)
    }

    do {
      return try JSONDecoder().decode(Response.self, from: data)
    } catch {
      throw DeviceFlowError.invalidResponse
    }
  }

  private static func formEncoded(_ fields: [String: String]) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return
      fields
      .sorted { $0.key < $1.key }
      .map { key, value in
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return "\(encodedKey)=\(encodedValue)"
      }
      .joined(separator: "&")
  }
}

private struct DeviceCodeResponse: Decodable {
  let deviceCode: String?
  let userCode: String?
  let verificationURI: String?
  let expiresIn: Int?
  let interval: Int?
  let error: String?
  let errorDescription: String?

  enum CodingKeys: String, CodingKey {
    case deviceCode = "device_code"
    case userCode = "user_code"
    case verificationURI = "verification_uri"
    case expiresIn = "expires_in"
    case interval
    case error
    case errorDescription = "error_description"
  }
}

private struct AccessTokenResponse: Decodable {
  let accessToken: String?
  let interval: Int?
  let error: String?
  let errorDescription: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case interval
    case error
    case errorDescription = "error_description"
  }
}

/// The waiting half of the device flow, behind a protocol so tests do not sleep.
public protocol DeviceFlowClocking: Sendable {
  func sleep(forSeconds seconds: Int) async throws
}

public struct TaskSleepClock: DeviceFlowClocking {
  public init() {}

  public func sleep(forSeconds seconds: Int) async throws {
    try await Task.sleep(for: .seconds(seconds))
  }
}

/// Drives a full device-flow sign-in: ask GitHub for a code, then wait for the
/// user to approve it.
public protocol DeviceFlowAuthorizing: Sendable {
  /// False when this build has no OAuth App client ID.
  var isAvailable: Bool { get }
  func requestAuthorization() async throws -> DeviceAuthorization
  func waitForAccessToken(authorization: DeviceAuthorization) async throws -> String
}

public struct GitHubDeviceFlowAuthorizer: DeviceFlowAuthorizing {
  private let clientID: String
  private let scopes: [String]
  private let client: any DeviceFlowRequesting
  private let clock: any DeviceFlowClocking

  public init(
    clientID: String = GitHubOAuthApp.clientID,
    scopes: [String] = GitHubOAuthApp.scopes,
    client: any DeviceFlowRequesting = GitHubDeviceFlowClient(),
    clock: any DeviceFlowClocking = TaskSleepClock()
  ) {
    self.clientID = clientID
    self.scopes = scopes
    self.client = client
    self.clock = clock
  }

  public var isAvailable: Bool {
    !clientID.isEmpty
  }

  public func requestAuthorization() async throws -> DeviceAuthorization {
    guard isAvailable else {
      throw DeviceFlowError.clientIDMissing
    }
    return try await client.requestDeviceAuthorization(clientID: clientID, scopes: scopes)
  }

  public func waitForAccessToken(authorization: DeviceAuthorization) async throws -> String {
    guard isAvailable else {
      throw DeviceFlowError.clientIDMissing
    }

    // A zero or negative interval would turn the poll into a spin loop against
    // github.com, so one second is the floor regardless of what GitHub sends.
    // The ceiling is what keeps `elapsed + interval` below the point where Int
    // addition traps; the client clamps too, but the arithmetic lives here, so
    // the guard belongs here as well.
    var interval = max(DeviceFlowSeconds.clamped(authorization.pollIntervalSeconds), 1)
    // GitHub reports `expired_token` on its own, but a server that kept
    // answering `authorization_pending` would otherwise poll forever.
    let budget = max(DeviceFlowSeconds.clamped(authorization.expiresInSeconds), interval)
    var elapsed = 0

    while elapsed + interval <= budget {
      try await clock.sleep(forSeconds: interval)
      elapsed += interval

      switch try await client.redeemAccessToken(
        clientID: clientID,
        deviceCode: authorization.deviceCode
      ) {
      case .authorized(let token):
        return token
      case .authorizationPending:
        continue
      case .slowDown(let requestedInterval):
        // The docs say add five seconds; the response may ask for more.
        interval = DeviceFlowSeconds.clamped(
          max(DeviceFlowSeconds.clamped(requestedInterval), interval + 5)
        )
      }
    }

    throw DeviceFlowError.expiredCode
  }
}
