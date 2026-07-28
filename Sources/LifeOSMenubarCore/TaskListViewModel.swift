import Combine
import Foundation

@MainActor
public final class TaskListViewModel: ObservableObject {
  @Published public private(set) var issues: [LifeOSIssue] = []
  @Published public var searchText = ""
  @Published public private(set) var lastSyncedAt: Date?
  @Published public private(set) var isRefreshing = false
  @Published public private(set) var errorMessage: String?

  public var sections: [TaskSectionSnapshot] {
    TaskListPresentation.sections(issues: issues, searchText: searchText)
  }

  private let cacheStore: any IssueCacheStoring
  private let syncEngine: IssueSyncEngine
  private var backgroundRefreshTask: Task<Void, Never>?

  public init(
    cacheStore: any IssueCacheStoring,
    syncEngine: IssueSyncEngine
  ) {
    self.cacheStore = cacheStore
    self.syncEngine = syncEngine

    do {
      apply(try cacheStore.load() ?? .empty)
    } catch {
      errorMessage = "Cached tasks could not be loaded: \(error.localizedDescription)"
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

  private func apply(_ snapshot: IssueCacheSnapshot) {
    issues = snapshot.issues
    lastSyncedAt = snapshot.lastSyncedAt
  }
}
