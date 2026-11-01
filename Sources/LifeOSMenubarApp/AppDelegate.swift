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
    let quickCaptureWindowController = QuickCaptureWindowController(
      viewModel: QuickCaptureViewModel(client: GitHubRESTIssueClient()),
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
