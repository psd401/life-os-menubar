import LifeOSMenubarCore
import SwiftUI

struct TaskDetailView: View {
  @StateObject private var viewModel: TaskDetailViewModel
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
    VStack(alignment: .leading, spacing: 12) {
      header

      errorBanner

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 18) {
          actions
          labels
          bodySection
          commentsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
      }

      Divider()
      commentComposer
    }
    .padding(16)
    .frame(width: 460, height: 620)
    .task {
      await loadDetail()
    }
    .confirmationDialog(
      "Close #\(viewModel.issue.number)?",
      isPresented: $showsCloseConfirmation,
      titleVisibility: .visible
    ) {
      Button("Mark done and close", role: .destructive) {
        Task {
          if let updatedIssue = await viewModel.close(token: token) {
            onIssueUpdated(updatedIssue)
            onBack()
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This replaces the current status with status:done and closes the issue on GitHub.")
    }
  }

  @ViewBuilder
  private var errorBanner: some View {
    if let errorMessage = viewModel.errorMessage {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Task error: \(errorMessage)")

        Spacer()

        if !viewModel.hasLoadedDetail {
          Button("Retry") {
            Task {
              await loadDetail()
            }
          }
          .disabled(viewModel.isLoading)
          .controlSize(.small)
          .accessibilityLabel("Retry loading task details")
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Button(action: onBack) {
          Label("Tasks", systemImage: "chevron.left")
        }
        .buttonStyle(.plain)

        Spacer()

        if viewModel.isLoading || viewModel.isMutating {
          ProgressView()
            .controlSize(.small)
            .accessibilityLabel(viewModel.isLoading ? "Loading task" : "Updating task")
        }
      }

      Text("#\(viewModel.issue.number)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
      Text(viewModel.issue.title)
        .font(.title3.weight(.semibold))
        .textSelection(.enabled)
    }
  }

  private var actions: some View {
    HStack(spacing: 8) {
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
        Label("Labels", systemImage: "tag")
      }
      .disabled(viewModel.isMutating || !viewModel.hasLoadedDetail)
      .accessibilityLabel("Edit non-contract labels")

      Spacer()

      Button("Close", role: .destructive) {
        showsCloseConfirmation = true
      }
      .disabled(
        viewModel.isMutating || !viewModel.hasLoadedDetail || viewModel.issue.state == .closed
      )
      .accessibilityLabel("Mark task done and close")
    }
    .controlSize(.small)
  }

  private var labels: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Labels")
        .font(.headline)

      ForEach(labelGroups) { group in
        VStack(alignment: .leading, spacing: 4) {
          Text(group.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          FlowLabelView(labels: group.labels)
        }
      }
    }
  }

  private var bodySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Details")
        .font(.headline)

      if viewModel.issue.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text("No description")
          .foregroundStyle(.secondary)
          .italic()
      } else {
        MarkdownBlockView(markdown: viewModel.issue.body)
      }
    }
  }

  private var commentsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Comments (\(viewModel.comments.count))")
        .font(.headline)

      if viewModel.comments.isEmpty {
        Text(viewModel.isLoading ? "Loading comments…" : "No comments")
          .foregroundStyle(.secondary)
      } else {
        ForEach(viewModel.comments) { comment in
          VStack(alignment: .leading, spacing: 5) {
            HStack {
              Text("@\(comment.authorLogin)")
                .font(.caption.weight(.semibold))
              Spacer()
              Text(
                comment.createdAt,
                format: .dateTime.year().month().day().hour().minute()
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
            MarkdownBlockView(markdown: comment.body, compact: true)
          }
          .padding(10)
          .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
  }

  private var commentComposer: some View {
    VStack(alignment: .trailing, spacing: 8) {
      TextEditor(text: $viewModel.commentDraft)
        .font(.body)
        .frame(minHeight: 54, maxHeight: 76)
        .padding(4)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.secondary.opacity(0.35))
        )
        .accessibilityLabel("New comment")

      Button("Post Comment") {
        Task {
          _ = await viewModel.addComment(token: token)
        }
      }
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
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 5) {
        chips
      }
      VStack(alignment: .leading, spacing: 5) {
        chips
      }
    }
  }

  @ViewBuilder
  private var chips: some View {
    ForEach(labels, id: \.name) { label in
      Text(label.name)
        .font(.caption)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.14), in: Capsule())
    }
  }
}

private struct MarkdownBlockView: View {
  let markdown: String
  var compact = false

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 4 : 7) {
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
        .frame(height: compact ? 2 : 5)
    } else if trimmed.hasPrefix("### ") {
      Text(inlineMarkdown(String(trimmed.dropFirst(4))))
        .font(.subheadline.weight(.semibold))
    } else if trimmed.hasPrefix("## ") {
      Text(inlineMarkdown(String(trimmed.dropFirst(3))))
        .font(.headline)
    } else if trimmed.hasPrefix("# ") {
      Text(inlineMarkdown(String(trimmed.dropFirst(2))))
        .font(.title3.weight(.semibold))
    } else if let checklist = checklistItem(from: trimmed) {
      HStack(alignment: .firstTextBaseline, spacing: 7) {
        Image(systemName: checklist.isChecked ? "checkmark.square" : "square")
          .accessibilityLabel(checklist.isChecked ? "Completed" : "Not completed")
        Text(inlineMarkdown(checklist.text))
      }
    } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
      HStack(alignment: .firstTextBaseline, spacing: 7) {
        Text("•")
        Text(inlineMarkdown(String(trimmed.dropFirst(2))))
      }
    } else if let orderedItem = MarkdownLineParser.orderedListItem(from: trimmed) {
      HStack(alignment: .firstTextBaseline, spacing: 7) {
        Text(orderedItem.marker)
          .monospacedDigit()
        Text(inlineMarkdown(orderedItem.text))
      }
    } else {
      Text(inlineMarkdown(trimmed))
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
