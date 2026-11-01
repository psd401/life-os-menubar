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
  // Sized for the states people actually see: first run (no repository,
  // sign-in text and the unconfigured notice) and signed in with a valid
  // repository, each with Advanced folded. The rare stack of every notice at
  // once — a failed sign-in, the missing-scope notice, a failed repository with
  // its label list, Advanced expanded — needs about 990pt, more than a 13-inch
  // MacBook's usable height, so that case scrolls instead.
  static let height: CGFloat = 780
}

struct SettingsView: View {
  @ObservedObject var viewModel: SettingsViewModel
  @ObservedObject var taskListViewModel: TaskListViewModel
  @Environment(\.nexus) private var palette
  @State private var signInTask: Task<Void, Never>?
  @State private var isAdvancedExpanded = false
  @State private var didCopyCode = false

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
    .onDisappear {
      cancelSignIn()
    }
  }

  /// True while a device-flow sign-in is asking for or waiting on a grant.
  private var isSignInInProgress: Bool {
    switch viewModel.deviceFlowState {
    case .requestingCode, .awaitingApproval:
      true
    case .idle, .failed:
      false
    }
  }

  /// Abandons an in-flight sign-in. It never touches a stored credential —
  /// removing one is what Sign out does.
  private func cancelSignIn() {
    signInTask?.cancel()
    signInTask = nil
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
        // This is the one sentence in the window that carries real risk, so it
        // is set at body size rather than caption size like the rest.
        Text(
          "Sign-in asks for the repo and read:project scopes. Note that repo grants read and "
            + "write access to every repository your GitHub account can reach, including "
            + "private and organization repositories. For the least-privilege alternative, "
            + "open Advanced and use a token instead."
        )
        .font(NexusFont.body)
        .foregroundStyle(palette.ink)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var signInButtonRow: some View {
    HStack(spacing: NexusSpace.s2) {
      // The one prominent `action` button in this view.
      Button("Sign in with GitHub") {
        cancelSignIn()
        didCopyCode = false
        signInTask = Task {
          await viewModel.signInWithDeviceFlow()
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(palette.action)
      .disabled(!viewModel.isDeviceFlowAvailable)

      if viewModel.isSignedIn {
        Button("Sign out", role: .destructive) {
          cancelSignIn()
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
      Text("GitHub is open in your browser. Enter this code there, then come back here.")
        .font(NexusFont.body)
        .foregroundStyle(palette.ink)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: NexusSpace.s2) {
        Text(authorization.userCode)
          .font(NexusFont.code)
          .foregroundStyle(palette.ink)
          .textSelection(.enabled)
          .accessibilityLabel("Sign-in code \(authorization.userCode)")

        Button(didCopyCode ? "Copied the code" : "Copy code") {
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(authorization.userCode, forType: .string)
          didCopyCode = true
        }
        .buttonStyle(.bordered)

        Link("Open the GitHub page", destination: authorization.verificationURL)
          .font(NexusFont.body)
      }

      HStack(spacing: NexusSpace.s2) {
        ProgressView()
          .controlSize(.small)
        Text("Waiting for your approval. This window updates on its own.")
          .font(NexusFont.caption1)
          .foregroundStyle(palette.inkMuted)
          .fixedSize(horizontal: false, vertical: true)

        Button("Cancel sign-in") {
          cancelSignIn()
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

        SecureField("Token", text: $viewModel.token, prompt: Text("Paste your token"))
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

        if isSignInInProgress {
          SettingsNotice(
            message: "Finish or cancel the sign-in above before entering a token.",
            systemImage: "info.circle",
            foreground: palette.inkMuted
          )
        }
      }
      .padding(.top, NexusSpace.s2)
      // Both paths write the same stored credential. Letting the field be
      // edited while a sign-in is pending means two writers racing over one
      // Keychain item, and a draft that a completing sign-in would silently
      // overwrite.
      .disabled(isSignInInProgress)
    } label: {
      Text("Use a token instead")
        .font(NexusFont.body)
        .foregroundStyle(palette.ink)
    }
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
      HStack(spacing: NexusSpace.s2) {
        ProgressView()
          .controlSize(.small)
        // A spinner on its own says "something is happening" and nothing else;
        // the same rule that pairs a status color with a word applies here.
        Text("Checking with GitHub.")
          .font(NexusFont.caption1)
          .foregroundStyle(palette.inkMuted)
      }
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
