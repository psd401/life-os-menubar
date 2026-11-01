import AppKit
import LifeOSMenubarCore
import NexusKit
import SwiftUI

struct PanelView: View {
  @ObservedObject var settingsViewModel: SettingsViewModel
  @ObservedObject var taskListViewModel: TaskListViewModel
  @ObservedObject var quickAddViewModel: QuickCaptureViewModel
  @Environment(\.nexus) private var palette
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
    VStack(alignment: .leading, spacing: NexusSpace.s3) {
      header

      QuickAddComposerView(
        viewModel: quickAddViewModel,
        tokenProvider: {
          settingsViewModel.token
        },
        onCreated: { createdIssue in
          taskListViewModel.reconcileRemoteIssue(createdIssue)
        }
      )

      Picker("Task view", selection: $listMode) {
        Text("All").tag(PanelListMode.all)
        Text("Today (\(taskListViewModel.todayCount))").tag(PanelListMode.today)
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      TextField("Search tasks", text: $taskListViewModel.searchText)
        .textFieldStyle(.roundedBorder)
        .font(NexusFont.body)
        .frame(height: NexusSize.macControl)
        .accessibilityLabel("Search tasks by title")

      FilterControlsView(viewModel: taskListViewModel)

      if let errorMessage = taskListViewModel.errorMessage {
        PanelNotice(
          message: errorMessage,
          systemImage: "exclamationmark.triangle",
          accessibilityLabel: "Refresh error: \(errorMessage)"
        )
      }

      if let filterErrorMessage = taskListViewModel.filterErrorMessage {
        PanelNotice(
          message: filterErrorMessage,
          systemImage: "exclamationmark.triangle",
          accessibilityLabel: "Filter error: \(filterErrorMessage)"
        )
      }

      if let projectFieldMessage = taskListViewModel.projectFieldMessage {
        PanelNotice(
          message: projectFieldMessage,
          systemImage: "calendar.badge.exclamationmark",
          accessibilityLabel: "Project date warning: \(projectFieldMessage)"
        )
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: NexusSpace.s4) {
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
        .padding(.vertical, NexusSpace.s0_5)
      }
      .frame(maxHeight: .infinity)

      footer
    }
    .padding(NexusSpace.s4)
    .frame(width: PanelMetrics.width, height: PanelMetrics.height)
  }

  /// Glass chrome at the top of the panel, per the Nexus `MacMenuBarExtra`
  /// pattern: navigation floats as glass, the task list below stays on paper.
  private var header: some View {
    HStack(spacing: NexusSpace.s2) {
      NexusMark()
        .fill(palette.action)
        .frame(width: NexusSize.iconSm, height: NexusSize.iconSm)
        .accessibilityHidden(true)

      Text("Life OS")
        .font(NexusFont.title2)
        .foregroundStyle(palette.ink)

      Spacer()

      if taskListViewModel.isRefreshing {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel("Refreshing tasks")
      }
    }
    .padding(.horizontal, NexusSpace.s3)
    .padding(.vertical, NexusSpace.s2)
    .nexusGlass(in: RoundedRectangle(cornerRadius: NexusRadius.md))
  }

  private var footer: some View {
    HStack(spacing: NexusSpace.s3) {
      Button {
        Task {
          await taskListViewModel.refresh(token: settingsViewModel.token)
        }
      } label: {
        Label("Refresh tasks", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .disabled(taskListViewModel.isRefreshing)

      if let lastSyncedAt = taskListViewModel.lastSyncedAt {
        Text("Updated \(lastSyncedAt, style: .relative)")
          .font(NexusFont.caption1)
          .foregroundStyle(palette.inkMuted)
      } else {
        Text("Not synced")
          .font(NexusFont.caption1)
          .foregroundStyle(palette.inkMuted)
      }

      Spacer()

      Menu {
        Button("Open settings", action: openSettings)
        Divider()
        Button("Quit Life OS", action: quit)
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: NexusSize.iconSm, weight: .regular))
          .foregroundStyle(palette.inkMuted)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .accessibilityLabel("More options")
    }
    .padding(.horizontal, NexusSpace.s3)
    .padding(.vertical, NexusSpace.s2)
    .nexusGlass(in: RoundedRectangle(cornerRadius: NexusRadius.md))
  }
}

private enum PanelListMode: String, CaseIterable {
  case all
  case today
}

/// A warning line inside the panel. The icon and the sentence carry the
/// meaning; the `warning` color only reinforces it, per the Nexus rule that a
/// status color never stands alone.
private struct PanelNotice: View {
  @Environment(\.nexus) private var palette
  let message: String
  let systemImage: String
  let accessibilityLabel: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s2) {
      Image(systemName: systemImage)
        .font(.system(size: NexusSize.iconSm, weight: .regular))
        .accessibilityHidden(true)
      Text(message)
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(NexusFont.caption1)
    .foregroundStyle(palette.warningInk)
    .padding(.horizontal, NexusSpace.s3)
    .padding(.vertical, NexusSpace.s2)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(palette.warningSoft, in: RoundedRectangle(cornerRadius: NexusRadius.sm))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }
}

