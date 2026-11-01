import LifeOSMenubarCore
import NexusKit
import SwiftUI

struct TaskDetailView: View {
  @StateObject private var viewModel: TaskDetailViewModel
  @Environment(\.nexus) private var palette
  @State private var showsCloseConfirmation = false

  let token: String
  let availableLabels: [GitHubLabel]
  let onBack: () -> Void
  let onIssueUpdated: (LifeOSIssue) -> Void

  init(
    issue: LifeOSIssue,
    token: String,
    availableLabels: [GitHubLabel],
    detailClient: any GitHubIssueDetailFetching = GitHubGraphQLIssueDetailClient(),
    mutationClient: any GitHubIssueMutating = GitHubRESTIssueClient(),
    onBack: @escaping () -> Void,
    onIssueUpdated: @escaping (LifeOSIssue) -> Void
  ) {
    _viewModel = StateObject(
      wrappedValue: TaskDetailViewModel(
        issue: issue,
        detailClient: detailClient,
        mutationClient: mutationClient
      )
    )
    self.token = token
    self.availableLabels = availableLabels
    self.onBack = onBack
    self.onIssueUpdated = onIssueUpdated
  }

  var body: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s3) {
      header

      errorBanner

      ScrollView {
        LazyVStack(alignment: .leading, spacing: NexusSpace.s5) {
          actions
          labels
          bodySection
          commentsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, NexusSpace.s0_5)
      }

      commentComposer
    }
    .padding(NexusSpace.s4)
    .frame(width: PanelMetrics.width, height: PanelMetrics.height)
    .task {
      await loadDetail()
    }
    .confirmationDialog(
      "Close #\(viewModel.issue.number)?",
      isPresented: $showsCloseConfirmation,
      titleVisibility: .visible
    ) {
      Button("Mark task done and close it", role: .destructive) {
        Task {
          if let updatedIssue = await viewModel.close(token: token) {
            onIssueUpdated(updatedIssue)
            onBack()
          }
        }
      }
      Button("Keep task open", role: .cancel) {}
    } message: {
      Text("This replaces the current status with status:done and closes the issue on GitHub.")
    }
  }

  @ViewBuilder
  private var errorBanner: some View {
    if let errorMessage = viewModel.errorMessage {
      HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s2) {
        HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s2) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: NexusSize.iconSm, weight: .regular))
            .accessibilityHidden(true)
          Text(errorMessage)
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(NexusFont.caption1)
        .foregroundStyle(palette.warningInk)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Task error: \(errorMessage)")

        Spacer()

        if !viewModel.hasLoadedDetail {
          Button("Retry loading") {
            Task {
              await loadDetail()
            }
          }
          .buttonStyle(.bordered)
          .disabled(viewModel.isLoading)
          .controlSize(.small)
          .accessibilityLabel("Retry loading task details")
        }
      }
      .padding(.horizontal, NexusSpace.s3)
      .padding(.vertical, NexusSpace.s2)
      .background(palette.warningSoft, in: RoundedRectangle(cornerRadius: NexusRadius.sm))
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s2) {
      HStack {
        Button(action: onBack) {
          Label("Back to tasks", systemImage: "chevron.left")
            .font(NexusFont.body)
            .foregroundStyle(palette.ink)
        }
        .buttonStyle(.plain)

        Spacer()

        if viewModel.isLoading || viewModel.isMutating {
          ProgressView()
            .controlSize(.small)
            .accessibilityLabel(viewModel.isLoading ? "Loading task" : "Updating task")
        }
      }
      .padding(.horizontal, NexusSpace.s3)
      .padding(.vertical, NexusSpace.s2)
      .nexusChrome(in: RoundedRectangle(cornerRadius: NexusRadius.md))

      Text("#\(viewModel.issue.number)")
        .font(NexusFont.code)
        .foregroundStyle(palette.inkMuted)
      Text(viewModel.issue.title)
        .font(NexusFont.title1)
        .foregroundStyle(palette.ink)
        .textSelection(.enabled)
    }
  }

  private var actions: some View {
    HStack(spacing: NexusSpace.s2) {
      Menu {
        ForEach(TaskStatusSection.allCases) { status in
          Button {
            Task {
              if let updatedIssue = await viewModel.changeStatus(
                token: token,
                to: status.labelName
              ) {
                onIssueUpdated(updatedIssue)
              }
            }
          } label: {
            if currentStatus == status.labelName {
              Label(status.title, systemImage: "checkmark")
            } else {
              Text(status.title)
            }
          }
        }
      } label: {
        Label(statusTitle, systemImage: "arrow.triangle.2.circlepath")
          .font(NexusFont.body)
      }
      .disabled(viewModel.isMutating || !viewModel.hasLoadedDetail)
      .accessibilityLabel("Change status. Current status: \(statusTitle)")

      Menu {
        ForEach(priorityChoices, id: \.self) { priority in
          Button {
            Task {
              if let updatedIssue = await viewModel.changePriority(
                token: token,
                to: priority
              ) {
                onIssueUpdated(updatedIssue)
              }
            }
          } label: {
            if currentPriority == priority {
              Label(priorityTitle(priority), systemImage: "checkmark")
            } else {
              Text(priorityTitle(priority))
            }
          }
        }
      } label: {
        Label(priorityTitle(currentPriority), systemImage: "flag")
          .font(NexusFont.body)
      }
      .disabled(viewModel.isMutating || !viewModel.hasLoadedDetail)
      .accessibilityLabel("Change priority. Current priority: \(priorityTitle(currentPriority))")

      Menu {
        if nonContractLabels.isEmpty {
          Text("No labels in cache")
        } else {
          ForEach(nonContractLabels, id: \.name) { label in
            Button {
              Task {
                let isSelected = !viewModel.issue.labels.contains { $0.name == label.name }
                if let updatedIssue = await viewModel.setNonContractLabel(
                  token: token,
                  label: label.name,
                  isSelected: isSelected
                ) {
                  onIssueUpdated(updatedIssue)
                }
              }
            } label: {
              if viewModel.issue.labels.contains(where: { $0.name == label.name }) {
                Label(label.name, systemImage: "checkmark")
              } else {
                Text(label.name)
              }
            }
          }
        }
      } label: {
        Label("Edit labels", systemImage: "tag")
          .font(NexusFont.body)
      }
      .disabled(viewModel.isMutating || !viewModel.hasLoadedDetail)
      .accessibilityLabel("Edit non-contract labels")

      Spacer()

      Button("Close task", role: .destructive) {
        showsCloseConfirmation = true
      }
      .buttonStyle(.bordered)
      .disabled(
        viewModel.isMutating || !viewModel.hasLoadedDetail || viewModel.issue.state == .closed
      )
      .accessibilityLabel("Mark task done and close")
    }
    .controlSize(.small)
  }

  private var labels: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s2) {
      Text("Labels")
        .font(NexusFont.headline)
        .foregroundStyle(palette.ink)

      ForEach(labelGroups) { group in
        VStack(alignment: .leading, spacing: NexusSpace.s1) {
          Text(group.title)
            .font(NexusFont.caption2)
            .foregroundStyle(palette.inkMuted)
          FlowLabelView(labels: group.labels)
        }
      }
    }
  }

  private var bodySection: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s2) {
      Text("Details")
        .font(NexusFont.headline)
        .foregroundStyle(palette.ink)

      if viewModel.issue.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text("No description")
          .font(NexusFont.body)
          .foregroundStyle(palette.inkMuted)
      } else {
        MarkdownBlockView(markdown: viewModel.issue.body)
      }
    }
  }

  private var commentsSection: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s3) {
      Text("Comments (\(viewModel.comments.count))")
        .font(NexusFont.headline)
        .foregroundStyle(palette.ink)

      if viewModel.comments.isEmpty {
        Text(viewModel.isLoading ? "Loading comments…" : "No comments")
          .font(NexusFont.body)
          .foregroundStyle(palette.inkMuted)
      } else {
        ForEach(viewModel.comments) { comment in
          VStack(alignment: .leading, spacing: NexusSpace.s1) {
            HStack {
              Text("@\(comment.authorLogin)")
                .font(NexusFont.caption2)
                .foregroundStyle(palette.ink)
              Spacer()
              Text(
                comment.createdAt,
                format: .dateTime.year().month().day().hour().minute()
              )
              .font(NexusFont.caption1)
              .foregroundStyle(palette.inkMuted)
            }
            MarkdownBlockView(markdown: comment.body, compact: true)
          }
          .padding(NexusSpace.s3)
          .background(
            palette.surfaceRaised,
            in: RoundedRectangle(cornerRadius: NexusRadius.sm)
          )
          .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.sm)
              .stroke(palette.line, lineWidth: 1)
          )
        }
      }
    }
  }

  private var commentComposer: some View {
    VStack(alignment: .trailing, spacing: NexusSpace.s2) {
      TextEditor(text: $viewModel.commentDraft)
        .font(NexusFont.body)
        .scrollContentBackground(.hidden)
        .frame(minHeight: NexusSize.controlLg, maxHeight: NexusSize.headerHeight + NexusSpace.s5)
        .padding(NexusSpace.s1)
        .background(
          palette.surfaceRaised,
          in: RoundedRectangle(cornerRadius: NexusRadius.sm)
        )
        .overlay(
          RoundedRectangle(cornerRadius: NexusRadius.sm)
            .stroke(palette.line, lineWidth: 1)
        )
        .accessibilityLabel("New comment")

      Button("Post comment") {
        Task {
          _ = await viewModel.addComment(token: token)
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(palette.action)
      .disabled(
        viewModel.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          || viewModel.isMutating
          || !viewModel.hasLoadedDetail
      )
      .keyboardShortcut(.return, modifiers: [.command])
    }
  }

  private var currentStatus: String? {
    viewModel.issue.labels.first {
      ContractLabelFamily.status.contains($0.name)
    }?.name
  }

  private var currentPriority: String? {
    viewModel.issue.labels.first {
      ContractLabelFamily.priority.contains($0.name)
    }?.name
  }

  private var statusTitle: String {
    guard let currentStatus else {
      return "Status"
    }
    return String(currentStatus.dropFirst(ContractLabelFamily.status.prefix.count)).capitalized
  }

  private var priorityChoices: [String] {
    var choices = Set(
      availableLabels
        .map(\.name)
        .filter(ContractLabelFamily.priority.contains)
    )
    choices.formUnion((0...4).map { "priority:p\($0)" })
    if let currentPriority {
      choices.insert(currentPriority)
    }
    return choices.sorted()
  }

  private func priorityTitle(_ priority: String?) -> String {
    guard let priority else {
      return "Priority"
    }
    return String(priority.dropFirst(ContractLabelFamily.priority.prefix.count)).uppercased()
  }

  private var nonContractLabels: [GitHubLabel] {
    var labelsByName: [String: GitHubLabel] = [:]
    for label in availableLabels + viewModel.issue.labels
    where LabelRules.family(for: label.name) == nil {
      labelsByName[label.name] = label
    }
    return labelsByName.values.sorted {
      $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }

  private var labelGroups: [DetailLabelGroup] {
    let grouped = Dictionary(grouping: viewModel.issue.labels) { label in
      label.name.split(separator: ":", maxSplits: 1).first.map(String.init) ?? "other"
    }
    return grouped.map { family, labels in
      DetailLabelGroup(
        title: family.capitalized,
        labels: labels.sorted {
          $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
      )
    }
    .sorted {
      $0.title.localizedStandardCompare($1.title) == .orderedAscending
    }
  }

  private func loadDetail() async {
    await viewModel.load(token: token)
    if viewModel.errorMessage == nil {
      onIssueUpdated(viewModel.issue)
    }
  }
}

private struct DetailLabelGroup: Identifiable {
  let title: String
  let labels: [GitHubLabel]

  var id: String {
    title
  }
}

private struct FlowLabelView: View {
  let labels: [GitHubLabel]

  var body: some View {
    // `NexusFlowLayout` wraps between badges but measures each one at its ideal
    // width (`sizeThatFits(.unspecified)`), so a single label longer than the
    // panel is placed at that width and clipped rather than wrapped. A GitHub
    // label has no length limit this app controls, so the flow layout is used
    // only while every badge fits; past that, the vertical fallback gives each
    // badge the full width and lets its text wrap, which is what this view did
    // before the Nexus pass.
    ViewThatFits(in: .horizontal) {
      NexusFlowLayout(spacing: NexusSpace.s1) {
        badges
      }
      VStack(alignment: .leading, spacing: NexusSpace.s1) {
        badges
      }
    }
  }

  @ViewBuilder
  private var badges: some View {
    ForEach(labels, id: \.name) { label in
      NexusBadge(label.name, tone: label.name.nexusLabelTone)
    }
  }
}

extension String {
  /// Contract labels carry their Nexus semantics: `attention` for the Inbox
  /// (needs a decision), `flow` for work in flight, `info` for what is lined
  /// up. Everything else is neutral — the label text is always the word.
  fileprivate var nexusLabelTone: NexusBadge.Tone {
    switch self {
    case "status:inbox":
      return .attention
    case "status:active":
      return .flow
    case "status:next", "status:scheduled":
      return .info
    default:
      return .neutral
    }
  }
}

private struct MarkdownBlockView: View {
  let markdown: String
  var compact = false

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? NexusSpace.s1 : NexusSpace.s2) {
      ForEach(Array(markdown.components(separatedBy: .newlines).enumerated()), id: \.offset) {
        line in
        block(for: line.element)
      }
    }
    .textSelection(.enabled)
  }

  @ViewBuilder
  private func block(for line: String) -> some View {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty {
      Spacer()
        .frame(height: compact ? NexusSpace.s0_5 : NexusSpace.s1)
    } else if trimmed.hasPrefix("### ") {
      Text(inlineMarkdown(String(trimmed.dropFirst(4))))
        .font(NexusFont.headline)
    } else if trimmed.hasPrefix("## ") {
      Text(inlineMarkdown(String(trimmed.dropFirst(3))))
        .font(NexusFont.title3)
    } else if trimmed.hasPrefix("# ") {
      Text(inlineMarkdown(String(trimmed.dropFirst(2))))
        .font(NexusFont.title2)
    } else if let checklist = checklistItem(from: trimmed) {
      HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s2) {
        Image(systemName: checklist.isChecked ? "checkmark.square" : "square")
          .font(.system(size: NexusSize.iconSm, weight: .regular))
          .accessibilityLabel(checklist.isChecked ? "Completed" : "Not completed")
        Text(inlineMarkdown(checklist.text))
          .font(NexusFont.body)
      }
    } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
      HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s2) {
        Text("•")
          .font(NexusFont.body)
        Text(inlineMarkdown(String(trimmed.dropFirst(2))))
          .font(NexusFont.body)
      }
    } else if let orderedItem = MarkdownLineParser.orderedListItem(from: trimmed) {
      HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s2) {
        Text(orderedItem.marker)
          .font(NexusFont.code)
        Text(inlineMarkdown(orderedItem.text))
          .font(NexusFont.body)
      }
    } else {
      Text(inlineMarkdown(trimmed))
        .font(NexusFont.body)
    }
  }

  private func inlineMarkdown(_ source: String) -> AttributedString {
    (try? AttributedString(
      markdown: source,
      options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
    )) ?? AttributedString(source)
  }

  private func checklistItem(from line: String) -> (isChecked: Bool, text: String)? {
    let prefixes = [
      ("- [ ] ", false),
      ("* [ ] ", false),
      ("- [x] ", true),
      ("* [x] ", true),
      ("- [X] ", true),
      ("* [X] ", true),
    ]
    guard let match = prefixes.first(where: { line.hasPrefix($0.0) }) else {
      return nil
    }
    return (match.1, String(line.dropFirst(match.0.count)))
  }

}
