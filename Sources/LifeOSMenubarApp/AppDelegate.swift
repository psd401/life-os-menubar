import AppKit
import KeyboardShortcuts
import LifeOSMenubarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var quickCaptureWindowController: QuickCaptureWindowController?
  private var statusItemController: StatusItemController?
  private var settingsWindowController: SettingsWindowController?
  private var taskListViewModel: TaskListViewModel?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)

    let settingsViewModel = SettingsViewModel(
      tokenStore: KeychainTokenStore(),
      validator: GitHubTokenValidator(),
      launchAtLoginController: LaunchAtLoginController()
    )
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