/// Inline quick-add pinned above the scrolling task list.
///
/// Title-only by design: it leaves `body` and `priority` on the view model
/// untouched so every task it creates carries the Agent Operating Contract
/// defaults (`status:inbox`, `type:task`, `source:manual`, `priority:p2`). The
/// capture window remains the place to override priority or add notes.
///
/// Success is reported in the composer rather than by making the new row
/// visible. The row can legitimately be filtered out of view — by the Today
/// mode (a composed task has no due date), by the search query, or by an
/// active label filter — and the alternative, resetting the mode, query and
/// filters on every add, throws away view state the user set deliberately,
/// including the filter selection that `TaskListViewModel` persists to disk.
///
/// "Add task" is the one prominent `action` button in this view, which is why
/// the footer's refresh control and the filter controls are all secondary.
private struct QuickAddComposerView: View {
  @ObservedObject var viewModel: QuickCaptureViewModel
  @Environment(\.nexus) private var palette
  @FocusState private var isTitleFocused: Bool
  @State private var createdIssueNumber: Int?

  let tokenProvider: @MainActor () -> String
  let onCreated: (LifeOSIssue) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s2) {
      HStack(spacing: NexusSpace.s2) {
        // The glyph is what tells this field apart from the visually identical
        // search field a couple of rows down; without it the panel has two
        // bare rounded-border fields and no cue as to which does what.
        Image(systemName: "plus.circle")
          .font(.system(size: NexusSize.iconSm, weight: .regular))
          .foregroundStyle(palette.inkMuted)
          .accessibilityHidden(true)

        TextField("Add a task to Inbox", text: $viewModel.title)
          .textFieldStyle(.roundedBorder)
          .font(NexusFont.body)
          .frame(height: NexusSize.macControl)
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
          .buttonStyle(.borderedProminent)
          .tint(palette.action)
          .controlSize(.small)
          .disabled(!viewModel.canSubmit)
          .accessibilityLabel("Add task to Inbox")
          .accessibilityHint("Enter a task title to enable this button")
      }

      if let errorMessage = viewModel.errorMessage {
        HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s1) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: NexusSize.iconSm, weight: .regular))
            .accessibilityHidden(true)
          Text(errorMessage)
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(NexusFont.caption1)
        .foregroundStyle(palette.dangerInk)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add task error: \(errorMessage)")
      } else if let createdIssueNumber {
        HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s1) {
          Image(systemName: "checkmark.circle")
            .font(.system(size: NexusSize.iconSm, weight: .regular))
            .accessibilityHidden(true)
          Text("Added")
          Text("#\(createdIssueNumber)")
            .font(NexusFont.code)
          Text("to Inbox")
        }
        .font(NexusFont.caption1)
        .foregroundStyle(palette.successInk)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Added task number \(createdIssueNumber) to Inbox")
      }
    }
    // Clear the confirmation once the next title is being typed. Keyed on a
    // non-empty title on purpose: the success path itself empties the field, so
    // keying on any change would race the confirmation away as it appears.
    .onChange(of: viewModel.title) {
      if !viewModel.title.isEmpty {
        createdIssueNumber = nil
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
    createdIssueNumber = nil
    Task {
      if let createdIssue = await viewModel.submit(token: tokenProvider()) {
        onCreated(createdIssue)
        createdIssueNumber = createdIssue.number
      }
      // Keep the caret in the field either way: ready for the next task on
      // success, and on the retained text after a failure.
      isTitleFocused = true
    }
  }
}

private struct FilterControlsView: View {
  @ObservedObject var viewModel: TaskListViewModel
  @Environment(\.nexus) private var palette
  @State private var isExpanded = false
  @State private var savedFilterName = ""

