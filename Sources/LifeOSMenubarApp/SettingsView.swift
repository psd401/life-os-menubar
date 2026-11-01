import KeyboardShortcuts
import LifeOSMenubarCore
import NexusKit
import SwiftUI

/// Geometry for the settings window. Nexus has no token for a settings window's
/// frame, so the two constants live here instead of as literals in the window
/// controller and the view.
enum SettingsMetrics {
  static let width: CGFloat = 520
  static let height: CGFloat = 430
}

struct SettingsView: View {
  @ObservedObject var viewModel: SettingsViewModel
  @ObservedObject var taskListViewModel: TaskListViewModel
  @Environment(\.nexus) private var palette

  var body: some View {
    Form {
      Section {
        SecureField("Fine-grained personal access token", text: $viewModel.token)
          .textContentType(.password)
          .font(NexusFont.body)
          .frame(height: NexusSize.macControl)

        HStack(spacing: NexusSpace.s2) {
          // The one prominent `action` button in this view.
          Button("Save and validate token") {
            Task {
              await viewModel.saveAndValidateToken()
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(palette.action)
          .disabled(
            viewModel.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || viewModel.validationState == .validating
          )

          Button("Clear token", role: .destructive) {
            viewModel.clearToken()
          }
          .buttonStyle(.bordered)
          .disabled(viewModel.token.isEmpty)

          validationStatus
        }

        if let persistenceError = viewModel.persistenceError {
          SettingsNotice(
            message: persistenceError,
            systemImage: "exclamationmark.triangle",
            foreground: palette.dangerInk
          )
        }

        Text("The token is stored only in your macOS Keychain.")
          .font(NexusFont.caption1)
          .foregroundStyle(palette.inkMuted)

        if taskListViewModel.projectFieldAccess == .missingScope {
          SettingsNotice(
            message: "Today and project dates need read:project access. "
              + "Re-run sign-in or replace this token with one that grants read:project; "
              + "all other features continue to work.",
            systemImage: "calendar.badge.exclamationmark",
            foreground: palette.warningInk
          )
        }
      } header: {
        Text("GitHub")
          .font(NexusFont.headline)
          .foregroundStyle(palette.ink)
      }

      Section {
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
          SettingsNotice(
            message: launchAtLoginError,
            systemImage: "exclamationmark.triangle",
            foreground: palette.dangerInk
          )
        }

        if let badgePreferenceError = viewModel.badgePreferenceError {
          SettingsNotice(
            message: badgePreferenceError,
            systemImage: "exclamationmark.triangle",
            foreground: palette.dangerInk
          )
        }
      } header: {
        Text("General")
          .font(NexusFont.headline)
          .foregroundStyle(palette.ink)
      }
    }
    .font(NexusFont.body)
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .padding(NexusSpace.s4)
    .frame(width: SettingsMetrics.width, height: SettingsMetrics.height)
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
      // The badge has to say "Valid", not just turn green around a username:
      // the Nexus rule is that a status color is always paired with a word, and
      // without one a VoiceOver user hears the login and no status at all.
      NexusBadge("Valid · @\(login)", tone: .success)
        .accessibilityLabel("Token is valid for @\(login)")
    case .invalid(let message):
      NexusBadge("Not valid · \(message)", tone: .danger)
        .lineLimit(2)
        .accessibilityLabel("Token is not valid: \(message)")
    }
  }
}

/// A settings notice. The icon and the sentence carry the meaning; the status
/// color only reinforces it.
private struct SettingsNotice: View {
  let message: String
  let systemImage: String
  let foreground: Color

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: NexusSpace.s2) {
      Image(systemName: systemImage)
        .font(.system(size: NexusSize.iconSm, weight: .regular))
        .accessibilityHidden(true)
      Text(message)
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(NexusFont.caption1)
    .foregroundStyle(foreground)
    .accessibilityElement(children: .combine)
  }
}
