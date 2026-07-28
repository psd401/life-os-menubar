import Combine
import Foundation

@MainActor
public final class TaskListViewModel: ObservableObject {
  @Published public private(set) var issues: [LifeOSIssue] = []
  @Published public var searchText = ""
  @Published public private(set) var activeFilter: TaskFilterSelection = .empty
  @Published public private(set) var savedFilters: [SavedTaskFilter] = []
  @Published public private(set) var lastSyncedAt: Date?
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

  private let cacheStore: any IssueCacheStoring
  private let syncEngine: IssueSyncEngine
  private let filterStore: any TaskFilterStoring
  private var backgroundRefreshTask: Task<Void, Never>?

  public init(
    cacheStore: any IssueCacheStoring,
    syncEngine: IssueSyncEngine,
    filterStore: any TaskFilterStoring
  ) {
    self.cacheStore = cacheStore
    self.syncEngine = syncEngine
    self.filterStore = filterStore

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

  private func apply(_ snapshot: IssueCacheSnapshot) {
    issues = snapshot.issues
    lastSyncedAt = snapshot.lastSyncedAt
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
