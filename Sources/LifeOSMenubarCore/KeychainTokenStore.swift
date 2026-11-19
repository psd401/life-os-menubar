import Foundation
import Security

/// Persistence for the one GitHub credential: its access token and, for an
/// expiring token, the refresh token and expiry that go with it. The three are
/// one item so a refresh replaces them in a single write — GitHub retires the
/// old refresh token the moment it issues a new one, so a half-written pair
/// would be unrecoverable.
public protocol TokenStoring: Sendable {
  func loadCredential() throws -> GitHubCredential?
  func saveCredential(_ credential: GitHubCredential) throws
  func deleteCredential() throws
}

public struct KeychainError: LocalizedError, Equatable, Sendable {
  public let status: OSStatus

  public init(status: OSStatus) {
    self.status = status
  }

  public var errorDescription: String? {
    if let message = SecCopyErrorMessageString(status, nil) as String? {
      return "Keychain error: \(message)"
    }
    return "Keychain error \(status)."
  }
}

public struct KeychainTokenStore: TokenStoring {
  private let service: String
  private let account: String

  // The account name predates OAuth sign-in. It stays, so the item an earlier
  // version wrote is the item this one reads.
  public init(
    service: String = "com.krishagel.LifeOSMenubar",
    account: String = "github-personal-access-token"
  ) {
    self.service = service
    self.account = account
  }

  public func loadCredential() throws -> GitHubCredential? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw KeychainError(status: status)
    }
    guard
      let data = result as? Data,
      let credential = GitHubCredential(storedData: data)
    else {
      throw KeychainError(status: errSecDecode)
    }
    return credential
  }

  public func saveCredential(_ credential: GitHubCredential) throws {
    let data = try credential.storedData()
    let update = [kSecValueData as String: data]
    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)

    if updateStatus == errSecItemNotFound {
      var item = baseQuery
      item[kSecValueData as String] = data
      let addStatus = SecItemAdd(item as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainError(status: addStatus)
      }
      return
    }

    guard updateStatus == errSecSuccess else {
      throw KeychainError(status: updateStatus)
    }
  }

  public func deleteCredential() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError(status: status)
    }
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
  }
}
