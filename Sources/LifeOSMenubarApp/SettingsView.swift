import KeyboardShortcuts
import LifeOSMenubarCore
import NexusKit
import SwiftUI

/// Geometry for the settings window. Nexus has no token for a settings window's
/// frame, so the two constants live here instead of as literals in the window
/// controller and the view.
enum SettingsMetrics {
  static let width: CGFloat = 520
  /// Grown for the "Task repository" section added in
  /// [#21](https://github.com/psd401/life-os-menubar/issues/21); the form has a
  /// fixed frame, so a section that does not fit is a clipped section. Sized for
  /// that section's tallest state — a repository that failed validation, which
  /// shows both the three-line missing-labels notice and the unconfigured one.
  static let height: CGFloat = 740
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
        TextField("owner/repo", text: $viewModel.repositorySlug)
          .textFieldStyle(.roundedBorder)
          .font(NexusFont.body)
          .frame(height: NexusSize.macControl)
          .accessibilityLabel("Task repository, as owner slash repo")

        HStack(spacing: NexusSpace.s2) {
          Button("Save and validate repository") {
            Task {
              await viewModel.saveAndValidateRepository()
            }
          }
          .buttonStyle(.bordered)
          .disabled(
            viewModel.repositorySlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || viewModel.repositoryState == .validating
          )

          Button("Clear repository", role: .destructive) {
            viewModel.clearRepository()
          }
          .buttonStyle(.bordered)
          .disabled(!viewModel.isRepositoryConfigured && viewModel.repositorySlug.isEmpty)
        }

        // The verdict sits on its own row rather than beside the buttons: a
        // badge sharing the row squeezes "Save and validate repository" until
        // macOS truncates the button's own label.
        repositoryStatus

        // The reason goes on its own full-width row, not inside the badge: the
        // missing-label message names every missing label, and a badge sharing
        // a row with two buttons truncates it to the first two.
        if case .invalid(let message) = viewModel.repositoryState {
          SettingsNotice(
            message: message,
            systemImage: "exclamationmark.triangle",
            foreground: palette.dangerInk
          )
        }

        if !viewModel.isRepositoryConfigured {
          SettingsNotice(
            message: "No task repository is set yet. Enter the owner/repo of a repo that "
              + "follows docs/life-os-repo-standard.md, then save and validate it.",
            systemImage: "folder.badge.questionmark",
            foreground: palette.warningInk
          )
        }

        Text(
          "Validation checks that this token can read the repository and that every "
            + "required status, priority, type, and source label already exists."
        )
        .font(NexusFont.caption1)
        .foregroundStyle(palette.inkMuted)
      } header: {
        Text("Task repository")
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

  /// The repository's own status badge. Same Nexus rule as the token badge: the
  /// word carries the meaning, the color only reinforces it.
  @ViewBuilder
  private var repositoryStatus: some View {
    switch viewModel.repositoryState {
    case .idle:
      EmptyView()
    case .validating:
      ProgressView()
        .controlSize(.small)
    case .valid(let slug):
      NexusBadge("Valid · \(slug)", tone: .success)
        .accessibilityLabel("Task repository \(slug) is valid")
    case .invalid:
      // The reason is the notice below this row, so the badge is only the
      // verdict — still a word beside the color, per the Nexus rule.
      NexusBadge("Not valid", tone: .danger)
        .accessibilityLabel("Task repository is not valid")
    }
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