  var body: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s2) {
      HStack(spacing: NexusSpace.s2) {
        Button {
          withAnimation(NexusMotion.easeOut) {
            isExpanded.toggle()
          }
        } label: {
          HStack(spacing: NexusSpace.s1) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
              .font(.system(size: NexusSize.iconXs, weight: .regular))
            Text("Filters")
              .font(NexusFont.body)
            if viewModel.activeFilterCount > 0 {
              NexusBadge("\(viewModel.activeFilterCount)", tone: .info)
            }
          }
          .foregroundStyle(palette.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse filters" : "Expand filters")

        Spacer()

        savedFiltersMenu

        Button("Clear filters") {
          viewModel.clearFilters()
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(viewModel.activeFilter.isEmpty)
        .accessibilityLabel("Clear all filters")
      }

      if isExpanded {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: NexusSpace.s2) {
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
        .frame(maxHeight: NexusSize.macInspector)

        HStack(spacing: NexusSpace.s2) {
          TextField("Saved filter name", text: $savedFilterName)
            .textFieldStyle(.roundedBorder)
            .font(NexusFont.body)
            .frame(height: NexusSize.macControl)
            .onSubmit(saveCurrentFilter)

          Button("Save filter", action: saveCurrentFilter)
            .buttonStyle(.bordered)
            .controlSize(.small)
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
            Button("Apply filter") {
              viewModel.applySavedFilter(id: savedFilter.id)
            }
            Button("Delete filter", role: .destructive) {
              viewModel.deleteSavedFilter(id: savedFilter.id)
            }
          }
        }
      }
    } label: {
      Label("Saved filters", systemImage: "bookmark")
        .font(NexusFont.body)
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
  @Environment(\.nexus) private var palette
  let family: TaskFilterFamily
  let labels: [GitHubLabel]
  let isSelected: (String) -> Bool
  let toggle: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s1) {
      Text(family.title)
        .font(NexusFont.caption2)
        .foregroundStyle(palette.inkMuted)

      if labels.isEmpty {
        Text("No labels in cache")
          .font(NexusFont.caption1)
          .foregroundStyle(palette.inkSubtle)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: NexusSpace.s1) {
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
  @Environment(\.nexus) private var palette
  let label: String
  let fullLabelName: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(NexusFont.caption1)
        .padding(.horizontal, NexusSpace.s2)
        .padding(.vertical, NexusSpace.s1)
        .foregroundStyle(isSelected ? palette.onAction : palette.ink)
        .background(
          isSelected ? palette.action : palette.surfaceSunken,
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
    TaskSectionLayout(
      title: section.status.title,
      count: section.issues.count,
      tone: section.status.nexusTone,
      emptyMessage: "No tasks",
      issues: section.issues,
      selectIssue: selectIssue
    )
  }
}

private struct TodayTaskSectionView: View {
  let issues: [LifeOSIssue]
  let selectIssue: (LifeOSIssue) -> Void

  var body: some View {
    TaskSectionLayout(
      title: "Due today and overdue",
      count: issues.count,
      tone: .attention,
      emptyMessage: "No tasks due today",
      issues: issues,
      selectIssue: selectIssue
    )
  }
}

/// One titled group of task rows. The count badge carries the section's Nexus
/// tone: `attention` for work that needs a decision, `flow` for work in
/// flight. The section title is always the word beside the color.
private struct TaskSectionLayout: View {
  @Environment(\.nexus) private var palette
  let title: String
  let count: Int
  let tone: NexusBadge.Tone
  let emptyMessage: String
  let issues: [LifeOSIssue]
  let selectIssue: (LifeOSIssue) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: NexusSpace.s2) {
      HStack(spacing: NexusSpace.s2) {
        Text(title)
          .font(NexusFont.headline)
          .foregroundStyle(palette.ink)
        NexusBadge("\(count)", tone: tone)
        Spacer()
      }

      if issues.isEmpty {
        Text(emptyMessage)
          .font(NexusFont.caption1)
          .foregroundStyle(palette.inkSubtle)
          .padding(.leading, NexusSpace.s0_5)
      } else {
        VStack(spacing: NexusSpace.s1) {
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
}

/// A task row, on paper rather than glass: content surfaces stay solid so the
/// glass chrome above and below it reads as floating.
private struct TaskRow: View {
  @Environment(\.nexus) private var palette
  let issue: LifeOSIssue
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s2) {
        Text("#\(issue.number)")
          .font(NexusFont.code)
          .foregroundStyle(palette.inkSubtle)
          .frame(minWidth: NexusSpace.s10, alignment: .trailing)

        Text(issue.title)
          .font(NexusFont.body)
          .foregroundStyle(palette.ink)
          .lineLimit(2)

        Spacer(minLength: NexusSpace.s1)

        if let dueDate = issue.dueDate {
          Text(dueDate.githubDate)
            .font(NexusFont.code)
            .foregroundStyle(palette.inkMuted)
        }

        if let priority = issue.labels.first(where: { $0.name.hasPrefix("priority:") }) {
          Text(priority.name.replacingOccurrences(of: "priority:", with: "").uppercased())
            .font(NexusFont.code)
            .foregroundStyle(palette.inkMuted)
        }

        Image(systemName: "chevron.right")
          .font(.system(size: NexusSize.iconXs, weight: .regular))
          .foregroundStyle(palette.inkSubtle)
      }
      .padding(.horizontal, NexusSpace.s2)
      .padding(.vertical, NexusSpace.s2)
      .frame(minHeight: NexusSize.macRow)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
    .background(palette.surfaceRaised, in: RoundedRectangle(cornerRadius: NexusRadius.sm))
    .accessibilityLabel("Open task #\(issue.number): \(issue.title)")
  }
}

extension TaskStatusSection {
  /// Nexus semantics for a status section: `attention` is work that needs a
  /// decision, `flow` is work in flight, `info` is work that is lined up, and
  /// everything parked is `neutral`.
  fileprivate var nexusTone: NexusBadge.Tone {
    switch self {
    case .inbox:
      return .attention
    case .active:
      return .flow
    case .next, .scheduled:
      return .info
    case .waiting, .someday:
      return .neutral
    }
  }
}
