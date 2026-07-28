import Foundation
import Testing

@testable import LifeOSMenubarCore

struct IssueSyncEngineTests {
  @Test
  func initialRefreshFetchesAllOpenIssuesAndPersistsThem() async throws {
    let fetchedIssues = [
      syncTestIssue(number: 2, state: .closed),
      syncTestIssue(number: 1, state: .open),
    ]
    let client = IssueFetcherSpy(result: .success(fetchedIssues))
    let cache = InMemoryIssueCacheStore()
    let refreshTime = Date(timeIntervalSince1970: 1_785_200_000)
    let engine = IssueSyncEngine(
      client: client,
      cacheStore: cache,
      now: { refreshTime }
    )

    let snapshot = try await engine.refresh(token: "token")

    #expect(await client.receivedWatermarks == [nil])
    #expect(snapshot.issues.map(\.number) == [1])
    #expect(snapshot.lastSyncedAt == refreshTime)
    #expect(snapshot.lastFullSyncedAt == refreshTime)
    #expect(cache.snapshot == snapshot)
  }

  @Test
  func deltaRefreshUsesWatermarkMergesUpdatesAndRemovesClosedIssues() async throws {
    let watermark = Date(timeIntervalSince1970: 1_785_190_000)
    let lastFullSync = Date(timeIntervalSince1970: 1_785_150_000)
    let unchangedIssue = syncTestIssue(number: 1, title: "Unchanged")
    let replacedIssue = syncTestIssue(number: 2, title: "Old title")
    let cache = InMemoryIssueCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [unchangedIssue, replacedIssue],
        lastSyncedAt: watermark,
        lastFullSyncedAt: lastFullSync
      )
    )
    let client = IssueFetcherSpy(
      result: .success([
        syncTestIssue(number: 2, title: "New title"),
        syncTestIssue(number: 1, state: .closed),
        syncTestIssue(number: 3, title: "New issue"),
      ])
    )
    let refreshTime = Date(timeIntervalSince1970: 1_785_200_000)
    let engine = IssueSyncEngine(
      client: client,
      cacheStore: cache,
      now: { refreshTime }
    )

    let snapshot = try await engine.refresh(token: "token")

    #expect(await client.receivedWatermarks == [watermark])
    #expect(snapshot.issues.map(\.number) == [2, 3])
    #expect(snapshot.issues[0].title == "New title")
    #expect(snapshot.lastSyncedAt == refreshTime)
    #expect(snapshot.lastFullSyncedAt == lastFullSync)
  }

  @Test
  func refreshPerformsFullReconciliationAfterTwentyFourHours() async throws {
    let lastFullSync = Date(timeIntervalSince1970: 1_785_000_000)
    let lastDeltaSync = Date(timeIntervalSince1970: 1_785_050_000)
    let refreshTime = lastFullSync.addingTimeInterval((24 * 60 * 60) + 1)
    let staleIssue = syncTestIssue(number: 1, title: "Stale label")
    let reconciledIssue = syncTestIssue(number: 2, title: "Current labels")
    let cache = InMemoryIssueCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [staleIssue],
        lastSyncedAt: lastDeltaSync,
        lastFullSyncedAt: lastFullSync
      )
    )
    let client = IssueFetcherSpy(result: .success([reconciledIssue]))
    let engine = IssueSyncEngine(
      client: client,
      cacheStore: cache,
      now: { refreshTime }
    )

    let snapshot = try await engine.refresh(token: "token")

    #expect(await client.receivedWatermarks == [nil])
    #expect(snapshot.issues == [reconciledIssue])
    #expect(snapshot.lastSyncedAt == refreshTime)
    #expect(snapshot.lastFullSyncedAt == refreshTime)
  }

  @Test
  func failedRefreshLeavesExistingCacheUntouched() async {
    let existing = IssueCacheSnapshot(
      issues: [syncTestIssue(number: 1)],
      lastSyncedAt: Date(timeIntervalSince1970: 1_785_100_000),
      lastFullSyncedAt: Date(timeIntervalSince1970: 1_785_100_000)
    )
    let cache = InMemoryIssueCacheStore(snapshot: existing)
    let engine = IssueSyncEngine(
      client: IssueFetcherSpy(result: .failure(.network)),
      cacheStore: cache
    )

    await #expect(throws: IssueFetcherSpy.StubError.network) {
      try await engine.refresh(token: "token")
    }
    #expect(cache.snapshot == existing)
    #expect(cache.saveCallCount == 0)
  }

  @Test
  func refreshMergesProjectDatesForEveryOpenCachedIssue() async throws {
    let watermark = Date(timeIntervalSince1970: 1_785_190_000)
    let cachedIssue = syncTestIssue(number: 1)
    let cache = InMemoryIssueCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [cachedIssue],
        lastSyncedAt: watermark,
        lastFullSyncedAt: watermark
      )
    )
    let projectFields = ProjectFieldFetchResult(
      fieldsByIssueNumber: [
        1: IssueProjectFields(
          dueDate: ProjectDate(githubDate: "2026-07-28"),
          deferUntil: ProjectDate(githubDate: "2026-07-27")
        )
      ],
      access: .available
    )
    let engine = IssueSyncEngine(
      client: IssueFetcherSpy(result: .success([])),
      projectFieldClient: ProjectFieldFetcherStub(result: .success(projectFields)),
      cacheStore: cache,
      now: { watermark.addingTimeInterval(60) }
    )

    let snapshot = try await engine.refresh(token: "token")

    #expect(snapshot.projectFieldAccess == .available)
    #expect(snapshot.issues[0].dueDate == ProjectDate(githubDate: "2026-07-28"))
    #expect(snapshot.issues[0].deferUntil == ProjectDate(githubDate: "2026-07-27"))
  }

  @Test
  func projectDateChangesApplyEvenWhenIssueDeltaIsEmpty() async throws {
    let watermark = Date(timeIntervalSince1970: 1_785_190_000)
    let cachedIssue = LifeOSIssue(
      number: 1,
      title: "Task",
      body: "",
      labels: [GitHubLabel(name: "status:inbox", color: "ffffff")],
      updatedAt: watermark,
      dueDate: ProjectDate(githubDate: "2026-07-29")
    )
    let cache = InMemoryIssueCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [cachedIssue],
        lastSyncedAt: watermark,
        lastFullSyncedAt: watermark,
        projectFieldAccess: .available
      )
    )
    let projectFields = ProjectFieldFetchResult(
      fieldsByIssueNumber: [
        1: IssueProjectFields(dueDate: ProjectDate(githubDate: "2026-07-28"))
      ],
      access: .available
    )
    let engine = IssueSyncEngine(
      client: IssueFetcherSpy(result: .success([])),
      projectFieldClient: ProjectFieldFetcherStub(result: .success(projectFields)),
      cacheStore: cache,
      now: { watermark.addingTimeInterval(60) }
    )

    let snapshot = try await engine.refresh(token: "token")

    #expect(snapshot.issues[0].dueDate == ProjectDate(githubDate: "2026-07-28"))
  }

  @Test
  func missingProjectScopeClearsStaleDatesButKeepsNormalIssueRefreshWorking() async throws {
    let refreshTime = Date(timeIntervalSince1970: 1_785_200_000)
    let fetchedIssue = syncTestIssue(number: 1, title: "Fresh title")
    let cache = InMemoryIssueCacheStore()
    let engine = IssueSyncEngine(
      client: IssueFetcherSpy(result: .success([fetchedIssue])),
      projectFieldClient: ProjectFieldFetcherStub(result: .success(.missingScope)),
      cacheStore: cache,
      now: { refreshTime }
    )

    let snapshot = try await engine.refresh(token: "token")

    #expect(snapshot.issues.map(\.title) == ["Fresh title"])
    #expect(snapshot.issues[0].dueDate == nil)
    #expect(snapshot.projectFieldAccess == .missingScope)
    #expect(cache.snapshot == snapshot)
  }
}

