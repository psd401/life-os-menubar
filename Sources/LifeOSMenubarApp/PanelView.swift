import AppKit
import LifeOSMenubarCore
import SwiftUI

struct PanelView: View {
  @ObservedObject var settingsViewModel: SettingsViewModel
  @ObservedObject var taskListViewModel: TaskListViewModel
  let openSettings: () -> Void
  let quit: () -> Void

  var body: some View {
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

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          ForEach(taskListViewModel.sections) { section in
            TaskSectionView(section: section)
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
          TaskRow(issue: issue)
        }
      }
    }
  }
}

private struct TaskRow: View {
  let issue: LifeOSIssue

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text("#\(issue.number)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.tertiary)
        .frame(minWidth: 42, alignment: .trailing)

      Text(issue.title)
        .font(.callout)
        .lineLimit(2)

      Spacer(minLength: 4)

      if let priority = issue.labels.first(where: { $0.name.hasPrefix("priority:") }) {
        Text(priority.name.replacingOccurrences(of: "priority:", with: "").uppercased())
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
  }
}
