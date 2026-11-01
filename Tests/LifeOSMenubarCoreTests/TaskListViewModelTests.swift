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
