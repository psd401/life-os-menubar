import Foundation

public enum TaskFilterFamily: String, CaseIterable, Codable, Identifiable, Sendable {
  case status
  case priority
  case area
  case context
  case person
  case energy
  case estimate
  case type

  public var id: String {
    rawValue
  }

  public var title: String {
    rawValue.capitalized
  }

  public var labelPrefix: String {
    "\(rawValue):"
  }

  public func contains(labelName: String) -> Bool {
    labelName.hasPrefix(labelPrefix) && labelName.count > labelPrefix.count
  }

  public static func family(for labelName: String) -> TaskFilterFamily? {
    allCases.first { $0.contains(labelName: labelName) }
  }
}

public struct TaskFilterSelection: Codable, Equatable, Sendable {
  public static let empty = TaskFilterSelection()

  private var labelsByFamily: [TaskFilterFamily: Set<String>]

  public init(labelsByFamily: [TaskFilterFamily: Set<String>] = [:]) {
    self.labelsByFamily = labelsByFamily.reduce(into: [:]) { result, entry in
      let validLabels = entry.value.filter { entry.key.contains(labelName: $0) }
      if !validLabels.isEmpty {
        result[entry.key] = validLabels
      }
    }
  }

  public var isEmpty: Bool {
    labelsByFamily.isEmpty
  }

  public var selectedLabelCount: Int {
    labelsByFamily.values.reduce(0) { $0 + $1.count }
  }

  public var selectedFamilies: [TaskFilterFamily] {
    TaskFilterFamily.allCases.filter { labelsByFamily[$0] != nil }
  }

  public func selectedLabels(for family: TaskFilterFamily) -> Set<String> {
    labelsByFamily[family] ?? []
  }

  public func contains(labelName: String, in family: TaskFilterFamily) -> Bool {
    labelsByFamily[family]?.contains(labelName) == true
  }

  public mutating func toggle(labelName: String, in family: TaskFilterFamily) {
    guard family.contains(labelName: labelName) else {
      return
    }

    var selectedLabels = labelsByFamily[family] ?? []
    if selectedLabels.remove(labelName) == nil {
      selectedLabels.insert(labelName)
    }

    if selectedLabels.isEmpty {
      labelsByFamily.removeValue(forKey: family)
    } else {
      labelsByFamily[family] = selectedLabels
    }
  }
}

public enum TaskFilterPredicate {
  public static func matches(
    issue: LifeOSIssue,
    selection: TaskFilterSelection
  ) -> Bool {
    selection.selectedFamilies.allSatisfy { family in
      let selectedLabels = selection.selectedLabels(for: family)
      return issue.labels.contains { selectedLabels.contains($0.name) }
    }
  }

  public static func availableLabels(
    in issues: [LifeOSIssue]
  ) -> [TaskFilterFamily: [GitHubLabel]] {
    var labelsByFamily: [TaskFilterFamily: [String: GitHubLabel]] = [:]

    for label in issues.flatMap(\.labels) {
      guard let family = TaskFilterFamily.family(for: label.name) else {
        continue
      }
      labelsByFamily[family, default: [:]][label.name] = label
    }

    return labelsByFamily.mapValues { labelsByName in
      labelsByName.values.sorted {
        $0.name.localizedStandardCompare($1.name) == .orderedAscending
      }
    }
  }
}
