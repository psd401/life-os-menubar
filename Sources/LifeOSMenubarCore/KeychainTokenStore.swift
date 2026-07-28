import Foundation
import Security

public protocol TokenStoring: Sendable {
  func loadToken() throws -> String?
  func saveToken(_ token: String) throws
  func deleteToken() throws
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

  public init(
    service: String = "com.krishagel.LifeOSMenubar",
    account: String = "github-personal-access-token"
  ) {
    self.service = service
    self.account = account
  }

  public func loadToken() throws -> String? {
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
      let token = String(data: data, encoding: .utf8)
    else {
      throw KeychainError(status: errSecDecode)
    }
    return token
  }

  public func saveToken(_ token: String) throws {
    let data = Data(token.utf8)
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

  public func deleteToken() throws {
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
