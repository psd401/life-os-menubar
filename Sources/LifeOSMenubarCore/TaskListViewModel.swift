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

  /// The number for the menu bar icon. It describes the whole repo, so the
  /// panel's search and filters don't change it. Today is 0 without
  /// `read:project`, because the due dates are then unknown rather than absent.
  public func menuBarCount(for setting: MenuBarCount) -> Int {
    menuBarCount(for: setting, issues: issues, projectFieldAccess: projectFieldAccess)
  }

  /// The menu bar number as it changes, for the status item to render.
  ///
  /// Built from the values the publishers emit, never read back from the
  /// properties: `@Published` emits before the property is set, so a read
  /// inside the pipeline sees the old value. A refresh that gained
  /// read:project would otherwise leave the Today badge at 0 until the next
  /// sync.
  public func menuBarCountPublisher(
    for setting: AnyPublisher<MenuBarCount, Never>
  ) -> AnyPublisher<(count: Int, kind: MenuBarCount), Never> {
    Publishers.CombineLatest3($issues, $projectFieldAccess, setting)
      .map { [weak self] issues, access, setting in
        (
          count: self?.menuBarCount(for: setting, issues: issues, projectFieldAccess: access) ?? 0,
          kind: setting
        )
      }
      .eraseToAnyPublisher()
  }

  private func menuBarCount(
    for setting: MenuBarCount,
    issues: [LifeOSIssue],
    projectFieldAccess: ProjectFieldAccess
  ) -> Int {
    switch setting {
    case .today:
      projectFieldAccess == .available
        ? TodayTaskPresentation.issues(from: issues, now: now(), calendar: calendar).count
        : 0
    case .inbox:
      TaskListPresentation.sections(issues: issues, searchText: "")
        .first { $0.status == .inbox }?.issues.count ?? 0
    case .off:
      0
    }
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
  private var repositoryGeneration = 0
  private var queuedRefreshToken: String?

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
      // Queue rather than drop. A refresh requested right after the task
      // repository changed would otherwise be swallowed by the previous
      // repository's in-flight refresh, leaving the new repo unsynced until
      // the next timer tick.
      queuedRefreshToken = token
      return
    }

    var candidate = token
    isRefreshing = true
    defer {
      isRefreshing = false
    }

    while true {
      await performRefresh(token: candidate)
      guard let queuedToken = queuedRefreshToken else {
        return
      }
      queuedRefreshToken = nil
      candidate = queuedToken
    }
  }

  private func performRefresh(token: String) async {
    let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else {
      errorMessage = GitHubIssueClientError.emptyToken.localizedDescription
      return
    }

    // The repository this refresh belongs to. A change while it is in flight
    // makes both its result and the snapshot the sync engine wrote on the way
    // out belong to a repository the app is no longer pointed at.
    let generation = repositoryGeneration

    do {
      let snapshot = try await syncEngine.refresh(token: candidate)
      guard generation == repositoryGeneration else {
        discardStaleSnapshot()
        return
      }
      apply(snapshot)
      errorMessage = nil
    } catch {
      guard generation == repositoryGeneration else {
        return
      }
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
  ///
  /// It also abandons any refresh still in flight, through the same generation
  /// a repository change bumps: a refresh started under the signed-out account
  /// would otherwise finish afterwards and write that account's tasks back. A
  /// refresh queued behind it carries the old token, so it is dropped too.
  public func clearCachedTasks() {
    repositoryGeneration += 1
    queuedRefreshToken = nil
    apply(.empty)
    errorMessage = nil
    do {
      try cacheStore.save(.empty)
    } catch {
      errorMessage = "Cached tasks could not be cleared: \(error.localizedDescription)"
    }
  }

  /// Undoes the cache write a refresh for the previous repository performed
  /// after `resetForRepositoryChange()` had already cleared it.
  ///
  /// Clearing the watermark again is the part that matters: left in place, the
  /// next refresh would be a delta sync asking the *new* repository only for
  /// issues changed since the *old* repository's last sync, and the stale tasks
  /// would survive until the 24-hour full reconcile.
  private func discardStaleSnapshot() {
    issues = []
    lastSyncedAt = nil
    lastFullSyncedAt = nil
    projectFieldAccess = .unknown
    clearPersistedCache()
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

  /// Drops every cached task and both sync watermarks.
  ///
  /// Called when the configured task repository changes. The cache is keyed by
  /// issue number only, so without this the panel would show the previous
  /// repo's tasks next to the new repo's, and the delta-sync watermark would
  /// suppress the very fetch that could correct it.
  public func resetForRepositoryChange() {
    repositoryGeneration += 1
    issues = []
    lastSyncedAt = nil
    lastFullSyncedAt = nil
    projectFieldAccess = .unknown
    errorMessage = nil
    clearPersistedCache()
  }

  private func clearPersistedCache() {
    do {
      try cacheStore.save(.empty)
    } catch {
      errorMessage =
        "The task repository changed, but the old cache could not be cleared: "
        + error.localizedDescription
    }
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
