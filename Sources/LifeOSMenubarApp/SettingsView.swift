import LifeOSMenubarCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject var viewModel: SettingsViewModel

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
      }

      Section("General") {
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
      }
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 520, height: 310)
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
