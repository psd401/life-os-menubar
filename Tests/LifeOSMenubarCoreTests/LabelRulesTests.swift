import Testing

@testable import LifeOSMenubarCore

struct LabelRulesTests {
  @Test
  func statusSwapRemovesEveryPreviousStatusAndPreservesOtherLabels() throws {
    let labels = try LabelRules.changingStatus(
      in: [
        "area:work",
        "status:next",
        "priority:p1",
        "status:waiting",
        "context:mac",
      ],
      to: "status:active"
    )

    #expect(
      labels
        == [
          "area:work",
          "status:active",
          "priority:p1",
          "context:mac",
        ]
    )
    #expect(labels.filter(ContractLabelFamily.status.contains).count == 1)
    #expect(labels.filter(ContractLabelFamily.priority.contains).count == 1)
  }

  @Test
  func statusSwapRepairsMissingPriorityWithContractDefault() throws {
    let labels = try LabelRules.changingStatus(
      in: ["area:home"],
      to: "status:scheduled"
    )

    #expect(labels == ["area:home", "status:scheduled", "priority:p2"])
  }

  @Test
  func prioritySwapRepairsMissingStatusAndDuplicatePriority() throws {
    let labels = try LabelRules.changingPriority(
      in: ["priority:p3", "source:manual", "priority:p4"],
      to: "priority:p0"
    )

    #expect(labels == ["priority:p0", "source:manual", "status:inbox"])
    #expect(labels.filter(ContractLabelFamily.status.contains).count == 1)
    #expect(labels.filter(ContractLabelFamily.priority.contains).count == 1)
  }

  @Test
  func validSwapToCurrentValueIsAnExactNoOp() throws {
    let labels = ["status:next", "area:work", "priority:p1"]

    #expect(try LabelRules.changingStatus(in: labels, to: "status:next") == labels)
    #expect(try LabelRules.changingPriority(in: labels, to: "priority:p1") == labels)
  }

  @Test
  func nonContractEditorAddsAndRemovesLabelsWhileRepairingContractFamilies() throws {
    let added = try LabelRules.editingNonContractLabel(
      in: ["status:inbox"],
      label: "context:mac",
      isSelected: true
    )
    #expect(added == ["status:inbox", "context:mac", "priority:p2"])

    let removed = try LabelRules.editingNonContractLabel(
      in: added,
      label: "context:mac",
      isSelected: false
    )
    #expect(removed == ["status:inbox", "priority:p2"])
  }

  @Test
  func nonContractEditorRejectsContractLabels() {
    #expect(
      throws: LabelRulesError.contractLabelRequiresDedicatedControl("status:active")
    ) {
      try LabelRules.editingNonContractLabel(
        in: ["status:inbox", "priority:p2"],
        label: "status:active",
        isSelected: true
      )
    }
    #expect(
      throws: LabelRulesError.contractLabelRequiresDedicatedControl("priority:p0")
    ) {
      try LabelRules.editingNonContractLabel(
        in: ["status:inbox", "priority:p2"],
        label: "priority:p0",
        isSelected: true
      )
    }
  }
}
