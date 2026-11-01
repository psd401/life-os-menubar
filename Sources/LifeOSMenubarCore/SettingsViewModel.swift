import Combine
import Foundation

public enum TokenValidationState: Equatable, Sendable {
  case idle
  case validating
  case valid(login: String)
  case invalid(message: String)
}

@MainActor
public final class SettingsViewModel: ObservableObject {
  @Published public var token: String
  @Published public private(set) var validationState: TokenValidationState = .idle
  @Published public private(set) var isLaunchAtLoginEnabled: Bool
  @Published public private(set) var isTodayBadgeEnabled: Bool
  @Published public private(set) var persistenceError: String?
  @Published public private(set) var launchAtLoginError: String?
  @Published public private(set) var badgePreferenceError: String?

  private let tokenStore: any TokenStoring
  private let validator: any GitHubTokenValidating
  private let launchAtLoginController: any LaunchAtLoginControlling
  private let badgePreferenceStore: any TodayBadgePreferenceStoring
  private var validationGeneration = 0

  public init(
    tokenStore: any TokenStoring,
    validator: any GitHubTokenValidating,
    launchAtLoginController: any LaunchAtLoginControlling,
    badgePreferenceStore: any TodayBadgePreferenceStoring =
      UserDefaultsTodayBadgePreferenceStore()
  ) {
    self.tokenStore = tokenStore
    self.validator = validator
    self.launchAtLoginController = launchAtLoginController
    self.badgePreferenceStore = badgePreferenceStore
    self.isLaunchAtLoginEnabled = launchAtLoginController.isEnabled

    do {
      self.token = try tokenStore.loadToken() ?? ""
    } catch {
      self.token = ""
      self.persistenceError = error.localizedDescription
    }

    do {
      self.isTodayBadgeEnabled = try badgePreferenceStore.loadIsEnabled()
    } catch {
      self.isTodayBadgeEnabled = true
      self.badgePreferenceError = error.localizedDescription
    }
  }

  @discardableResult
  public func saveToken() -> Bool {
    let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedToken.isEmpty else {
      persistenceError = "Enter a GitHub personal access token."
      return false
    }

    do {
      try tokenStore.saveToken(trimmedToken)
      token = trimmedToken
      persistenceError = nil
      validationState = .idle
      return true
    } catch {
      persistenceError = error.localizedDescription
      return false
    }
  }

  public func saveAndValidateToken() async {
    guard saveToken() else {
      return
    }
    await validateToken()
  }

  public func validateToken() async {
    validationGeneration += 1
    let generation = validationGeneration
    let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else {
      validationState = .invalid(message: "Enter a GitHub personal access token.")
      return
    }

    validationState = .validating
    do {
      let login = try await validator.validate(token: candidate)
      guard generation == validationGeneration,
        token.trimmingCharacters(in: .whitespacesAndNewlines) == candidate
      else {
        return
      }
      validationState = .valid(login: login)
    } catch {
      guard generation == validationGeneration,
        token.trimmingCharacters(in: .whitespacesAndNewlines) == candidate
      else {
        return
      }
      validationState = .invalid(message: error.localizedDescription)
    }
  }

  public func clearToken() {
    do {
      try tokenStore.deleteToken()
      token = ""
      validationState = .idle
      persistenceError = nil
    } catch {
      persistenceError = error.localizedDescription
    }
  }

  public func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
    do {
      try launchAtLoginController.setEnabled(isEnabled)
      isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
      launchAtLoginError = nil
    } catch {
      isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
      launchAtLoginError = error.localizedDescription
    }
  }

  public func setTodayBadgeEnabled(_ isEnabled: Bool) {
    do {
      try badgePreferenceStore.saveIsEnabled(isEnabled)
      isTodayBadgeEnabled = isEnabled
      badgePreferenceError = nil
    } catch {
      badgePreferenceError = error.localizedDescription
    }
  }
}
