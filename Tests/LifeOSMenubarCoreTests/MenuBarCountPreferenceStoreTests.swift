import Foundation
import Testing

@testable import LifeOSMenubarCore

struct MenuBarCountPreferenceStoreTests {
  @Test
  func defaultsToTodayOnAFreshInstall() throws {
    try withIsolatedDefaults { defaults throws in
      let store = UserDefaultsMenuBarCountPreferenceStore(userDefaults: defaults)

      #expect(try store.loadCount() == .today)
    }
  }

  @Test
  func keepsTheChoiceTheOldTodayToggleRecorded() throws {
    try withIsolatedDefaults { defaults throws in
      defaults.set(false, forKey: "todayBadgeEnabled")
      let store = UserDefaultsMenuBarCountPreferenceStore(userDefaults: defaults)

      #expect(try store.loadCount() == .off)

      defaults.set(true, forKey: "todayBadgeEnabled")
      #expect(try store.loadCount() == .today)
    }
  }

  @Test
  func savesTheChoiceAndRetiresTheOldToggle() throws {
    try withIsolatedDefaults { defaults throws in
      defaults.set(false, forKey: "todayBadgeEnabled")
      let store = UserDefaultsMenuBarCountPreferenceStore(userDefaults: defaults)

      try store.saveCount(.inbox)

      #expect(try store.loadCount() == .inbox)
      #expect(defaults.object(forKey: "todayBadgeEnabled") == nil)
    }
  }

  @Test
  func anUnknownStoredValueFallsBackToTheDefault() throws {
    try withIsolatedDefaults { defaults throws in
      defaults.set("weekly", forKey: "menuBarCount")
      let store = UserDefaultsMenuBarCountPreferenceStore(userDefaults: defaults)

      #expect(try store.loadCount() == .today)
    }
  }

  @Test
  func everyChoiceHasAPickerTitle() {
    #expect(MenuBarCount.allCases.map(\.title) == ["Today", "Inbox", "Off"])
  }

  private func withIsolatedDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let suiteName = "MenuBarCountPreferenceStoreTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
      defaults.removePersistentDomain(forName: suiteName)
    }
    try body(defaults)
  }
}
