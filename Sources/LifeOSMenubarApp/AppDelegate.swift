import AppKit
import KeyboardShortcuts
import LifeOSMenubarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var quickCaptureWindowController: QuickCaptureWindowController?
  private var statusItemController: StatusItemController?
  private var settingsWindowController: SettingsWindowController?
  private var taskListViewModel: TaskListViewModel?
  private var settingsViewModel: SettingsViewModel?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)

    // The task list is built first so signing out and changing the repository
    // can clear it: the settings view model takes both as closures.
    let cacheStore = JSONIssueCacheStore()
    let taskListViewModel = TaskListViewModel(
      cacheStore: cacheStore,
      syncEngine: IssueSyncEngine(
        client: GitHubGraphQLIssueClient(),
        projectFieldClient: GitHubGraphQLProjectFieldClient(),
        cacheStore: cacheStore
      ),
      filterStore: JSONTaskFilterStore()
    )
    // The clients read the configured repository from the same
    // `UserDefaultsTaskRepositoryStore` on every request, so changing it here
    // takes effect without rebuilding them — but the cache still holds the
    // previous repo's tasks, which is what onRepositoryChange throws away.
    let settingsViewModel = SettingsViewModel(
      tokenStore: KeychainTokenStore(),
      validator: GitHubTokenValidator(),
      launchAtLoginController: LaunchAtLoginController(),
      deviceFlow: GitHubDeviceFlowAuthorizer(),
      // Core holds no AppKit, so sending the user to github.com/login/device is
      // wired up here.
      verificationPageOpener: { url in
        NSWorkspace.shared.open(url)
      },
      onSignOut: { [weak taskListViewModel] in
        taskListViewModel?.clearCachedTasks()
      },
      onRepositoryChange: { [weak self, weak taskListViewModel] _ in
        guard let taskListViewModel else {
          return
        }
        taskListViewModel.resetForRepositoryChange()
        guard let token = self?.settingsViewModel?.token, !token.isEmpty else {
          return
        }
        Task {
          await taskListViewModel.refresh(token: token)
        }
      }
    )
    let settingsWindowController = SettingsWindowController(
      viewModel: settingsViewModel,
      taskListViewModel: taskListViewModel
    )
    // One client, two independent drafts: the capture window and the panel
    // composer must not share title/priority state, or opening the hotkey window
    // would wipe whatever is half-typed in the panel.
    let issueCreationClient = GitHubRESTIssueClient()
    let quickAddViewModel = QuickCaptureViewModel(client: issueCreationClient)
    let quickCaptureWindowController = QuickCaptureWindowController(
      viewModel: QuickCaptureViewModel(client: issueCreationClient),
      tokenProvider: {
        settingsViewModel.token
      },
      onCreated: { issue in
        taskListViewModel.reconcileRemoteIssue(issue)
        Task {
          await taskListViewModel.refresh(token: settingsViewModel.token)
        }
      }
    )
    let panelController = PanelController(
      rootView: PanelView(
        settingsViewModel: settingsViewModel,
        taskListViewModel: taskListViewModel,
        quickAddViewModel: quickAddViewModel,
        openSettings: {
          settingsWindowController.showSettings()
        },
        quit: {
          NSApplication.shared.terminate(nil)
        }
      )
    )

    self.settingsViewModel = settingsViewModel
    self.settingsWindowController = settingsWindowController
    self.quickCaptureWindowController = quickCaptureWindowController
    self.taskListViewModel = taskListViewModel
    self.statusItemController = StatusItemController(
      panelController: panelController,
      taskListViewModel: taskListViewModel,
      settingsViewModel: settingsViewModel,
      onPanelOpen: {
        quickAddViewModel.requestTitleFocus()
        Task {
          await taskListViewModel.refresh(token: settingsViewModel.token)
        }
      }
    )

    KeyboardShortcuts.onKeyUp(for: .quickCapture) { [weak quickCaptureWindowController] in
      quickCaptureWindowController?.showCapture()
    }

    taskListViewModel.startBackgroundRefresh {
      settingsViewModel.token
    }
    Task {
      await taskListViewModel.refresh(token: settingsViewModel.token)
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationWillTerminate(_ notification: Notification) {
    taskListViewModel?.stopBackgroundRefresh()
  }
}
