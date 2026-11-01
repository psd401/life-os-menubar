import Foundation
import Testing

@testable import LifeOSMenubarCore

struct TaskListPresentationTests {
  @Test
  func alwaysReturnsSixSectionsInFixedOrderWithCounts() {
    let sections = TaskListPresentation.sections(
      issues: [
        presentationIssue(number: 1, status: .active),
        presentationIssue(number: 2, status: .inbox),
        presentationIssue(number: 3, status: .inbox),
      ],
      searchText: ""
    )

    #expect(sections.map(\.status) == TaskStatusSection.allCases)
    #expect(sections.map(\.issues.count) == [2, 0, 1, 0, 0, 0])
  }

  @Test
  func sortsByPriorityThenNewestUpdatedAt() {
    let sections = TaskListPresentation.sections(
      issues: [
        presentationIssue(
          number: 1,
          status: .next,
          priority: "priority:p2",
          updatedAt: Date(timeIntervalSince1970: 300)
        ),
        presentationIssue(
          number: 2,
          status: .next,
          priority: "priority:p1",
          updatedAt: Date(timeIntervalSince1970: 100)
        ),
        presentationIssue(
          number: 3,
          status: .next,
          priority: "priority:p1",
          updatedAt: Date(timeIntervalSince1970: 200)
        ),
        presentationIssue(
          number: 4,
          status: .next,
          priority: nil,
          updatedAt: Date(timeIntervalSince1970: 400)
        ),
      ],
      searchText: ""
    )

    let next = sections[1]
    #expect(next.status == .next)
    #expect(next.issues.map(\.number) == [3, 2, 1, 4])
  }

  @Test
  func searchMatchesTitleCaseInsensitivelyAndComposesWithSections() {
    let sections = TaskListPresentation.sections(
      issues: [
        presentationIssue(number: 1, title: "Book dentist", status: .inbox),
        presentationIssue(number: 2, title: "Book flights", status: .scheduled),
        presentationIssue(number: 3, title: "Buy groceries", status: .inbox),
      ],
      searchText: " BOOK "
    )

    #expect(sections.first { $0.status == .inbox }?.issues.map(\.number) == [1])
    #expect(sections.first { $0.status == .scheduled }?.issues.map(\.number) == [2])
    #expect(sections.reduce(0) { $0 + $1.issues.count } == 2)
  }

  @Test
  func searchAndActiveFiltersApplySimultaneously() {
    let selection = TaskFilterSelection(
      labelsByFamily: [
        .area: ["area:work"],
        .priority: ["priority:p1"],
      ]
    )
    let sections = TaskListPresentation.sections(
      issues: [
        presentationIssue(
          number: 1,
          title: "Book work trip",
          status: .inbox,
          priority: "priority:p1",
          extraLabels: ["area:work"]
        ),
        presentationIssue(
          number: 2,
          title: "Book work lunch",
          status: .inbox,
          priority: "priority:p2",
          extraLabels: ["area:work"]
        ),
        presentationIssue(
          number: 3,
          title: "Prepare work notes",
          status: .inbox,
          priority: "priority:p1",
          extraLabels: ["area:work"]
        ),
      ],
      searchText: "book",
      filterSelection: selection
    )

    #expect(sections.first?.issues.map(\.number) == [1])
    #expect(sections.reduce(0) { $0 + $1.issues.count } == 1)
  }
}

private func presentationIssue(
  number: Int,
  title: String = "Task",
  status: TaskStatusSection,
  priority: String? = "priority:p2",
  extraLabels: [String] = [],
  updatedAt: Date = Date(timeIntervalSince1970: 100)
) -> LifeOSIssue {
  var labels = [GitHubLabel(name: status.labelName, color: "ffffff")]
  if let priority {
    labels.append(GitHubLabel(name: priority, color: "000000"))
  }
  labels.append(contentsOf: extraLabels.map { GitHubLabel(name: $0, color: "111111") })
  return LifeOSIssue(
    number: number,
    title: title,
    body: "",
    labels: labels,
    updatedAt: updatedAt
  )
}
