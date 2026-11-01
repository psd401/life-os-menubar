import AppKit
import LifeOSMenubarCore
import NexusKit
import SwiftUI

@MainActor
final class QuickCaptureWindowController: NSWindowController, NSWindowDelegate {
  private let viewModel: QuickCaptureViewModel
  private let tokenProvider: @MainActor () -> String
  private let onCreated: (LifeOSIssue) -> Void

  init(
    viewModel: QuickCaptureViewModel,
    tokenProvider: @escaping @MainActor () -> String,
    onCreated: @escaping (LifeOSIssue) -> Void
  ) {
    self.viewModel = viewModel
    self.tokenProvider = tokenProvider
    self.onCreated = onCreated

    let window = QuickCaptureWindow(
      contentRect: NSRect(x: 0, y: 0, width: QuickCaptureMetrics.width, height: 360),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    // The Nexus `MacQuickAsk` pattern is a floating bar, not a titled document
    // window, so the chrome is hidden and the SwiftUI content fills the frame.
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    // Two deliberate deviations from `MacQuickAsk`, both recorded in openwiki
    // decision 0003:
    //
    // 1. The window stays activating rather than `.nonactivatingPanel`. Capture
    //    is keyboard-first and the title field has to take first responder the
    //    moment the hotkey fires.
    // 2. The window stays opaque rather than showing the desktop through the
    //    bar. NexusKit's `.nexusTheme` paints `surfaceCanvas` behind its
    //    content unconditionally, so a see-through bar would mean editing a
    //    vendored file. Glass is applied where the pattern cares about it — the
    //    ask row — and the rest of the content sits on paper.
    window.setAccessibilityLabel("Quick capture")
    window.center()
    window.isReleasedWhenClosed = false
    window.level = .floating
    window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

    super.init(window: window)
    window.delegate = self
    window.cancelHandler = { [weak self] in
      self?.cancelCapture()
    }
    window.contentView = NSHostingView(
      rootView: QuickCaptureView(
        viewModel: viewModel,
        tokenProvider: tokenProvider,
        cancel: { [weak self] in
          self?.cancelCapture()
        },
        created: { [weak self] issue in
          self?.finishCapture(with: issue)
        }
      )
      .nexusTheme(family: .nexus)
    )
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  func showCapture() {
    guard let window else {
      return
    }
    if !window.isVisible {
      viewModel.prepareForNewCapture()
      window.center()
    }
    showWindow(nil)
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    viewModel.requestTitleFocus()
  }

  func windowWillClose(_ notification: Notification) {
    viewModel.cancel()
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    !viewModel.isSubmitting
  }

  private func cancelCapture() {
    guard !viewModel.isSubmitting else {
      return
    }
    viewModel.cancel()
    close()
  }

  private func finishCapture(with issue: LifeOSIssue) {
    onCreated(issue)
    close()
  }
}

private final class QuickCaptureWindow: NSWindow {
  var cancelHandler: (() -> Void)?

  override func cancelOperation(_ sender: Any?) {
    cancelHandler?()
  }
}
