import AppKit
import LifeOSMenubarCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  private var promotedActivationPolicy = false

  init(
    viewModel: SettingsViewModel,
    taskListViewModel: TaskListViewModel
  ) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Life OS Menubar Settings"
    window.contentView = NSHostingView(
      rootView: SettingsView(
        viewModel: viewModel,
        taskListViewModel: taskListViewModel
      )
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
  }

  func windowWillClose(_ notification: Notification) {
    guard promotedActivationPolicy else {
      return
    }
    promotedActivationPolicy = false
    NSApplication.shared.setActivationPolicy(.accessory)
  }
}
