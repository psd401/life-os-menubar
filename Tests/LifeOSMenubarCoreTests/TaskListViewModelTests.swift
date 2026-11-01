import Foundation
import Testing

@testable import LifeOSMenubarCore

@MainActor
struct TaskListViewModelTests {
  @Test
  func loadsCachedTasksWithoutStartingANetworkRequest() async {
    let cachedIssue = viewModelTestIssue(number: 7)
    let cache = ViewModelCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [cachedIssue],
        lastSyncedAt: Date(timeIntervalSince1970: 1_785_100_000),
        lastFullSyncedAt: Date(timeIntervalSince1970: 1_785_100_000)
      )
    )
    let client = ViewModelIssueFetcher(result: .success([]))
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(client: client, cacheStore: cache),
      filterStore: ViewModelFilterStore()
    )

    #expect(viewModel.issues == [cachedIssue])
    #expect(await client.callCount == 0)
  }

  @Test
  func clearingCachedTasksEmptiesTheListAndTheCacheOnSignOut() async throws {
    let cachedIssue = viewModelTestIssue(number: 11)
    let cache = ViewModelCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [cachedIssue],
        lastSyncedAt: Date(timeIntervalSince1970: 1_785_100_000),
        lastFullSyncedAt: Date(timeIntervalSince1970: 1_785_100_000),
        projectFieldAccess: .available
      )
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([])),
        cacheStore: cache
      ),
      filterStore: ViewModelFilterStore()
    )
    #expect(viewModel.issues == [cachedIssue])

    viewModel.clearCachedTasks()

    #expect(viewModel.issues.isEmpty)
    #expect(viewModel.lastSyncedAt == nil)
    #expect(viewModel.projectFieldAccess == .unknown)
    #expect(viewModel.errorMessage == nil)
    // On disk too: the next person to sign in must not find these.
    let persisted = try #require(try cache.load())
    #expect(persisted == .empty)
  }

  @Test
  func anEmptyTokenAloneDoesNotDropCachedTasks() async {
    // refresh(token:) deliberately keeps the cache on an empty token — an
    // offline launch should still show tasks. Clearing is sign-out's job, which
    // is why clearCachedTasks exists at all.
    let cachedIssue = viewModelTestIssue(number: 12)
    let cache = ViewModelCacheStore(
      snapshot: IssueCacheSnapshot(issues: [cachedIssue], lastSyncedAt: nil)
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([])),
        cacheStore: cache
      ),
      filterStore: ViewModelFilterStore()
    )

    await viewModel.refresh(token: "   ")

    #expect(viewModel.issues == [cachedIssue])
  }

  @Test
  func refreshFailureKeepsCachedTasksAndShowsNonBlockingError() async {
    let cachedIssue = viewModelTestIssue(number: 8)
    let cache = ViewModelCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [cachedIssue],
        lastSyncedAt: Date(timeIntervalSince1970: 1_785_100_000),
        lastFullSyncedAt: Date(timeIntervalSince1970: 1_785_100_000)
      )
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .failure(URLError(.notConnectedToInternet))),
        cacheStore: cache
      ),
      filterStore: ViewModelFilterStore()
    )

    await viewModel.refresh(token: "token")

    #expect(viewModel.issues == [cachedIssue])
    #expect(viewModel.errorMessage != nil)
    #expect(!viewModel.isRefreshing)
  }

  @Test
  func successfulRefreshReplacesVisibleSnapshotAndClearsError() async {
    let cache = ViewModelCacheStore()
    let fetchedIssue = viewModelTestIssue(number: 9)
    let refreshTime = Date(timeIntervalSince1970: 1_785_200_000)
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([fetchedIssue])),
        cacheStore: cache,
        now: { refreshTime }
      ),
      filterStore: ViewModelFilterStore()
    )

    await viewModel.refresh(token: "token")

    #expect(viewModel.issues == [fetchedIssue])
    #expect(viewModel.lastSyncedAt == refreshTime)
    #expect(viewModel.errorMessage == nil)
  }

  @Test
  func exposesCachedTodayCountAndProjectAccess() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let now = try #require(
      ISO8601DateFormatter().date(from: "2026-07-28T19:00:00Z")
    )
    let dueToday = LifeOSIssue(
      number: 1,
      title: "Due today",
      body: "",
      labels: [GitHubLabel(name: "status:inbox", color: "ffffff")],
      updatedAt: now,
      dueDate: ProjectDate(githubDate: "2026-07-28")
    )
    let deferred = LifeOSIssue(
      number: 2,
      title: "Deferred",
      body: "",
      labels: [GitHubLabel(name: "status:inbox", color: "ffffff")],
      updatedAt: now,
      dueDate: ProjectDate(githubDate: "2026-07-27"),
      deferUntil: ProjectDate(githubDate: "2026-07-29")
    )
    let cache = ViewModelCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [dueToday, deferred],
        lastSyncedAt: now,
        projectFieldAccess: .available
      )
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([])),
        cacheStore: cache
      ),
      filterStore: ViewModelFilterStore(),
      now: { now },
      calendar: calendar
    )

    #expect(viewModel.projectFieldAccess == .available)
    #expect(viewModel.todayCount == 1)
    #expect(viewModel.todayIssues.map(\.number) == [1])
  }

  @Test
  func loadsPersistedActiveAndSavedFiltersAtLaunch() {
    let cache = ViewModelCacheStore()
    let selection = TaskFilterSelection(
      labelsByFamily: [.area: ["area:work"]]
    )
    let savedFilter = SavedTaskFilter(name: "Work", selection: selection)
    let filterStore = ViewModelFilterStore(
      snapshot: TaskFilterStoreSnapshot(
        activeSelection: selection,
        savedFilters: [savedFilter]
      )
    )

    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([])),
        cacheStore: cache
      ),
      filterStore: filterStore
    )

    #expect(viewModel.activeFilter == selection)
    #expect(viewModel.savedFilters == [savedFilter])
  }

  @Test
  func filterChangesAndSavedFilterLifecyclePersistImmediately() throws {
    let cache = ViewModelCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [
          LifeOSIssue(
            number: 1,
            title: "Work task",
            body: "",
            labels: [
              GitHubLabel(name: "status:inbox", color: "ffffff"),
              GitHubLabel(name: "area:work", color: "000000"),
            ],
            updatedAt: Date(timeIntervalSince1970: 1_785_000_000)
          )
        ],
        lastSyncedAt: nil
      )
    )
    let filterStore = ViewModelFilterStore()
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([])),
        cacheStore: cache
      ),
      filterStore: filterStore
    )

    viewModel.toggleFilter(labelName: "area:work", in: .area)
    #expect(viewModel.sections.first?.issues.map(\.number) == [1])
    #expect(try filterStore.load()?.activeSelection == viewModel.activeFilter)

    #expect(viewModel.saveCurrentFilter(named: " Work Focus "))
    let savedFilter = try #require(viewModel.savedFilters.first)
    #expect(savedFilter.name == "Work Focus")

    viewModel.clearFilters()
    #expect(viewModel.activeFilter == .empty)

    viewModel.applySavedFilter(id: savedFilter.id)
    #expect(viewModel.activeFilter.selectedLabels(for: .area) == ["area:work"])

    viewModel.deleteSavedFilter(id: savedFilter.id)
    #expect(viewModel.savedFilters.isEmpty)
    #expect(try filterStore.load()?.savedFilters.isEmpty == true)
  }

  @Test
  func reconcilesSuccessfulRemoteUpdateIntoVisibleListAndCache() throws {
    let original = LifeOSIssue(
      number: 10,
      title: "Cached task",
      body: "",
      labels: [GitHubLabel(name: "status:inbox", color: "ffffff")],
      updatedAt: Date(timeIntervalSince1970: 100),
      dueDate: ProjectDate(githubDate: "2026-07-28")
    )
    let snapshot = IssueCacheSnapshot(
      issues: [original],
      lastSyncedAt: Date(timeIntervalSince1970: 100),
      lastFullSyncedAt: Date(timeIntervalSince1970: 50)
    )
    let cache = ViewModelCacheStore(snapshot: snapshot)
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([])),
        cacheStore: cache
      ),
      filterStore: ViewModelFilterStore()
    )
    let updated = LifeOSIssue(
      number: 10,
      title: "Updated task",
      body: "New body",
      labels: [
        GitHubLabel(name: "status:active", color: "ffffff"),
        GitHubLabel(name: "priority:p1", color: "000000"),
      ],
      updatedAt: Date(timeIntervalSince1970: 200)
    )

    viewModel.reconcileRemoteIssue(updated)

    #expect(viewModel.issues == [updated.preservingProjectFields(from: original)])
    #expect(viewModel.issues[0].dueDate == original.dueDate)
    let loadedSnapshot = try cache.load()
    let saved = try #require(loadedSnapshot)
    #expect(saved.issues == [updated.preservingProjectFields(from: original)])
    #expect(saved.lastSyncedAt == snapshot.lastSyncedAt)
    #expect(saved.lastFullSyncedAt == snapshot.lastFullSyncedAt)
  }

  @Test
  func removesSuccessfullyClosedIssueFromVisibleListAndCache() throws {
    let original = viewModelTestIssue(number: 11)
    let cache = ViewModelCacheStore(
      snapshot: IssueCacheSnapshot(issues: [original], lastSyncedAt: nil)
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([])),
        cacheStore: cache
      ),
      filterStore: ViewModelFilterStore()
    )
    let closed = LifeOSIssue(
      number: original.number,
      title: original.title,
      body: original.body,
      labels: [
        GitHubLabel(name: "status:done", color: "ffffff"),
        GitHubLabel(name: "priority:p2", color: "000000"),
      ],
      updatedAt: Date(timeIntervalSince1970: 200),
      state: .closed
    )

    viewModel.reconcileRemoteIssue(closed)

    #expect(viewModel.issues.isEmpty)
    #expect(try cache.load()?.issues.isEmpty == true)
  }

  /// The panel quick-add composer relies on reconcile alone to surface a brand new
  /// issue, with no refresh round trip, so an unknown issue number must be inserted
  /// into the visible list, land in the Inbox section, and be written to the cache.
  @Test
  func reconcileInsertsUnknownIssueIntoInboxSectionAndCache() throws {
    let existing = viewModelTestIssue(number: 10)
    let cache = ViewModelCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [existing],
        lastSyncedAt: Date(timeIntervalSince1970: 100),
        lastFullSyncedAt: Date(timeIntervalSince1970: 50)
      )
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([])),
        cacheStore: cache
      ),
      filterStore: ViewModelFilterStore()
    )
    let created = LifeOSIssue(
      number: 11,
      title: "Composed task",
      body: "",
      labels: [
        GitHubLabel(name: LabelRules.defaultStatus, color: "ffffff"),
        GitHubLabel(name: "type:task", color: "ffffff"),
        GitHubLabel(name: "source:manual", color: "ffffff"),
        GitHubLabel(name: LabelRules.defaultPriority, color: "ffffff"),
      ],
      updatedAt: Date(timeIntervalSince1970: 300)
    )

    viewModel.reconcileRemoteIssue(created)

    #expect(viewModel.issues.map(\.number) == [10, 11])
    let inboxSection = try #require(viewModel.sections.first { $0.status == .inbox })
    #expect(inboxSection.issues.contains(created))
    #expect(try cache.load()?.issues.map(\.number) == [10, 11])
  }
  @Test
  func changingTheTaskRepositoryDropsTheOtherRepositorysCachedTasks() async throws {
    let cache = ViewModelCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [viewModelTestIssue(number: 7)],
        lastSyncedAt: Date(timeIntervalSince1970: 1_785_100_000),
        lastFullSyncedAt: Date(timeIntervalSince1970: 1_785_100_000),
        projectFieldAccess: .available
      )
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .success([])),
        cacheStore: cache
      ),
      filterStore: ViewModelFilterStore()
    )
    #expect(!viewModel.issues.isEmpty)

    viewModel.resetForRepositoryChange()

    #expect(viewModel.issues.isEmpty)
    #expect(viewModel.lastSyncedAt == nil)
    #expect(viewModel.projectFieldAccess == .unknown)
    // The watermark has to be cleared on disk too, or the next delta refresh
    // would ask the new repo only for issues changed since the old repo's sync.
    let persisted = try #require(try cache.load())
    #expect(persisted.issues.isEmpty)
    #expect(persisted.lastSyncedAt == nil)
    #expect(persisted.lastFullSyncedAt == nil)
  }

  @Test
  func aRefreshThatWasInFlightWhenTheRepositoryChangedIsDiscarded() async throws {
    // Regression for the race found in review of #21: the old repository's
    // refresh finished *after* the reset, wrote its issues and a fresh
    // watermark to the cache, and put them back on screen under the new repo.
    let cache = ViewModelCacheStore()
    let client = ControlledIssueFetcher()
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(client: client, cacheStore: cache),
      filterStore: ViewModelFilterStore()
    )

    let refresh = Task { @MainActor in
      await viewModel.refresh(token: "token")
    }
    await client.waitUntilPending()

    viewModel.resetForRepositoryChange()
    await client.finish(with: [viewModelTestIssue(number: 7)])
    await refresh.value

    #expect(viewModel.issues.isEmpty)
    #expect(viewModel.lastSyncedAt == nil)
    let persisted = try #require(try cache.load())
    #expect(persisted.issues.isEmpty)
    // The watermark is the dangerous half: left set, the next refresh would be
    // a delta sync against the new repo using the old repo's sync time.
    #expect(persisted.lastSyncedAt == nil)
    #expect(persisted.lastFullSyncedAt == nil)
  }

  @Test
  func aRefreshInFlightAtSignOutCannotWriteTheSignedOutAccountsTasksBack() async throws {
    // Same race as a repository change, reached by signing out: the refresh
    // started under the old account finishes after `clearCachedTasks()` and
    // would put that account's tasks back on screen and on disk. A refresh
    // queued behind it carries the old token and must not run either.
    let cache = ViewModelCacheStore()
    // Only the first fetch suspends, so a queued refresh that wrongly runs
    // fails this test instead of hanging it.
    let client = ControlledIssueFetcher(
      laterCallsReturn: [viewModelTestIssue(number: 8)]
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(client: client, cacheStore: cache),
      filterStore: ViewModelFilterStore()
    )

    let refresh = Task { @MainActor in
      await viewModel.refresh(token: "old-account-token")
    }
    await client.waitUntilPending()
    await viewModel.refresh(token: "old-account-token")

    viewModel.clearCachedTasks()
    await client.finish(with: [viewModelTestIssue(number: 7)])
    await refresh.value

    #expect(viewModel.issues.isEmpty)
    #expect(viewModel.lastSyncedAt == nil)
    #expect(await client.callCount == 1)
    let persisted = try #require(try cache.load())
    #expect(persisted.issues.isEmpty)
    #expect(persisted.lastSyncedAt == nil)
    #expect(persisted.lastFullSyncedAt == nil)
  }

  @Test
  func aRefreshRequestedDuringAnInFlightOneRunsAfterwardsInsteadOfBeingDropped() async throws {
    let cache = ViewModelCacheStore()
    // Only the first fetch suspends; later ones answer immediately, so a
    // regression fails this test rather than hanging it waiting for a second
    // fetch that never comes.
    let client = ControlledIssueFetcher(
      laterCallsReturn: [viewModelTestIssue(number: 9)]
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(client: client, cacheStore: cache),
      filterStore: ViewModelFilterStore()
    )

    let firstRefresh = Task { @MainActor in
      await viewModel.refresh(token: "token")
    }
    await client.waitUntilPending()

    // What AppDelegate does when the repository changes: reset, then refresh.
    viewModel.resetForRepositoryChange()
    await viewModel.refresh(token: "token")

    await client.finish(with: [])
    await firstRefresh.value

    #expect(await client.callCount == 2)
    #expect(viewModel.issues.map(\.number) == [9])
  }

}

