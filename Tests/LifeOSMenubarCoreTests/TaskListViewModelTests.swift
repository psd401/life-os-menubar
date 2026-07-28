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
        lastSyncedAt: Date(timeIntervalSince1970: 1_785_100_000)
      )
    )
    let client = ViewModelIssueFetcher(result: .success([]))
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(client: client, cacheStore: cache)
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
        lastSyncedAt: Date(timeIntervalSince1970: 1_785_100_000)
      )
    )
    let viewModel = TaskListViewModel(
      cacheStore: cache,
      syncEngine: IssueSyncEngine(
        client: ViewModelIssueFetcher(result: .failure(URLError(.notConnectedToInternet))),
        cacheStore: cache
      )
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
      )
    )

    await viewModel.refresh(token: "token")

    #expect(viewModel.issues == [fetchedIssue])
    #expect(viewModel.lastSyncedAt == refreshTime)
    #expect(viewModel.errorMessage == nil)
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
