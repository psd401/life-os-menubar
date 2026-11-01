import AppKit
import LifeOSMenubarCore
import SwiftUI

struct PanelView: View {
  @ObservedObject var settingsViewModel: SettingsViewModel
  @ObservedObject var taskListViewModel: TaskListViewModel
  @ObservedObject var quickAddViewModel: QuickCaptureViewModel
  @State private var selectedIssue: LifeOSIssue?
  @State private var listMode = PanelListMode.all
  let openSettings: () -> Void
  let quit: () -> Void

  var body: some View {
    Group {
      if let selectedIssue {
        TaskDetailView(
          issue: selectedIssue,
          token: settingsViewModel.token,
          availableLabels: taskListViewModel.issues.flatMap(\.labels),
          onBack: {
            self.selectedIssue = nil
          },
          onIssueUpdated: { updatedIssue in
            taskListViewModel.reconcileRemoteIssue(updatedIssue)
            if updatedIssue.state == .open {
              self.selectedIssue = updatedIssue
            }
          }
        )
      } else {
        taskList
      }
    }
  }

  private var taskList: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "checkmark.circle")
          .accessibilityHidden(true)
        Text("Life OS")
          .font(.headline)
        Spacer()
        if taskListViewModel.isRefreshing {
          ProgressView()
            .controlSize(.small)
            .accessibilityLabel("Refreshing tasks")
        }
      }

      QuickAddComposerView(
        viewModel: quickAddViewModel,
        token: settingsViewModel.token,
        onCreated: { createdIssue in
          taskListViewModel.reconcileRemoteIssue(createdIssue)
        }
      )

      Picker("Task view", selection: $listMode) {
        Text("All").tag(PanelListMode.all)
        Text("Today (\(taskListViewModel.todayCount))").tag(PanelListMode.today)
      }
      .pickerStyle(.segmented)

      TextField("Search tasks", text: $taskListViewModel.searchText)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("Search tasks by title")

      FilterControlsView(viewModel: taskListViewModel)

      if let errorMessage = taskListViewModel.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Refresh error: \(errorMessage)")
      }

      if let filterErrorMessage = taskListViewModel.filterErrorMessage {
        Label(filterErrorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Filter error: \(filterErrorMessage)")
      }

      if let projectFieldMessage = taskListViewModel.projectFieldMessage {
        Label(projectFieldMessage, systemImage: "calendar.badge.exclamationmark")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Project date warning: \(projectFieldMessage)")
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          if listMode == .today {
            TodayTaskSectionView(
              issues: taskListViewModel.todayIssues,
              selectIssue: { issue in
                selectedIssue = issue
              }
            )
          } else {
            ForEach(taskListViewModel.sections) { section in
              TaskSectionView(
                section: section,
                selectIssue: { issue in
                  selectedIssue = issue
                }
              )
            }
          }
        }
        .padding(.vertical, 2)
      }
      .frame(maxHeight: .infinity)

      Divider()

      footer
    }
    .padding(16)
    .frame(width: 460, height: 620)
  }

  private var footer: some View {
    HStack(spacing: 12) {
      Button {
        Task {
          await taskListViewModel.refresh(token: settingsViewModel.token)
        }
      } label: {
        Label("Refresh", systemImage: "arrow.clockwise")
      }
      .disabled(taskListViewModel.isRefreshing)

      if let lastSyncedAt = taskListViewModel.lastSyncedAt {
        Text("Updated \(lastSyncedAt, style: .relative)")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text("Not synced")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
      Menu {
        Button("Settings…", action: openSettings)
        Divider()
        Button("Quit", action: quit)
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .accessibilityLabel("More options")
    }
  }
}

private enum PanelListMode: String, CaseIterable {
  case all
  case today
}

/// Inline quick-add pinned above the scrolling task list.
///
/// Title-only by design: it leaves `body` and `priority` on the view model
/// untouched so every task it creates carries the Agent Operating Contract
/// defaults (`status:inbox`, `type:task`, `source:manual`, `priority:p2`). The
/// capture window remains the place to override priority or add notes.
private struct QuickAddComposerView: View {
  @ObservedObject var viewModel: QuickCaptureViewModel
  @FocusState private var isTitleFocused: Bool

  let token: String
  let onCreated: (LifeOSIssue) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        TextField("Add a task", text: $viewModel.title)
          .textFieldStyle(.roundedBorder)
          .focused($isTitleFocused)
          .onSubmit(submit)
          .disabled(viewModel.isSubmitting)
          .accessibilityLabel("New task title")

        if viewModel.isSubmitting {
          ProgressView()
            .controlSize(.small)
            .accessibilityLabel("Adding task")
        }

        Button("Add task", action: submit)
          .disabled(!viewModel.canSubmit)
          .accessibilityLabel("Add task to Inbox")
      }

      if let errorMessage = viewModel.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Add task error: \(errorMessage)")
      }
    }
    .onAppear {
      isTitleFocused = true
    }
    // NSPopover reuses one hosting controller, so `onAppear` is not a reliable
    // panel-open signal; the counter the panel bumps on open is.
    .onChange(of: viewModel.titleFocusRequest) {
      isTitleFocused = true
    }
  }

  private func submit() {
    guard viewModel.canSubmit else {
      return
    }
    Task {
      if let createdIssue = await viewModel.submit(token: token) {
        onCreated(createdIssue)
      }
      // Keep the caret in the field either way: ready for the next task on
      // success, and on the retained text after a failure.
      isTitleFocused = true
    }
  }
}

