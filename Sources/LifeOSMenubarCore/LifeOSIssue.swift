import Foundation

public struct GitHubLabel: Codable, Equatable, Hashable, Sendable {
  public let name: String
  public let color: String

  public init(name: String, color: String) {
    self.name = name
    self.color = color
  }
}

public enum GitHubIssueState: String, Codable, Equatable, Sendable {
  case open = "OPEN"
  case closed = "CLOSED"
}

public struct LifeOSIssue: Codable, Equatable, Identifiable, Sendable {
  public var id: Int {
    number
  }

  public let number: Int
  public let title: String
  public let body: String
  public let labels: [GitHubLabel]
  public let updatedAt: Date
  public let state: GitHubIssueState

  public init(
    number: Int,
    title: String,
    body: String,
    labels: [GitHubLabel],
    updatedAt: Date,
    state: GitHubIssueState = .open
  ) {
    self.number = number
    self.title = title
    self.body = body
    self.labels = labels
    self.updatedAt = updatedAt
    self.state = state
  }
}

public enum TaskStatusSection: String, CaseIterable, Identifiable, Sendable {
  case inbox
  case next
  case active
  case waiting
  case scheduled
  case someday

  public var id: String {
    rawValue
  }

  public var title: String {
    rawValue.capitalized
  }

  public var labelName: String {
    "status:\(rawValue)"
  }
}

public struct TaskSectionSnapshot: Equatable, Identifiable, Sendable {
  public var id: TaskStatusSection {
    status
  }

  public let status: TaskStatusSection
  public let issues: [LifeOSIssue]

  public init(status: TaskStatusSection, issues: [LifeOSIssue]) {
    self.status = status
    self.issues = issues
  }
}

public enum TaskListPresentation {
  public static func sections(
    issues: [LifeOSIssue],
    searchText: String,
    filterSelection: TaskFilterSelection = .empty
  ) -> [TaskSectionSnapshot] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let visibleIssues = issues.filter { issue in
      issue.state == .open
        && (query.isEmpty || issue.title.localizedCaseInsensitiveContains(query))
        && TaskFilterPredicate.matches(issue: issue, selection: filterSelection)
    }

    return TaskStatusSection.allCases.map { status in
      let matchingIssues =
        visibleIssues
        .filter { issue in
          issue.labels.contains { $0.name == status.labelName }
        }
        .sorted(by: issueSort)
      return TaskSectionSnapshot(status: status, issues: matchingIssues)
    }
  }

  private static func issueSort(_ lhs: LifeOSIssue, _ rhs: LifeOSIssue) -> Bool {
    let lhsPriority = priorityRank(for: lhs)
    let rhsPriority = priorityRank(for: rhs)
    if lhsPriority != rhsPriority {
      return lhsPriority < rhsPriority
    }
    if lhs.updatedAt != rhs.updatedAt {
      return lhs.updatedAt > rhs.updatedAt
    }
    return lhs.number < rhs.number
  }

  private static func priorityRank(for issue: LifeOSIssue) -> Int {
    guard
      let priorityLabel = issue.labels.first(where: { $0.name.hasPrefix("priority:p") }),
      let rank = Int(priorityLabel.name.dropFirst("priority:p".count))
    else {
      return Int.max
    }
    return rank
  }
}