private func syncTestIssue(
  number: Int,
  title: String = "Task",
  state: GitHubIssueState = .open
) -> LifeOSIssue {
  LifeOSIssue(
    number: number,
    title: title,
    body: "",
    labels: [GitHubLabel(name: "status:inbox", color: "ffffff")],
    updatedAt: Date(timeIntervalSince1970: Double(1_785_000_000 + number)),
    state: state
  )
}

private actor IssueFetcherSpy: GitHubIssueFetching {
  enum StubError: Error {
    case network
  }

  private let result: Result<[LifeOSIssue], StubError>
  private(set) var receivedWatermarks: [Date?] = []

  init(result: Result<[LifeOSIssue], StubError>) {
    self.result = result
  }

  func fetchIssues(token: String, updatedAfter: Date?) async throws -> [LifeOSIssue] {
    receivedWatermarks.append(updatedAfter)
    return try result.get()
  }
}

private actor ProjectFieldFetcherStub: GitHubProjectFieldFetching {
  enum StubError: Error {
    case network
  }

  private let result: Result<ProjectFieldFetchResult, StubError>

  init(result: Result<ProjectFieldFetchResult, StubError>) {
    self.result = result
  }

  func fetchProjectFields(token: String) async throws -> ProjectFieldFetchResult {
    try result.get()
  }
}

private final class InMemoryIssueCacheStore: IssueCacheStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var mutableSnapshot: IssueCacheSnapshot?
  private var mutableSaveCallCount = 0

  init(snapshot: IssueCacheSnapshot? = nil) {
    self.mutableSnapshot = snapshot
  }

  var snapshot: IssueCacheSnapshot? {
    lock.withLock {
      mutableSnapshot
    }
  }

  var saveCallCount: Int {
    lock.withLock {
      mutableSaveCallCount
    }
  }

  func load() throws -> IssueCacheSnapshot? {
    lock.withLock {
      mutableSnapshot
    }
  }

  func save(_ snapshot: IssueCacheSnapshot) throws {
    lock.withLock {
      mutableSnapshot = snapshot
      mutableSaveCallCount += 1
    }
  }
}
