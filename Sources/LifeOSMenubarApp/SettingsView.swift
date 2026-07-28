import KeyboardShortcuts
import LifeOSMenubarCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject var viewModel: SettingsViewModel
  @ObservedObject var taskListViewModel: TaskListViewModel

  var body: some View {
    Form {
      Section("GitHub") {
        SecureField("Fine-grained personal access token", text: $viewModel.token)
          .textContentType(.password)

        HStack {
          Button("Save & Validate") {
            Task {
              await viewModel.saveAndValidateToken()
            }
          }
          .disabled(
            viewModel.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || viewModel.validationState == .validating
          )

          Button("Clear", role: .destructive) {
            viewModel.clearToken()
          }
          .disabled(viewModel.token.isEmpty)

          validationStatus
        }

        if let persistenceError = viewModel.persistenceError {
          Label(persistenceError, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
        }

        Text("The token is stored only in your macOS Keychain.")
          .font(.caption)
          .foregroundStyle(.secondary)

        if taskListViewModel.projectFieldAccess == .missingScope {
          Label(
            "Today and project dates need read:project access. "
              + "Re-run sign-in or replace this token with one that grants read:project; "
              + "all other features continue to work.",
            systemImage: "calendar.badge.exclamationmark"
          )
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
        }
      }

      Section("General") {
        KeyboardShortcuts.Recorder(
          "Quick capture shortcut",
          name: .quickCapture
        )

        Toggle(
          "Show Today count in the menu bar",
          isOn: Binding(
            get: {
              viewModel.isTodayBadgeEnabled
            },
            set: { newValue in
              viewModel.setTodayBadgeEnabled(newValue)
            }
          )
        )

        Toggle(
          "Launch Life OS Menubar at login",
          isOn: Binding(
            get: {
              viewModel.isLaunchAtLoginEnabled
            },
            set: { newValue in
              viewModel.setLaunchAtLoginEnabled(newValue)
            }
          )
        )

        if let launchAtLoginError = viewModel.launchAtLoginError {
          Label(launchAtLoginError, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
        }

        if let badgePreferenceError = viewModel.badgePreferenceError {
          Label(badgePreferenceError, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
        }
      }
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 520, height: 430)
  }

  @ViewBuilder
  private var validationStatus: some View {
    switch viewModel.validationState {
    case .idle:
      EmptyView()
    case .validating:
      ProgressView()
        .controlSize(.small)
    case .valid(let login):
      Label("@\(login)", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .invalid(let message):
      Label(message, systemImage: "xmark.circle.fill")
        .foregroundStyle(.red)
        .lineLimit(2)
    }
  }
}
