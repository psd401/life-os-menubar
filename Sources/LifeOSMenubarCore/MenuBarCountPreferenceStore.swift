import Foundation

/// What the number on the menu bar icon counts.
public enum MenuBarCount: String, CaseIterable, Identifiable, Sendable {
  /// Open tasks due today or overdue, not deferred past today — the Today view.
  case today
  /// Open tasks in the Inbox section.
  case inbox
  /// No number, just the icon.
  case off

  public var id: String {
    rawValue
  }

  public var title: String {
    switch self {
    case .today:
      "Today"
    case .inbox:
      "Inbox"
    case .off:
      "Off"
    }
  }
}

public protocol MenuBarCountPreferenceStoring: Sendable {
  func loadCount() throws -> MenuBarCount
  func saveCount(_ count: MenuBarCount) throws
}

public struct UserDefaultsMenuBarCountPreferenceStore:
  MenuBarCountPreferenceStoring,
  @unchecked Sendable
{
  private let userDefaults: UserDefaults
  private let key: String
  /// The Bool the app stored before the count became a choice. Read only so an
  /// existing install keeps what it had (on → Today, off → Off); the first save
  /// of the new setting removes it.
  private let legacyTodayToggleKey = "todayBadgeEnabled"

  public init(
    userDefaults: UserDefaults = .standard,
    key: String = "menuBarCount"
  ) {
    self.userDefaults = userDefaults
    self.key = key
  }

  public func loadCount() throws -> MenuBarCount {
    if let stored = userDefaults.string(forKey: key),
      let count = MenuBarCount(rawValue: stored)
    {
      return count
    }
    if let legacyToggle = userDefaults.object(forKey: legacyTodayToggleKey) as? Bool {
      return legacyToggle ? .today : .off
    }
    return .today
  }

  public func saveCount(_ count: MenuBarCount) throws {
    userDefaults.set(count.rawValue, forKey: key)
    userDefaults.removeObject(forKey: legacyTodayToggleKey)
  }
}