private struct FilterControlsView: View {
  @ObservedObject var viewModel: TaskListViewModel
  @State private var isExpanded = false
  @State private var savedFilterName = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Button {
          withAnimation {
            isExpanded.toggle()
          }
        } label: {
          HStack(spacing: 5) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
              .font(.caption)
            Text("Filters")
            if viewModel.activeFilterCount > 0 {
              Text("\(viewModel.activeFilterCount)")
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
            }
          }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse filters" : "Expand filters")

        Spacer()

        savedFiltersMenu

        Button("Clear") {
          viewModel.clearFilters()
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.activeFilter.isEmpty)
        .accessibilityLabel("Clear all filters")
      }

      if isExpanded {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(TaskFilterFamily.allCases) { family in
              FilterFamilyRow(
                family: family,
                labels: viewModel.availableFilterLabels(for: family),
                isSelected: { labelName in
                  viewModel.isFilterSelected(labelName: labelName, in: family)
                },
                toggle: { labelName in
                  viewModel.toggleFilter(labelName: labelName, in: family)
                }
              )
            }
          }
        }
        .frame(maxHeight: 220)

        HStack {
          TextField("Saved filter name", text: $savedFilterName)
            .textFieldStyle(.roundedBorder)
            .onSubmit(saveCurrentFilter)

          Button("Save", action: saveCurrentFilter)
            .disabled(
              savedFilterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
      }
    }
  }

  private var savedFiltersMenu: some View {
    Menu {
      if viewModel.savedFilters.isEmpty {
        Text("No saved filters")
      } else {
        ForEach(viewModel.savedFilters) { savedFilter in
          Menu(savedFilter.name) {
            Button("Apply") {
              viewModel.applySavedFilter(id: savedFilter.id)
            }
            Button("Delete", role: .destructive) {
              viewModel.deleteSavedFilter(id: savedFilter.id)
            }
          }
        }
      }
    } label: {
      Label("Saved", systemImage: "bookmark")
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .accessibilityLabel("Saved filters")
  }

  private func saveCurrentFilter() {
    if viewModel.saveCurrentFilter(named: savedFilterName) {
      savedFilterName = ""
    }
  }
}

private struct FilterFamilyRow: View {
  let family: TaskFilterFamily
  let labels: [GitHubLabel]
  let isSelected: (String) -> Bool
  let toggle: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(family.title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      if labels.isEmpty {
        Text("No labels in cache")
          .font(.caption)
          .foregroundStyle(.tertiary)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(labels, id: \.name) { label in
              FilterChip(
                label: String(label.name.dropFirst(family.labelPrefix.count)),
                fullLabelName: label.name,
                isSelected: isSelected(label.name),
                action: {
                  toggle(label.name)
                }
              )
            }
          }
        }
      }
    }
  }
}

private struct FilterChip: View {
  let label: String
  let fullLabelName: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
          isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
          in: Capsule()
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(fullLabelName)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private struct TaskSectionView: View {
  let section: TaskSectionSnapshot
  let selectIssue: (LifeOSIssue) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(section.status.title)
          .font(.subheadline.weight(.semibold))
        Text("\(section.issues.count)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        Spacer()
      }

      if section.issues.isEmpty {
        Text("No tasks")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .padding(.leading, 2)
      } else {
        ForEach(section.issues) { issue in
          TaskRow(
            issue: issue,
            action: {
              selectIssue(issue)
            }
          )
        }
      }
    }
  }
}

private struct TodayTaskSectionView: View {
  let issues: [LifeOSIssue]
  let selectIssue: (LifeOSIssue) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Due Today & Overdue")
          .font(.subheadline.weight(.semibold))
        Text("\(issues.count)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        Spacer()
      }

      if issues.isEmpty {
        Text("No tasks due today")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .padding(.leading, 2)
      } else {
        ForEach(issues) { issue in
          TaskRow(
            issue: issue,
            action: {
              selectIssue(issue)
            }
          )
        }
      }
    }
  }
}

private struct TaskRow: View {
  let issue: LifeOSIssue
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("#\(issue.number)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.tertiary)
          .frame(minWidth: 42, alignment: .trailing)

        Text(issue.title)
          .font(.callout)
          .lineLimit(2)

        Spacer(minLength: 4)

        if let dueDate = issue.dueDate {
          Text(dueDate.githubDate)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }

        if let priority = issue.labels.first(where: { $0.name.hasPrefix("priority:") }) {
          Text(priority.name.replacingOccurrences(of: "priority:", with: "").uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }

        Image(systemName: "chevron.right")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
    .accessibilityLabel("Open task #\(issue.number): \(issue.title)")
    .padding(.vertical, 2)
  }
}
