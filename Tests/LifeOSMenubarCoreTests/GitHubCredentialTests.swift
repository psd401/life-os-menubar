import Foundation
import Testing

@testable import LifeOSMenubarCore

struct GitHubCredentialTests {
  private let issuedAt = Date(timeIntervalSince1970: 1_793_000_000)

  @Test
  func aGrantWithALifetimeExpiresThatManySecondsAfterItWasIssued() {
    let grant = GitHubTokenGrant(
      accessToken: "gho_access",
      accessTokenLifetimeSeconds: 28_800,
      refreshToken: "ghr_refresh"
    )

    let credential = grant.credential(issuedAt: issuedAt)

    #expect(credential.accessToken == "gho_access")
    #expect(credential.refreshToken == "ghr_refresh")
    #expect(credential.accessTokenExpiresAt == issuedAt.addingTimeInterval(28_800))
    #expect(credential.isRefreshable)
  }

  @Test
  func aGrantWithoutALifetimeNeverExpires() {
    let credential = GitHubTokenGrant(accessToken: "gho_long_lived").credential(issuedAt: issuedAt)

    #expect(credential.accessTokenExpiresAt == nil)
    #expect(credential.refreshToken == nil)
    #expect(!credential.isRefreshable)
    #expect(!credential.needsRefresh(at: issuedAt.addingTimeInterval(1_000_000), margin: 900))
  }

  @Test
  func aNegativeLifetimeIsTreatedAsAlreadyExpiredRatherThanTrusted() {
    let credential = GitHubTokenGrant(
      accessToken: "gho_access",
      accessTokenLifetimeSeconds: -5,
      refreshToken: "ghr_refresh"
    ).credential(issuedAt: issuedAt)

    #expect(credential.accessTokenExpiresAt == issuedAt)
  }

  @Test
  func anExpiringTokenNeedsRefreshOnlyInsideTheMargin() {
    let credential = GitHubCredential(
      accessToken: "gho_access",
      accessTokenExpiresAt: issuedAt.addingTimeInterval(28_800),
      refreshToken: "ghr_refresh"
    )

    #expect(!credential.needsRefresh(at: issuedAt, margin: 900))
    #expect(!credential.needsRefresh(at: issuedAt.addingTimeInterval(28_800 - 901), margin: 900))
    #expect(credential.needsRefresh(at: issuedAt.addingTimeInterval(28_800 - 900), margin: 900))
    // Already past expiry, as after a night with the lid closed.
    #expect(credential.needsRefresh(at: issuedAt.addingTimeInterval(40_000), margin: 900))
  }

  @Test
  func anExpiringTokenWithNoRefreshTokenCannotBeRefreshed() {
    let credential = GitHubCredential(
      accessToken: "gho_access",
      accessTokenExpiresAt: issuedAt,
      refreshToken: nil
    )

    #expect(!credential.isRefreshable)
    #expect(!credential.needsRefresh(at: issuedAt.addingTimeInterval(60), margin: 900))
  }

  @Test
  func roundTripsThroughItsStoredForm() throws {
    let credential = GitHubCredential(
      accessToken: "gho_access",
      accessTokenExpiresAt: issuedAt.addingTimeInterval(28_800),
      refreshToken: "ghr_refresh"
    )

    let restored = try #require(GitHubCredential(storedData: try credential.storedData()))

    #expect(restored == credential)
  }

  @Test
  func readsAStoredBareTokenFromAnEarlierVersionAsANonExpiringCredential() throws {
    // Every version before refresh support wrote the bare token string, and a
    // personal access token pasted into Settings is stored that way too.
    let restored = try #require(GitHubCredential(storedData: Data("ghp_legacy_token\n".utf8)))

    #expect(restored == GitHubCredential(accessToken: "ghp_legacy_token"))
    #expect(!restored.isRefreshable)
  }

  @Test
  func refusesAStoredJSONCredentialItCannotRead() {
    // A newer version's item, or one this version cannot decode, must not
    // fall through to the bare-token path: the JSON text itself would be
    // sent to GitHub as the bearer token.
    #expect(
      GitHubCredential(storedData: Data(#"{"version":2,"accessToken":"gho_future"}"#.utf8)) == nil
    )
    #expect(GitHubCredential(storedData: Data(#"{"token":"gho_unknown_shape"}"#.utf8)) == nil)
  }

  @Test
  func refusesStoredDataThatIsNeitherFormat() {
    #expect(GitHubCredential(storedData: Data()) == nil)
    #expect(GitHubCredential(storedData: Data("   ".utf8)) == nil)
    #expect(GitHubCredential(storedData: Data([0xFF, 0xFE, 0xFD])) == nil)
  }
}
