import Foundation
import Testing

@testable import LifeOSMenubarCore

struct TaskFilterTests {
  @Test
  func orsLabelsWithinAFamilyAndAndsAcrossFamilies() {
    let selection = TaskFilterSelection(
      labelsByFamily: [
        .area: ["area:work", "area:personal"],
        .priority: ["priority:p1"],
      ]
    )
    let issues = [
      filterIssue(number: 1, labels: ["area:work", "priority:p1"]),
      filterIssue(number: 2, labels: ["area:personal", "priority:p1"]),
      filterIssue(number: 3, labels: ["area:work", "priority:p2"]),
      filterIssue(number: 4, labels: ["priority:p1"]),
    ]

    let matchingNumbers = issues.filter {
      TaskFilterPredicate.matches(issue: $0, selection: selection)
    }.map(\.number)

    #expect(matchingNumbers == [1, 2])
  }

  @Test
  func emptySelectionMatchesEveryIssue() {
    let issue = filterIssue(number: 1, labels: [])

    #expect(TaskFilterPredicate.matches(issue: issue, selection: .empty))
  }

  @Test
  func availableLabelsAreDerivedFromCachedIssuesAndLimitedToSupportedFamilies() {
    let issues = [
      filterIssue(
        number: 1,
        labels: ["area:work", "person:alex", "source:manual"]
      ),
      filterIssue(
        number: 2,
        labels: ["area:work", "area:home", "priority:p2"]
      ),
    ]

    let labels = TaskFilterPredicate.availableLabels(in: issues)

    #expect(labels[.area]?.map(\.name) == ["area:home", "area:work"])
    #expect(labels[.person]?.map(\.name) == ["person:alex"])
    #expect(labels[.priority]?.map(\.name) == ["priority:p2"])
    #expect(labels[.status] == nil)
    #expect(labels.values.flatMap { $0 }.contains { $0.name == "source:manual" } == false)
  }

  @Test
  func toggleMaintainsNormalizedSelectionsAndSelectedCount() {
    var selection = TaskFilterSelection(
      labelsByFamily: [
        .area: ["area:work", "priority:p1"]
      ]
    )

    #expect(selection.selectedLabels(for: .area) == ["area:work"])
    #expect(selection.selectedLabelCount == 1)

    selection.toggle(labelName: "area:home", in: .area)
    #expect(selection.selectedLabels(for: .area) == ["area:home", "area:work"])
    #expect(selection.selectedLabelCount == 2)

    selection.toggle(labelName: "area:work", in: .area)
    selection.toggle(labelName: "area:home", in: .area)
    #expect(selection == .empty)
  }
}

private func filterIssue(number: Int, labels: [String]) -> LifeOSIssue {
  LifeOSIssue(
    number: number,
    title: "Task \(number)",
    body: "",
    labels: labels.map { GitHubLabel(name: $0, color: "ffffff") },
    updatedAt: Date(timeIntervalSince1970: 1_785_000_000)
  )
}