private func viewModelTestIssue(number: Int) -> LifeOSIssue {
  LifeOSIssue(
    number: number,
    title: "Cached task",
    body: "",
    labels: [GitHubLabel(name: "status:inbox", color: "ffffff")],
    updatedAt: Date(timeIntervalSince1970: 1_785_000_000)
  )
}

private actor ViewModelIssueFetcher: GitHubIssueFetching {
  private let result: Result<[LifeOSIssue], URLError>
  private(set) var callCount = 0

  init(result: Result<[LifeOSIssue], URLError>) {
    self.result = result
  }

  func fetchIssues(token: String, updatedAfter: Date?) async throws -> [LifeOSIssue] {
    callCount += 1
    return try result.get()
  }
}

private final class ViewModelCacheStore: IssueCacheStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var mutableSnapshot: IssueCacheSnapshot?

  init(snapshot: IssueCacheSnapshot? = nil) {
    self.mutableSnapshot = snapshot
  }

  func load() throws -> IssueCacheSnapshot? {
    lock.withLock {
      mutableSnapshot
    }
  }

  func save(_ snapshot: IssueCacheSnapshot) throws {
    lock.withLock {
      mutableSnapshot = snapshot
    }
  }
}

private final class ViewModelFilterStore: TaskFilterStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var mutableSnapshot: TaskFilterStoreSnapshot?

  init(snapshot: TaskFilterStoreSnapshot? = nil) {
    self.mutableSnapshot = snapshot
  }

  func load() throws -> TaskFilterStoreSnapshot? {
    lock.withLock {
      mutableSnapshot
    }
  }

  func save(_ snapshot: TaskFilterStoreSnapshot) throws {
    lock.withLock {
      mutableSnapshot = snapshot
    }
  }
}

