import AppKit
import SwiftUI

@MainActor
final class PanelController {
  private let popover: NSPopover

  init<Content: View>(rootView: Content) {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentSize = NSSize(width: 460, height: 620)
    popover.contentViewController = NSHostingController(rootView: rootView)
    self.popover = popover
  }

  @discardableResult
  func toggle(anchoredTo button: NSStatusBarButton) -> Bool {
    if popover.isShown {
      popover.performClose(nil)
      return false
    } else {
      popover.show(
        relativeTo: button.bounds,
        of: button,
        preferredEdge: .minY
      )
      popover.contentViewController?.view.window?.makeKey()
      return true
    }
  }
}
