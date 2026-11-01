import AppKit
import KeyboardShortcuts
import LifeOSMenubarCore
import NexusKit
import SwiftUI

/// Geometry for the settings window. Nexus has no token for a settings window's
/// frame, so the two constants live here instead of as literals in the window
/// controller and the view.
enum SettingsMetrics {
  static let width: CGFloat = 520
  static let height: CGFloat = 560
}

struct SettingsView: View {
  @ObservedObject var viewModel: SettingsViewModel
  @ObservedObject var taskListViewModel: TaskListViewModel
  @Environment(\.nexus) private var palette
  @State private var signInTask: Task<Void, Never>?
  @State private var isAdvancedExpanded = false

  var body: some View {
    Form {
      Section {
        signInControls

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
            message: "Today and project dates need read:project access. This token can read "
              + "issues but not projects, so Today and the menu bar count are off; everything "
              + "else keeps working. Sign in with GitHub to grant read:project.",
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
        advancedTokenControls
      } header: {
        Text("Advanced")
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
    .task {
      await viewModel.refreshSignInState()
    }
    .onDisappear {
      signInTask?.cancel()
      signInTask = nil
    }
  }

  // MARK: - Sign in

  @ViewBuilder
  private var signInControls: some View {
    switch viewModel.deviceFlowState {
    case .awaitingApproval(let authorization):
      deviceCodePrompt(authorization)
    case .requestingCode:
      HStack(spacing: NexusSpace.s2) {
        ProgressView()
          .controlSize(.small)
        Text("Asking GitHub for a sign-in code.")
          .font(NexusFont.caption1)
          .foregroundStyle(palette.inkMuted)
      }
    case .idle, .failed:
      signInButtonRow

      if case .failed(let message) = viewModel.deviceFlowState {
        SettingsNotice(
          message: message,
          systemImage: "exclamationmark.triangle",
          foreground: palette.dangerInk
        )
      }

      if let reason = viewModel.deviceFlowUnavailableReason {
        SettingsNotice(
          message: reason,
          systemImage: "person.badge.key",
          foreground: palette.warningInk
        )
      } else {
        Text(
          "Sign-in asks for the repo and read:project scopes. Note that repo grants read and "
            + "write access to every repository your GitHub account can reach, including "
            + "private and organization repositories. For the least-privilege alternative, "
            + "use Advanced below."
        )
        .font(NexusFont.caption1)
        .foregroundStyle(palette.inkMuted)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var signInButtonRow: some View {
    HStack(spacing: NexusSpace.s2) {
      // The one prominent `action` button in this view.
      Button("Sign in with GitHub") {
        signInTask?.cancel()
        signInTask = Task {
          await viewModel.signInWithDeviceFlow()
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(palette.action)
      .disabled(!viewModel.isDeviceFlowAvailable)

      if viewModel.isSignedIn {
        Button("Sign out", role: .destructive) {
          signInTask?.cancel()
          signInTask = nil
          viewModel.signOut()
        }
        .buttonStyle(.bordered)
      }

      validationStatus
    }
  }

  @ViewBuilder
  private func deviceCodePrompt(_ authorization: DeviceAuthorization) -> some View {
    VStack(alignment: .leading, spacing: NexusSpace.s2) {
      Text("Enter this code on GitHub to finish signing in.")
        .font(NexusFont.body)
        .foregroundStyle(palette.ink)

      HStack(spacing: NexusSpace.s2) {
        Text(authorization.userCode)
          .font(NexusFont.code)
          .foregroundStyle(palette.ink)
          .textSelection(.enabled)
          .accessibilityLabel("Sign-in code \(authorization.userCode)")

        Button("Copy code") {
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(authorization.userCode, forType: .string)
        }
        .buttonStyle(.bordered)

        Link("Open the GitHub page", destination: authorization.verificationURL)
          .font(NexusFont.body)
      }

      HStack(spacing: NexusSpace.s2) {
        ProgressView()
          .controlSize(.small)
        Text("Waiting for approval.")
          .font(NexusFont.caption1)
          .foregroundStyle(palette.inkMuted)

        // Cancelling abandons this attempt only. Any credential already in the
        // Keychain is left alone; removing one is what Sign out is for.
        Button("Cancel sign-in") {
          signInTask?.cancel()
          signInTask = nil
        }
        .buttonStyle(.bordered)
      }
    }
  }

  // MARK: - Advanced token entry

  @ViewBuilder
  private var advancedTokenControls: some View {
    DisclosureGroup(isExpanded: $isAdvancedExpanded) {
      VStack(alignment: .leading, spacing: NexusSpace.s2) {
        Text(
          "Paste a fine-grained personal access token with Issues read and write on your task "
            + "repository only. That is the narrowest access this app can run on. Fine-grained "
            + "tokens cannot reach a user-owned project, so Today and the menu bar count stay "
            + "off on this path."
        )
        .font(NexusFont.caption1)
        .foregroundStyle(palette.inkMuted)
        .fixedSize(horizontal: false, vertical: true)

        SecureField("Fine-grained personal access token", text: $viewModel.token)
          .textContentType(.password)
          .font(NexusFont.body)
          .frame(height: NexusSize.macControl)

        HStack(spacing: NexusSpace.s2) {
          Button("Save and validate token") {
            Task {
              await viewModel.saveAndValidateToken()
            }
          }
          .buttonStyle(.bordered)
          .disabled(
            viewModel.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || viewModel.validationState == .validating
          )
        }
      }
      .padding(.top, NexusSpace.s2)
    } label: {
      Text("Use a token instead")
        .font(NexusFont.body)
        .foregroundStyle(palette.ink)
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
      // The badge has to say "Signed in", not just turn green around a username:
      // the Nexus rule is that a status color is always paired with a word, and
      // without one a VoiceOver user hears the login and no status at all.
      NexusBadge("Signed in · @\(login)", tone: .success)
        .accessibilityLabel("Signed in to GitHub as @\(login)")
    case .invalid(let message):
      NexusBadge("Not signed in · \(message)", tone: .danger)
        .lineLimit(2)
        .accessibilityLabel("Not signed in: \(message)")
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
