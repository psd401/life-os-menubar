import Foundation
import Testing

@testable import LifeOSMenubarCore

struct ProjectFieldsTests {
  @Test
  func projectDateValidatesAndRoundTripsGitHubDateValues() {
    #expect(ProjectDate(githubDate: "2024-02-29")?.githubDate == "2024-02-29")
    #expect(ProjectDate(githubDate: "2026-02-30") == nil)
    #expect(ProjectDate(githubDate: "2026-7-28") == nil)
    #expect(ProjectDate(githubDate: "not-a-date") == nil)
  }

  @Test
  func todayIncludesDueAndOverdueTasksButExcludesFutureDueTasks() throws {
    let context = try todayTestContext()
    let issues = [
      projectFieldTestIssue(number: 1, dueDate: "2026-07-27"),
      projectFieldTestIssue(number: 2, dueDate: "2026-07-28"),
      projectFieldTestIssue(number: 3, dueDate: "2026-07-29"),
      projectFieldTestIssue(number: 4, dueDate: nil),
    ]

    let visible = TodayTaskPresentation.issues(
      from: issues,
      now: context.now,
      calendar: context.calendar
    )

    #expect(visible.map(\.number) == [1, 2])
  }

  @Test
  func deferAfterTodayHidesDueTaskWhileDeferTodayDoesNot() throws {
    let context = try todayTestContext()
    let issues = [
      projectFieldTestIssue(
        number: 1,
        dueDate: "2026-07-27",
        deferUntil: "2026-07-29"
      ),
      projectFieldTestIssue(
        number: 2,
        dueDate: "2026-07-28",
        deferUntil: "2026-07-28"
      ),
      projectFieldTestIssue(
        number: 3,
        dueDate: "2026-07-27",
        deferUntil: "2026-07-26"
      ),
    ]

    let visible = TodayTaskPresentation.issues(
      from: issues,
      now: context.now,
      calendar: context.calendar
    )

    #expect(visible.map(\.number) == [3, 2])
  }

  @Test
  func todayComposesWithSearchFiltersAndOpenState() throws {
    let context = try todayTestContext()
    let selection = TaskFilterSelection(labelsByFamily: [.area: ["area:work"]])
    let issues = [
      projectFieldTestIssue(
        number: 1,
        title: "Prepare work notes",
        dueDate: "2026-07-28",
        extraLabels: ["area:work"]
      ),
      projectFieldTestIssue(
        number: 2,
        title: "Prepare home notes",
        dueDate: "2026-07-28",
        extraLabels: ["area:home"]
      ),
      projectFieldTestIssue(
        number: 3,
        title: "Prepare closed notes",
        state: .closed,
        dueDate: "2026-07-28",
        extraLabels: ["area:work"]
      ),
    ]

    let visible = TodayTaskPresentation.issues(
      from: issues,
      now: context.now,
      calendar: context.calendar,
      searchText: "prepare",
      filterSelection: selection
    )

    #expect(visible.map(\.number) == [1])
  }
}

private func todayTestContext() throws -> (now: Date, calendar: Calendar) {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
  let now = try #require(
    ISO8601DateFormatter().date(from: "2026-07-28T19:00:00Z")
  )
  return (now, calendar)
}

private func projectFieldTestIssue(
  number: Int,
  title: String = "Task",
  state: GitHubIssueState = .open,
  dueDate: String?,
  deferUntil: String? = nil,
  extraLabels: [String] = []
) -> LifeOSIssue {
  LifeOSIssue(
    number: number,
    title: title,
    body: "",
    labels: [
      GitHubLabel(name: "status:inbox", color: "ffffff"),
      GitHubLabel(name: "priority:p2", color: "000000"),
    ] + extraLabels.map { GitHubLabel(name: $0, color: "111111") },
    updatedAt: Date(timeIntervalSince1970: Double(number)),
    state: state,
    dueDate: dueDate.flatMap(ProjectDate.init(githubDate:)),
    deferUntil: deferUntil.flatMap(ProjectDate.init(githubDate:))
  )
}
