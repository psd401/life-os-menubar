import AppKit
import LifeOSMenubarCore
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
      contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Quick Capture"
    window.center()
    window.isReleasedWhenClosed = false
    window.level = .floating
    window.collectionBehavior = [.moveToActiveSpace]

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
