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
    #expect(cache.snapshot == snapshot)
  }

  @Test
  func deltaRefreshUsesWatermarkMergesUpdatesAndRemovesClosedIssues() async throws {
    let watermark = Date(timeIntervalSince1970: 1_785_100_000)
    let unchangedIssue = syncTestIssue(number: 1, title: "Unchanged")
    let replacedIssue = syncTestIssue(number: 2, title: "Old title")
    let cache = InMemoryIssueCacheStore(
      snapshot: IssueCacheSnapshot(
        issues: [unchangedIssue, replacedIssue],
        lastSyncedAt: watermark
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
  }

  @Test
  func failedRefreshLeavesExistingCacheUntouched() async {
    let existing = IssueCacheSnapshot(
      issues: [syncTestIssue(number: 1)],
      lastSyncedAt: Date(timeIntervalSince1970: 1_785_100_000)
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
