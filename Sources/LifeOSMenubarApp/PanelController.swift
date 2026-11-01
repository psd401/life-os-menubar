import AppKit
import NexusKit
import SwiftUI

/// Geometry shared by the panel popover and the views hosted inside it.
///
/// The width is the Nexus `panel-width` token. Nexus has no token for the
/// height of a menu bar panel — the `MacMenuBarExtra` pattern sizes that to its
/// content — so the height is the one named constant here rather than a literal
/// repeated in three files.
enum PanelMetrics {
  static let width = NexusSize.panelWidth
  static let height: CGFloat = 620
}

@MainActor
final class PanelController {
  private let popover: NSPopover

  init<Content: View>(rootView: Content) {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentSize = NSSize(width: PanelMetrics.width, height: PanelMetrics.height)
    // The Nexus theme is applied once per hosted tree, at the root, so every
    // view below reads the resolved palette from `@Environment(\.nexus)` and
    // follows the system color scheme and contrast setting automatically.
    popover.contentViewController = NSHostingController(
      rootView: rootView.nexusTheme(family: .nexus)
    )
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
