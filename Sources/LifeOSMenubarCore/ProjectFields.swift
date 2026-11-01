import Foundation

public struct ProjectDate: Codable, Equatable, Hashable, Comparable, Sendable {
  public let year: Int
  public let month: Int
  public let day: Int

  public init?(githubDate: String) {
    let components = githubDate.split(separator: "-", omittingEmptySubsequences: false)
    guard components.count == 3,
      components[0].count == 4,
      components[1].count == 2,
      components[2].count == 2,
      let year = Int(components[0]),
      let month = Int(components[1]),
      let day = Int(components[2]),
      Self.isValid(year: year, month: month, day: day)
    else {
      return nil
    }

    self.year = year
    self.month = month
    self.day = day
  }

  public init(date: Date, calendar: Calendar = .current) {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    self.year = components.year ?? 1
    self.month = components.month ?? 1
    self.day = components.day ?? 1
  }

  public var githubDate: String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }

  public static func < (lhs: ProjectDate, rhs: ProjectDate) -> Bool {
    if lhs.year != rhs.year {
      return lhs.year < rhs.year
    }
    if lhs.month != rhs.month {
      return lhs.month < rhs.month
    }
    return lhs.day < rhs.day
  }

  private static func isValid(year: Int, month: Int, day: Int) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let components = DateComponents(
      calendar: calendar,
      timeZone: calendar.timeZone,
      year: year,
      month: month,
      day: day
    )
    guard let date = calendar.date(from: components) else {
      return false
    }
    let verified = calendar.dateComponents([.year, .month, .day], from: date)
    return verified.year == year && verified.month == month && verified.day == day
  }
}

public enum ProjectFieldAccess: String, Codable, Equatable, Sendable {
  case unknown
  case available
  case missingScope
}

public struct IssueProjectFields: Codable, Equatable, Sendable {
  public let dueDate: ProjectDate?
  public let deferUntil: ProjectDate?

  public init(
    dueDate: ProjectDate? = nil,
    deferUntil: ProjectDate? = nil
  ) {
    self.dueDate = dueDate
    self.deferUntil = deferUntil
  }
}

public struct ProjectFieldFetchResult: Equatable, Sendable {
  public let fieldsByIssueNumber: [Int: IssueProjectFields]
  public let access: ProjectFieldAccess

  public init(
    fieldsByIssueNumber: [Int: IssueProjectFields],
    access: ProjectFieldAccess
  ) {
    self.fieldsByIssueNumber = fieldsByIssueNumber
    self.access = access
  }

  public static let missingScope = ProjectFieldFetchResult(
    fieldsByIssueNumber: [:],
    access: .missingScope
  )
}

public protocol GitHubProjectFieldFetching: Sendable {
  func fetchProjectFields(token: String) async throws -> ProjectFieldFetchResult
}

public enum TodayTaskPresentation {
  public static func issues(
    from issues: [LifeOSIssue],
    now: Date = Date(),
    calendar: Calendar = .current,
    searchText: String = "",
    filterSelection: TaskFilterSelection = .empty
  ) -> [LifeOSIssue] {
    let today = ProjectDate(date: now, calendar: calendar)
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

    return
      issues
      .filter { issue in
        guard issue.state == .open,
          let dueDate = issue.dueDate,
          dueDate <= today
        else {
          return false
        }
        guard issue.deferUntil.map({ $0 > today }) != true else {
          return false
        }
        return (query.isEmpty || issue.title.localizedCaseInsensitiveContains(query))
          && TaskFilterPredicate.matches(issue: issue, selection: filterSelection)
      }
      .sorted(by: issueSort)
  }

  private static func issueSort(_ lhs: LifeOSIssue, _ rhs: LifeOSIssue) -> Bool {
    if lhs.dueDate != rhs.dueDate {
      return (lhs.dueDate ?? ProjectDate(date: .distantFuture))
        < (rhs.dueDate ?? ProjectDate(date: .distantFuture))
    }
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
