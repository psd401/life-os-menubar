import Combine
import Foundation

@MainActor
public final class TaskListViewModel: ObservableObject {
  @Published public private(set) var issues: [LifeOSIssue] = []
  @Published public var searchText = ""
  @Published public private(set) var activeFilter: TaskFilterSelection = .empty
  @Published public private(set) var savedFilters: [SavedTaskFilter] = []
  @Published public private(set) var lastSyncedAt: Date?
  @Published public private(set) var projectFieldAccess: ProjectFieldAccess = .unknown
  @Published public private(set) var isRefreshing = false
  @Published public private(set) var errorMessage: String?
  @Published public private(set) var filterErrorMessage: String?

  public var sections: [TaskSectionSnapshot] {
    TaskListPresentation.sections(
      issues: issues,
      searchText: searchText,
      filterSelection: activeFilter
    )
  }

  public var activeFilterCount: Int {
    activeFilter.selectedLabelCount
  }

  public var todayIssues: [LifeOSIssue] {
    TodayTaskPresentation.issues(
      from: issues,
      now: now(),
      calendar: calendar,
      searchText: searchText,
      filterSelection: activeFilter
    )
  }

  public var todayCount: Int {
    TodayTaskPresentation.issues(
      from: issues,
      now: now(),
      calendar: calendar
    ).count
  }

  public var projectFieldMessage: String? {
    guard projectFieldAccess == .missingScope else {
      return nil
    }
    return
      "Today dates are unavailable because this token is missing read:project. "
      + "Other task features remain available."
  }

  private let cacheStore: any IssueCacheStoring
  private let syncEngine: IssueSyncEngine
  private let filterStore: any TaskFilterStoring
  private let now: @Sendable () -> Date
  private let calendar: Calendar
  private var backgroundRefreshTask: Task<Void, Never>?
  private var lastFullSyncedAt: Date?

  public init(
    cacheStore: any IssueCacheStoring,
    syncEngine: IssueSyncEngine,
    filterStore: any TaskFilterStoring,
    now: @escaping @Sendable () -> Date = Date.init,
    calendar: Calendar = .current
  ) {
    self.cacheStore = cacheStore
    self.syncEngine = syncEngine
    self.filterStore = filterStore
    self.now = now
    self.calendar = calendar

    do {
      apply(try cacheStore.load() ?? .empty)
    } catch {
      errorMessage = "Cached tasks could not be loaded: \(error.localizedDescription)"
    }

    do {
      let filterSnapshot = try filterStore.load() ?? .empty
      activeFilter = filterSnapshot.activeSelection
      savedFilters = filterSnapshot.savedFilters
    } catch {
      filterErrorMessage = "Filters could not be loaded: \(error.localizedDescription)"
    }
  }

  deinit {
    backgroundRefreshTask?.cancel()
  }

  public func refresh(token: String) async {
    guard !isRefreshing else {
      return
    }

    let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else {
      errorMessage = GitHubIssueClientError.emptyToken.localizedDescription
      return
    }

    isRefreshing = true
    defer {
      isRefreshing = false
    }

    do {
      apply(try await syncEngine.refresh(token: candidate))
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Drops every synced task, in memory and on disk.
  ///
  /// Called on sign-out. `refresh(token:)` returns early on an empty token
  /// without touching `issues`, so without this the previous account's tasks
  /// would keep showing in the panel and counting toward the Today badge —
  /// and would still be there for whoever signs in next. Resetting the cache to
  /// `.empty` also clears the sync watermarks, so the next sign-in starts with
  /// a full fetch rather than a delta against someone else's data.
  public func clearCachedTasks() {
    apply(.empty)
    errorMessage = nil
    do {
      try cacheStore.save(.empty)
    } catch {
      errorMessage = "Cached tasks could not be cleared: \(error.localizedDescription)"
    }
  }

  public func startBackgroundRefresh(
    every interval: Duration = .seconds(300),
    tokenProvider: @escaping @MainActor () -> String
  ) {
    backgroundRefreshTask?.cancel()
    backgroundRefreshTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: interval)
        } catch {
          return
        }
        guard let self else {
          return
        }
        await self.refresh(token: tokenProvider())
      }
    }
  }

  public func stopBackgroundRefresh() {
    backgroundRefreshTask?.cancel()
    backgroundRefreshTask = nil
  }

  public func availableFilterLabels(for family: TaskFilterFamily) -> [GitHubLabel] {
    TaskFilterPredicate.availableLabels(in: issues)[family] ?? []
  }

  public func isFilterSelected(
    labelName: String,
    in family: TaskFilterFamily
  ) -> Bool {
    activeFilter.contains(labelName: labelName, in: family)
  }

  public func toggleFilter(
    labelName: String,
    in family: TaskFilterFamily
  ) {
    activeFilter.toggle(labelName: labelName, in: family)
    persistFilters()
  }

  public func clearFilters() {
    guard !activeFilter.isEmpty else {
      return
    }
    activeFilter = .empty
    persistFilters()
  }

  @discardableResult
  public func saveCurrentFilter(named name: String) -> Bool {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      return false
    }

    if let existingIndex = savedFilters.firstIndex(where: {
      $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
    }) {
      savedFilters[existingIndex] = SavedTaskFilter(
        id: savedFilters[existingIndex].id,
        name: trimmedName,
        selection: activeFilter
      )
    } else {
      savedFilters.append(
        SavedTaskFilter(name: trimmedName, selection: activeFilter)
      )
    }
    persistFilters()
    return true
  }

  public func applySavedFilter(id: UUID) {
    guard let savedFilter = savedFilters.first(where: { $0.id == id }) else {
      return
    }
    activeFilter = savedFilter.selection
    persistFilters()
  }

  public func deleteSavedFilter(id: UUID) {
    guard let savedFilterIndex = savedFilters.firstIndex(where: { $0.id == id }) else {
      return
    }
    savedFilters.remove(at: savedFilterIndex)
    persistFilters()
  }

  public func reconcileRemoteIssue(_ issue: LifeOSIssue) {
    if issue.state == .closed {
      issues.removeAll { $0.number == issue.number }
    } else if let existingIndex = issues.firstIndex(where: { $0.number == issue.number }) {
      issues[existingIndex] = issue.preservingProjectFields(from: issues[existingIndex])
    } else {
      issues.append(issue)
    }
    issues.sort { $0.number < $1.number }

    do {
      try cacheStore.save(
        IssueCacheSnapshot(
          issues: issues,
          lastSyncedAt: lastSyncedAt,
          lastFullSyncedAt: lastFullSyncedAt,
          projectFieldAccess: projectFieldAccess
        )
      )
    } catch {
      errorMessage =
        "Task changed on GitHub, but the cache could not be saved: \(error.localizedDescription)"
    }
  }

  private func apply(_ snapshot: IssueCacheSnapshot) {
    issues = snapshot.issues
    lastSyncedAt = snapshot.lastSyncedAt
    lastFullSyncedAt = snapshot.lastFullSyncedAt
    projectFieldAccess = snapshot.projectFieldAccess
  }

  private func persistFilters() {
    do {
      try filterStore.save(
        TaskFilterStoreSnapshot(
          activeSelection: activeFilter,
          savedFilters: savedFilters
        )
      )
      filterErrorMessage = nil
    } catch {
      filterErrorMessage = "Filters could not be saved: \(error.localizedDescription)"
    }
  }
}