/// A fetcher the test resumes by hand, so a repository change can be made to
/// land in the middle of a refresh.
private actor ControlledIssueFetcher: GitHubIssueFetching {
  private(set) var callCount = 0
  private let laterCallsReturn: [LifeOSIssue]?
  private var pending: CheckedContinuation<[LifeOSIssue], any Error>?
  private var waiters: [CheckedContinuation<Void, Never>] = []

  /// `laterCallsReturn` makes every fetch after the first answer immediately
  /// with those issues; `nil` suspends every fetch until `finish(with:)`.
  init(laterCallsReturn: [LifeOSIssue]? = nil) {
    self.laterCallsReturn = laterCallsReturn
  }

  func fetchIssues(token: String, updatedAfter: Date?) async throws -> [LifeOSIssue] {
    callCount += 1
    if callCount > 1, let laterCallsReturn {
      return laterCallsReturn
    }
    return try await withCheckedThrowingContinuation { continuation in
      pending = continuation
      for waiter in waiters {
        waiter.resume()
      }
      waiters = []
    }
  }

  func waitUntilPending() async {
    guard pending == nil else {
      return
    }
    await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  func finish(with issues: [LifeOSIssue]) {
    guard let continuation = pending else {
      preconditionFailure("No pending fetch to finish")
    }
    pending = nil
    continuation.resume(returning: issues)
  }
}
