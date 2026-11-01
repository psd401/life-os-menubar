import Foundation

public enum ContractLabelFamily: String, Sendable {
  case status
  case priority

  public var prefix: String {
    "\(rawValue):"
  }

  public func contains(_ labelName: String) -> Bool {
    labelName.hasPrefix(prefix) && labelName.count > prefix.count
  }
}

public enum LabelRulesError: LocalizedError, Equatable, Sendable {
  case invalidStatusLabel(String)
  case invalidPriorityLabel(String)
  case contractLabelRequiresDedicatedControl(String)
  case emptyLabel

  public var errorDescription: String? {
    switch self {
    case .invalidStatusLabel(let label):
      "\"\(label)\" is not a status label."
    case .invalidPriorityLabel(let label):
      "\"\(label)\" is not a priority label."
    case .contractLabelRequiresDedicatedControl(let label):
      "\"\(label)\" must be changed with the status or priority control."
    case .emptyLabel:
      "A label name cannot be empty."
    }
  }
}

public enum LabelRules {
  public static let defaultStatus = "status:inbox"
  public static let defaultPriority = "priority:p2"

  /// The label definitions a task repo must already contain for the app to
  /// work. `LabelRules` repairs a *missing contract label on a task*, but
  /// nothing here creates the label definitions in the repo — that is the
  /// bootstrap step in `docs/life-os-repo-standard.md`, and
  /// `TaskRepositoryValidator` is what checks it was done.
  ///
  /// Derived from `TaskStatusSection` so the panel's sections and this list
  /// cannot drift apart. `status:done` is not a section — a done task is
  /// closed, so it never appears in the panel — but closing a task writes it,
  /// so the label has to exist.
  public static let requiredLabelNames: [String] =
    TaskStatusSection.allCases.map(\.labelName)
    + ["status:done"]
    + ["priority:p0", "priority:p1", "priority:p2", "priority:p3"]
    + ["type:task", "source:manual"]

  public static func family(for labelName: String) -> ContractLabelFamily? {
    ContractLabelFamily.allCases.first { $0.contains(labelName) }
  }

  public static func changingStatus(
    in labels: [String],
    to status: String
  ) throws -> [String] {
    guard ContractLabelFamily.status.contains(status) else {
      throw LabelRulesError.invalidStatusLabel(status)
    }
    return normalized(labels, status: status, priority: nil)
  }

  public static func changingPriority(
    in labels: [String],
    to priority: String
  ) throws -> [String] {
    guard ContractLabelFamily.priority.contains(priority) else {
      throw LabelRulesError.invalidPriorityLabel(priority)
    }
    return normalized(labels, status: nil, priority: priority)
  }

  public static func editingNonContractLabel(
    in labels: [String],
    label: String,
    isSelected: Bool
  ) throws -> [String] {
    let candidate = label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else {
      throw LabelRulesError.emptyLabel
    }
    guard family(for: candidate) == nil else {
      throw LabelRulesError.contractLabelRequiresDedicatedControl(candidate)
    }

    var editedLabels = labels
    if isSelected {
      if !editedLabels.contains(candidate) {
        editedLabels.append(candidate)
      }
    } else {
      editedLabels.removeAll { $0 == candidate }
    }
    return normalized(editedLabels, status: nil, priority: nil)
  }

  private static func normalized(
    _ labels: [String],
    status statusOverride: String?,
    priority priorityOverride: String?
  ) -> [String] {
    let status =
      statusOverride
      ?? labels.first(where: ContractLabelFamily.status.contains)
      ?? defaultStatus
    let priority =
      priorityOverride
      ?? labels.first(where: ContractLabelFamily.priority.contains)
      ?? defaultPriority

    var result: [String] = []
    var insertedStatus = false
    var insertedPriority = false

    for label in labels {
      if ContractLabelFamily.status.contains(label) {
        if !insertedStatus {
          result.append(status)
          insertedStatus = true
        }
      } else if ContractLabelFamily.priority.contains(label) {
        if !insertedPriority {
          result.append(priority)
          insertedPriority = true
        }
      } else {
        result.append(label)
      }
    }

    if !insertedStatus {
      result.append(status)
    }
    if !insertedPriority {
      result.append(priority)
    }
    return result
  }
}

extension ContractLabelFamily: CaseIterable {}
