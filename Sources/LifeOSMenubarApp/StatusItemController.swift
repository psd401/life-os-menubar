import AppKit

@MainActor
final class StatusItemController {
  private let panelController: PanelController
  private let onPanelOpen: () -> Void
  private let statusItem: NSStatusItem

  init(
    panelController: PanelController,
    onPanelOpen: @escaping () -> Void
  ) {
    self.panelController = panelController
    self.onPanelOpen = onPanelOpen
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    guard let button = statusItem.button else {
      return
    }
    let image = NSImage(
      systemSymbolName: "checkmark.circle",
      accessibilityDescription: "Life OS"
    )
    image?.isTemplate = true
    button.image = image
    button.imagePosition = .imageOnly
    button.target = self
    button.action = #selector(togglePanel(_:))
  }

  @objc
  private func togglePanel(_ sender: NSStatusBarButton) {
    if panelController.toggle(anchoredTo: sender) {
      onPanelOpen()
    }
  }
}
