import AppKit
import SwiftUI

@MainActor
final class PanelController {
  private let panel: StatusPanel

  init<Content: View>(rootView: Content) {
    let panel = StatusPanel(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
      styleMask: [.nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.contentView = NSHostingView(rootView: rootView)
    panel.backgroundColor = .windowBackgroundColor
    panel.hasShadow = true
    panel.hidesOnDeactivate = true
    panel.isFloatingPanel = true
    panel.isReleasedWhenClosed = false
    panel.level = .popUpMenu
    panel.collectionBehavior = [.moveToActiveSpace, .transient]
    self.panel = panel
  }

  @discardableResult
  func toggle(anchoredTo button: NSStatusBarButton) -> Bool {
    if panel.isVisible {
      panel.orderOut(nil)
      return false
    } else {
      show(anchoredTo: button)
      return true
    }
  }

  private func show(anchoredTo button: NSStatusBarButton) {
    guard let buttonWindow = button.window else {
      return
    }

    let buttonRectInWindow = button.convert(button.bounds, to: nil)
    let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)
    let visibleFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
    let panelSize = panel.frame.size

    let proposedX = buttonRectOnScreen.midX - (panelSize.width / 2)
    let minimumX = visibleFrame.minX + 8
    let maximumX = visibleFrame.maxX - panelSize.width - 8
    let clampedX = min(max(proposedX, minimumX), maximumX)
    let y = buttonRectOnScreen.minY - panelSize.height - 4

    panel.setFrameOrigin(NSPoint(x: clampedX, y: y))
    panel.makeKeyAndOrderFront(nil)
  }
}

private final class StatusPanel: NSPanel {
  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    false
  }

  override func cancelOperation(_ sender: Any?) {
    orderOut(sender)
  }

  override func resignKey() {
    super.resignKey()
    orderOut(nil)
  }
}
