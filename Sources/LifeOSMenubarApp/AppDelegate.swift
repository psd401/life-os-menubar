import AppKit
import LifeOSMenubarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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
        cacheStore: cacheStore
      ),
      filterStore: JSONTaskFilterStore()
    )
    let settingsWindowController = SettingsWindowController(viewModel: settingsViewModel)
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
    self.taskListViewModel = taskListViewModel
    self.statusItemController = StatusItemController(
      panelController: panelController,
      onPanelOpen: {
        Task {
          await taskListViewModel.refresh(token: settingsViewModel.token)
        }
      }
    )

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
