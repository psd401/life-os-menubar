import AppKit
import LifeOSMenubarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItemController: StatusItemController?
  private var settingsWindowController: SettingsWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)

    let settingsViewModel = SettingsViewModel(
      tokenStore: KeychainTokenStore(),
      validator: GitHubTokenValidator(),
      launchAtLoginController: LaunchAtLoginController()
    )
    let settingsWindowController = SettingsWindowController(viewModel: settingsViewModel)
    let panelController = PanelController(
      rootView: PanelView(
        settingsViewModel: settingsViewModel,
        openSettings: {
          settingsWindowController.showSettings()
        },
        quit: {
          NSApplication.shared.terminate(nil)
        }
      )
    )

    self.settingsWindowController = settingsWindowController
    self.statusItemController = StatusItemController(panelController: panelController)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}
