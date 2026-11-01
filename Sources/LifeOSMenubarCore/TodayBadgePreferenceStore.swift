import Foundation

public protocol TodayBadgePreferenceStoring: Sendable {
  func loadIsEnabled() throws -> Bool
  func saveIsEnabled(_ isEnabled: Bool) throws
}

public struct UserDefaultsTodayBadgePreferenceStore:
  TodayBadgePreferenceStoring,
  @unchecked Sendable
{
  private let userDefaults: UserDefaults
  private let key: String

  public init(
    userDefaults: UserDefaults = .standard,
    key: String = "todayBadgeEnabled"
  ) {
    self.userDefaults = userDefaults
    self.key = key
  }

  public func loadIsEnabled() throws -> Bool {
    userDefaults.object(forKey: key) as? Bool ?? true
  }

  public func saveIsEnabled(_ isEnabled: Bool) throws {
    userDefaults.set(isEnabled, forKey: key)
  }
}
