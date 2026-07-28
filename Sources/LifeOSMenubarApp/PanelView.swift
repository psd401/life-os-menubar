import AppKit
import LifeOSMenubarCore
import SwiftUI

struct PanelView: View {
  @ObservedObject var settingsViewModel: SettingsViewModel
  let openSettings: () -> Void
  let quit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "checkmark.circle")
          .accessibilityHidden(true)
        Text("Life OS")
          .font(.headline)
        Spacer()
      }

      Text(connectionSummary)
        .font(.callout)
        .foregroundStyle(.secondary)

      Divider()

      HStack {
        Button("Settings…", action: openSettings)
        Spacer()
        Button("Quit", action: quit)
      }
    }
    .padding(18)
    .frame(width: 320, height: 180)
  }

  private var connectionSummary: String {
    settingsViewModel.token.isEmpty
      ? "Add a GitHub token in Settings to get started."
      : "GitHub token stored securely in Keychain."
  }
}
