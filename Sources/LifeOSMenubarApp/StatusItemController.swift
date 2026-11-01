import AppKit
import Combine
import LifeOSMenubarCore
import NexusKit

@MainActor
final class StatusItemController {
  private let panelController: PanelController
  private let onPanelOpen: () -> Void
  private let statusItem: NSStatusItem
  private var cancellables: Set<AnyCancellable> = []
  private var renderedBadge: (count: Int, kind: MenuBarCount)?

  init(
    panelController: PanelController,
    taskListViewModel: TaskListViewModel,
    settingsViewModel: SettingsViewModel,
    onPanelOpen: @escaping () -> Void
  ) {
    self.panelController = panelController
    self.onPanelOpen = onPanelOpen
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    guard let button = statusItem.button else {
      return
    }
    button.image = StatusItemBadgeRenderer.image(count: 0)
    button.imagePosition = .imageOnly
    button.target = self
    button.action = #selector(togglePanel(_:))

    taskListViewModel.menuBarCountPublisher(
      for: settingsViewModel.$menuBarCount.eraseToAnyPublisher()
    )
    .sink { [weak self] badge in
      self?.updateBadge(count: badge.count, kind: badge.kind)
    }
    .store(in: &cancellables)
  }

  @objc
  private func togglePanel(_ sender: NSStatusBarButton) {
    if panelController.toggle(anchoredTo: sender) {
      onPanelOpen()
    }
  }

  private func updateBadge(count: Int, kind: MenuBarCount) {
    if let renderedBadge, renderedBadge.count == count, renderedBadge.kind == kind {
      return
    }
    renderedBadge = (count, kind)

    statusItem.length = count > 0 ? NSStatusItem.variableLength : NSStatusItem.squareLength
    statusItem.button?.image = StatusItemBadgeRenderer.image(count: count)
    statusItem.button?.setAccessibilityLabel(Self.accessibilityLabel(count: count, kind: kind))
  }

  /// The badge is a bare number, so VoiceOver has to say what it counts.
  private static func accessibilityLabel(count: Int, kind: MenuBarCount) -> String {
    guard count > 0 else {
      return "Life OS"
    }
    switch kind {
    case .today:
      return "Life OS, \(count) due today"
    case .inbox:
      return "Life OS, \(count) in Inbox"
    case .off:
      return "Life OS"
    }
  }
}

/// Draws the menu bar image.
///
/// This renderer is deliberately outside the Nexus palette. The image is a
/// **template** image: macOS masks it and tints the result to match the menu
/// bar, so the black here is the mask, not a color choice — a Nexus `ink` or
/// `action` fill would be thrown away and would break in a light menu bar. For
/// the same reason the badge geometry and its 9pt digits are menu-bar metrics
/// rather than Nexus tokens, which have no menu-bar scale; the icon box is the
/// one dimension that maps cleanly onto a token (`icon-sm`).
private enum StatusItemBadgeRenderer {
  static func image(count: Int) -> NSImage? {
    guard count > 0 else {
      let image = NSImage(
        systemSymbolName: "checkmark.circle",
        accessibilityDescription: "Life OS"
      )
      image?.isTemplate = true
      return image
    }

    let countText = count > 99 ? "99+" : String(count)
    let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.black,
    ]
    let textSize = countText.size(withAttributes: attributes)
    let iconSize = NexusSize.iconSm
    let bubbleHeight: CGFloat = 14
    let bubbleWidth = max(bubbleHeight, ceil(textSize.width) + 7)
    let spacing: CGFloat = 3
    let imageSize = NSSize(
      width: iconSize + spacing + bubbleWidth,
      height: max(iconSize, bubbleHeight)
    )

    let image = NSImage(size: imageSize, flipped: false) { _ in
      guard
        let symbol = NSImage(
          systemSymbolName: "checkmark.circle",
          accessibilityDescription: nil
        )?.withSymbolConfiguration(
          NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
        )
      else {
        return false
      }

      NSColor.black.set()
      symbol.draw(
        in: NSRect(
          x: 0,
          y: (imageSize.height - iconSize) / 2,
          width: iconSize,
          height: iconSize
        )
      )

      let bubbleRect = NSRect(
        x: iconSize + spacing,
        y: (imageSize.height - bubbleHeight) / 2,
        width: bubbleWidth,
        height: bubbleHeight
      )
      NSBezierPath(
        roundedRect: bubbleRect,
        xRadius: bubbleHeight / 2,
        yRadius: bubbleHeight / 2
      ).fill()

      let textPoint = NSPoint(
        x: bubbleRect.midX - (textSize.width / 2),
        y: bubbleRect.midY - (textSize.height / 2)
      )
      NSGraphicsContext.current?.compositingOperation = .destinationOut
      countText.draw(at: textPoint, withAttributes: attributes)
      NSGraphicsContext.current?.compositingOperation = .sourceOver
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Life OS, \(count) due today"
    return image
  }
}
