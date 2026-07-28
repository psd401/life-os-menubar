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

      if let errorMessage = taskListViewModel.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Refresh error: \(errorMessage)")
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
