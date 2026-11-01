import AppKit
import NexusKit

@main
enum LifeOSMenubarMain {
  @MainActor
  static func main() {
    // Register the bundled Nexus fonts before anything can render: the panel,
    // the capture window and Settings all name Newsreader, Public Sans and IBM
    // Plex Mono through `NexusFont`, and an unregistered family falls back to
    // the system font silently.
    NexusFonts.register()

    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
    withExtendedLifetime(delegate) {}
  }
}
