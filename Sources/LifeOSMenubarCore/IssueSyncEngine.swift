import Foundation

public actor IssueSyncEngine {
  private let client: any GitHubIssueFetching
  private let projectFieldClient: (any GitHubProjectFieldFetching)?
  private let cacheStore: any IssueCacheStoring
  private let now: @Sendable () -> Date
  private let fullRefreshInterval: TimeInterval

  public init(
    client: any GitHubIssueFetching,
    projectFieldClient: (any GitHubProjectFieldFetching)? = nil,
    cacheStore: any IssueCacheStoring,
    now: @escaping @Sendable () -> Date = Date.init,
    fullRefreshInterval: TimeInterval = 24 * 60 * 60
  ) {
    self.client = client
    self.projectFieldClient = projectFieldClient
    self.cacheStore = cacheStore
    self.now = now
    self.fullRefreshInterval = fullRefreshInterval
  }

  public func refresh(token: String) async throws -> IssueCacheSnapshot {
    let existingSnapshot = try cacheStore.load() ?? .empty
    let refreshStartedAt = now()
    let fullRefreshExpired =
      existingSnapshot.lastFullSyncedAt.map {
        refreshStartedAt.timeIntervalSince($0) >= fullRefreshInterval
      } ?? true
    let shouldPerformFullRefresh =
      existingSnapshot.lastSyncedAt == nil || fullRefreshExpired
    let updates = try await client.fetchIssues(
      token: token,
      updatedAfter: shouldPerformFullRefresh ? nil : existingSnapshot.lastSyncedAt
    )
    let projectFieldResult = try await projectFieldClient?.fetchProjectFields(token: token)

    let baseIssues: [LifeOSIssue]
    if shouldPerformFullRefresh {
      baseIssues = updates.filter { $0.state == .open }
    } else {
      baseIssues = Self.merge(existing: existingSnapshot.issues, updates: updates)
    }
    let mergedIssues = Self.applyingProjectFields(
      to: baseIssues,
      result: projectFieldResult
    )

    let snapshot = IssueCacheSnapshot(
      issues: mergedIssues.sorted { $0.number < $1.number },
      lastSyncedAt: max(existingSnapshot.lastSyncedAt ?? .distantPast, refreshStartedAt),
      lastFullSyncedAt: shouldPerformFullRefresh
        ? refreshStartedAt
        : existingSnapshot.lastFullSyncedAt,
      projectFieldAccess: projectFieldResult?.access ?? existingSnapshot.projectFieldAccess
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
        if let existingIssue = issuesByNumber[issue.number] {
          issuesByNumber[issue.number] = issue.preservingProjectFields(from: existingIssue)
        } else {
          issuesByNumber[issue.number] = issue
        }
      case .closed:
        issuesByNumber.removeValue(forKey: issue.number)
      }
    }
    return Array(issuesByNumber.values)
  }

  private static func applyingProjectFields(
    to issues: [LifeOSIssue],
    result: ProjectFieldFetchResult?
  ) -> [LifeOSIssue] {
    guard let result else {
      return issues
    }

    switch result.access {
    case .available:
      return issues.map { issue in
        issue.updatingProjectFields(
          result.fieldsByIssueNumber[issue.number] ?? IssueProjectFields()
        )
      }
    case .missingScope:
      return issues.map { $0.updatingProjectFields(IssueProjectFields()) }
    case .unknown:
      return issues
    }
  }
}
