import Combine
import Foundation

public enum TokenValidationState: Equatable, Sendable {
  case idle
  case validating
  case valid(login: String)
  case invalid(message: String)
}

public enum TaskRepositoryState: Equatable, Sendable {
  case idle
  case validating
  case valid(slug: String)
  case invalid(message: String)
}

@MainActor
public final class SettingsViewModel: ObservableObject {
  @Published public var token: String
  @Published public private(set) var validationState: TokenValidationState = .idle
  @Published public var repositorySlug: String
  @Published public private(set) var repositoryState: TaskRepositoryState = .idle
  @Published public private(set) var isRepositoryConfigured: Bool
  @Published public private(set) var isLaunchAtLoginEnabled: Bool
  @Published public private(set) var isTodayBadgeEnabled: Bool
  @Published public private(set) var persistenceError: String?
  @Published public private(set) var launchAtLoginError: String?
  @Published public private(set) var badgePreferenceError: String?

  private let tokenStore: any TokenStoring
  private let validator: any GitHubTokenValidating
  private let launchAtLoginController: any LaunchAtLoginControlling
  private let badgePreferenceStore: any TodayBadgePreferenceStoring
  private let repositoryStore: any TaskRepositoryStoring
  private let repositoryValidator: any TaskRepositoryValidating
  private let onRepositoryChange: @MainActor (TaskRepository?) -> Void
  private var validationGeneration = 0
  private var repositoryValidationGeneration = 0

  public init(
    tokenStore: any TokenStoring,
    validator: any GitHubTokenValidating,
    launchAtLoginController: any LaunchAtLoginControlling,
    badgePreferenceStore: any TodayBadgePreferenceStoring =
      UserDefaultsTodayBadgePreferenceStore(),
    repositoryStore: any TaskRepositoryStoring = UserDefaultsTaskRepositoryStore(),
    repositoryValidator: any TaskRepositoryValidating = TaskRepositoryValidator(),
    onRepositoryChange: @escaping @MainActor (TaskRepository?) -> Void = { _ in }
  ) {
    self.tokenStore = tokenStore
    self.validator = validator
    self.launchAtLoginController = launchAtLoginController
    self.badgePreferenceStore = badgePreferenceStore
    self.repositoryStore = repositoryStore
    self.repositoryValidator = repositoryValidator
    self.onRepositoryChange = onRepositoryChange
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

    let configuredRepository = try? repositoryStore.loadRepository()
    self.repositorySlug = configuredRepository?.slug ?? ""
    self.isRepositoryConfigured = configuredRepository != nil
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

  /// Validates the typed `owner/repo` against GitHub and saves it only if the
  /// repo exists, the token can read it, and every required label definition is
  /// already there. A repo that fails any of those is never written to the
  /// store, so the app cannot start syncing against something it will misread —
  /// see [decision 0005](../../openwiki/decisions/0005-configurable-task-repo.md).
  public func saveAndValidateRepository() async {
    repositoryValidationGeneration += 1
    let generation = repositoryValidationGeneration

    let candidate: TaskRepository
    do {
      candidate = try TaskRepository.parse(repositorySlug)
    } catch {
      repositoryState = .invalid(message: error.localizedDescription)
      return
    }

    let candidateToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidateToken.isEmpty else {
      repositoryState = .invalid(
        message: TaskRepositoryValidationError.emptyToken.localizedDescription
      )
      return
    }

    repositoryState = .validating
    let report: TaskRepositoryValidationReport
    do {
      report = try await repositoryValidator.validate(
        token: candidateToken,
        repository: candidate
      )
    } catch {
      guard generation == repositoryValidationGeneration else {
        return
      }
      repositoryState = .invalid(message: error.localizedDescription)
      return
    }

    guard generation == repositoryValidationGeneration else {
      return
    }
    guard report.isConforming else {
      repositoryState = .invalid(message: Self.missingLabelsMessage(report.missingLabels))
      return
    }

    do {
      try repositoryStore.saveRepository(candidate)
    } catch {
      repositoryState = .invalid(message: error.localizedDescription)
      return
    }

    repositorySlug = candidate.slug
    isRepositoryConfigured = true
    repositoryState = .valid(slug: candidate.slug)
    onRepositoryChange(candidate)
  }

  public func clearRepository() {
    do {
      try repositoryStore.clearRepository()
    } catch {
      repositoryState = .invalid(message: error.localizedDescription)
      return
    }

    repositoryValidationGeneration += 1
    repositorySlug = ""
    isRepositoryConfigured = false
    repositoryState = .idle
    onRepositoryChange(nil)
  }

  private static func missingLabelsMessage(_ missingLabels: [String]) -> String {
    "This repository is missing \(missingLabels.count) required "
      + (missingLabels.count == 1 ? "label" : "labels")
      + ": \(missingLabels.joined(separator: ", ")). "
      + "Run the bootstrap in docs/life-os-repo-standard.md, then validate again."
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
