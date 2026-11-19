import Foundation

/// What GitHub's token endpoint issued, for a sign-in or a refresh.
///
/// When the OAuth App has token expiration on — the default for every OAuth
/// App registered since GitHub's 2026-08-14 change, Life OS Menubar included —
/// the access token lives eight hours and comes with a refresh token that
/// renews it. Without expiration there is only the access token. Lifetimes stay
/// relative here because that is how GitHub sends them;
/// `credential(issuedAt:)` pins them to a clock.
public struct GitHubTokenGrant: Equatable, Sendable {
  public let accessToken: String
  public let accessTokenLifetimeSeconds: Int?
  public let refreshToken: String?

  public init(
    accessToken: String,
    accessTokenLifetimeSeconds: Int? = nil,
    refreshToken: String? = nil
  ) {
    self.accessToken = accessToken
    self.accessTokenLifetimeSeconds = accessTokenLifetimeSeconds
    self.refreshToken = refreshToken
  }

  public func credential(issuedAt issueDate: Date) -> GitHubCredential {
    GitHubCredential(
      accessToken: accessToken,
      // A negative lifetime is nonsense; reading it as "already expired"
      // renews at once rather than trusting a date in the past.
      accessTokenExpiresAt: accessTokenLifetimeSeconds.map {
        issueDate.addingTimeInterval(TimeInterval(max($0, 0)))
      },
      refreshToken: refreshToken
    )
  }
}

/// The GitHub credential the app keeps in the Keychain and sends as a bearer
/// token.
public struct GitHubCredential: Equatable, Sendable {
  public let accessToken: String
  /// Nil for a token that does not expire on a schedule the app knows: a
  /// pasted personal access token, or a token from before token expiration.
  public let accessTokenExpiresAt: Date?
  /// Nil when nothing can renew the access token.
  public let refreshToken: String?

  public init(accessToken: String, accessTokenExpiresAt: Date? = nil, refreshToken: String? = nil) {
    self.accessToken = accessToken
    self.accessTokenExpiresAt = accessTokenExpiresAt
    self.refreshToken = refreshToken
  }

  /// True when the access token expires and a refresh token can renew it.
  public var isRefreshable: Bool {
    accessTokenExpiresAt != nil && !(refreshToken ?? "").isEmpty
  }

  /// Whether to renew before the next request: the access token expires
  /// within `margin` of `now`, or already has.
  public func needsRefresh(at now: Date, margin: TimeInterval) -> Bool {
    guard isRefreshable, let accessTokenExpiresAt else {
      return false
    }
    return accessTokenExpiresAt.timeIntervalSince(now) <= margin
  }
}

// MARK: - Stored form

extension GitHubCredential {
  /// The bytes the Keychain item holds: versioned JSON.
  public func storedData() throws -> Data {
    try Self.encoder.encode(
      StoredCredential(
        version: StoredCredential.currentVersion,
        accessToken: accessToken,
        accessTokenExpiresAt: accessTokenExpiresAt,
        refreshToken: refreshToken
      )
    )
  }

  /// Reads a Keychain item in either format it can hold: the versioned JSON
  /// this version writes, or the bare token string every earlier version wrote
  /// — which keeps a stored v1 personal access token signed in. Nil for
  /// anything else.
  public init?(storedData data: Data) {
    if let stored = try? Self.decoder.decode(StoredCredential.self, from: data),
      stored.version == StoredCredential.currentVersion,
      !stored.accessToken.isEmpty
    {
      self.init(
        accessToken: stored.accessToken,
        accessTokenExpiresAt: stored.accessTokenExpiresAt,
        refreshToken: stored.refreshToken
      )
      return
    }

    guard
      let bareToken = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !bareToken.isEmpty
    else {
      return nil
    }
    self.init(accessToken: bareToken)
  }

  private static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    return encoder
  }

  private static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }
}

private struct StoredCredential: Codable {
  static let currentVersion = 1

  let version: Int
  let accessToken: String
  let accessTokenExpiresAt: Date?
  let refreshToken: String?
}
