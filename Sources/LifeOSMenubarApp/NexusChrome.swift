import NexusKit
import SwiftUI

/// Floating glass for this app's chrome, with the accessibility fallback the
/// Nexus macOS guideline asks for.
///
/// NexusKit's own `.nexusGlass(in:)` falls back to a solid `surface-raised`
/// with a `line` border on **Reduce Transparency** only. The guideline — and
/// #19's Definition of Done — say the swap happens under **Increase Contrast**
/// too, and macOS lets the two be toggled independently: a person can turn on
/// Increase Contrast and leave Transparency alone, and then translucent chrome
/// survives the one setting meant to get rid of it.
///
/// Fixing that in `Vendor/NexusKit/` is not an option — vendored files are
/// never hand-edited — so this app-owned modifier checks both environment
/// values and defers to `.nexusGlass(in:)` only when neither is on. The solid
/// branch is deliberately identical to NexusKit's: `surface-raised` filled in
/// the same shape, with a 1pt `line` stroke. Drop this wrapper and go back to
/// `.nexusGlass(in:)` directly once NexusKit reads
/// `colorSchemeContrast` upstream.
struct NexusChrome<S: Shape>: ViewModifier {
  @Environment(\.nexus) private var palette
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  let shape: S

  func body(content: Content) -> some View {
    if contrast == .increased || reduceTransparency {
      content
        .background(palette.surfaceRaised, in: shape)
        .overlay(shape.stroke(palette.line, lineWidth: 1))
    } else {
      content.nexusGlass(in: shape)
    }
  }
}

extension View {
  /// Glass chrome that turns solid under Increase Contrast *or* Reduce
  /// Transparency. Use this instead of `.nexusGlass(in:)` throughout the app.
  func nexusChrome<S: Shape>(in shape: S) -> some View {
    modifier(NexusChrome(shape: shape))
  }
}
