import AppKit
import LifeOSMenubarCore
import NexusKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  private var promotedActivationPolicy = false
  private let viewModel: SettingsViewModel

  init(
    viewModel: SettingsViewModel,
    taskListViewModel: TaskListViewModel
  ) {
    self.viewModel = viewModel
    let window = NSWindow(
      contentRect: NSRect(
        x: 0,
        y: 0,
        width: SettingsMetrics.width,
        height: SettingsMetrics.height
      ),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Life OS Menubar settings"
    window.contentView = NSHostingView(
      rootView: SettingsView(
        viewModel: viewModel,
        taskListViewModel: taskListViewModel
      )
      .nexusTheme(family: .nexus)
    )
    window.center()
    window.isReleasedWhenClosed = false

    super.init(window: window)
    window.delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  func showSettings() {
    let application = NSApplication.shared
    if application.activationPolicy() != .regular {
      promotedActivationPolicy = application.setActivationPolicy(.regular)
    }

    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    application.activate(ignoringOtherApps: true)

    // Open with nothing focused. Otherwise SwiftUI focuses the first focusable
    // control — the shortcut recorder, now that the token field sits under
    // Advanced — and a focused recorder is already recording: the next modifier
    // chord (⌘W to close this window, say) becomes the quick-capture shortcut,
    // and the global hot key is paused meanwhile. Async, so it runs after
    // SwiftUI's own initial focus.
    DispatchQueue.main.async { [weak self] in
      self?.window?.makeFirstResponder(nil)
    }

    // This window and its hosted SwiftUI view are built once and reused, so a
    // `.task` on the view would only ever run on the first open. Re-checking
    // here is what keeps the signed-in badge honest after a token is revoked
    // or expires between visits.
    Task {
      await viewModel.refreshSignInState()
    }
  }

  func windowWillClose(_ notification: Notification) {
    guard promotedActivationPolicy else {
      return
    }
    promotedActivationPolicy = false
    NSApplication.shared.setActivationPolicy(.accessory)
  }
}
