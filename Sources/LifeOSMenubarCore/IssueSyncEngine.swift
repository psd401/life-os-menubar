import Foundation

public actor IssueSyncEngine {
  private let client: any GitHubIssueFetching
  private let cacheStore: any IssueCacheStoring
  private let now: @Sendable () -> Date

  public init(
    client: any GitHubIssueFetching,
    cacheStore: any IssueCacheStoring,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.client = client
    self.cacheStore = cacheStore
    self.now = now
  }

  public func refresh(token: String) async throws -> IssueCacheSnapshot {
    let existingSnapshot = try cacheStore.load() ?? .empty
    let refreshStartedAt = now()
    let updates = try await client.fetchIssues(
      token: token,
      updatedAfter: existingSnapshot.lastSyncedAt
    )

    let mergedIssues: [LifeOSIssue]
    if existingSnapshot.lastSyncedAt == nil {
      mergedIssues = updates.filter { $0.state == .open }
    } else {
      mergedIssues = Self.merge(existing: existingSnapshot.issues, updates: updates)
    }

    let snapshot = IssueCacheSnapshot(
      issues: mergedIssues.sorted { $0.number < $1.number },
      lastSyncedAt: max(existingSnapshot.lastSyncedAt ?? .distantPast, refreshStartedAt)
    )
    try cacheStore.save(snapshot)
    return snapshot
  }

  private static func merge(
    existing: [LifeOSIssue],
    updates: [LifeOSIssue]
  ) -> [LifeOSIssue] {
    var issuesByNumber = Dictionary(
      uniqueKeysWithValues:
        existing
        .filter { $0.state == .open }
        .map { ($0.number, $0) }
    )

    for issue in updates {
      switch issue.state {
      case .open:
        issuesByNumber[issue.number] = issue
      case .closed:
        issuesByNumber.removeValue(forKey: issue.number)
      }
    }
    return Array(issuesByNumber.values)
  }
}
