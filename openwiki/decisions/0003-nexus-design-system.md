---
okf_version: "0.1"
---

# 0003 — Adopt the Nexus design system via NexusKit

**Date:** 2026-10-31 · **Status:** Implemented
([#19](https://github.com/psd401/life-os-menubar/issues/19))
· **Driver:** psd-dev-standards 10 (design system)

## Context

v1's SwiftUI views use ad-hoc colors, fonts, and spacing chosen per view.
`PanelView` and `TaskDetailView` are the two largest files in the App target
(435 and 498 lines) and carry most of that styling inline. Standard 10 makes
Nexus the PSD design system, and a public psd401 app that does not look like one
is a visible exception.

## Decision

Adopt Nexus through the **NexusKit** SwiftUI package: colors, typography, and
spacing come from Nexus tokens rather than literals. Components and themes are in
scope.

Nexus's agent-pattern surfaces — companion, AskUserQuestion, trust lines — are
explicitly **out** of scope. There is no agent in this app, and adopting those
patterns would mean inventing an agent to justify them.

## Alternatives rejected

- **Keep ad-hoc styling.** Cheapest, but leaves the app off-standard and leaves
  every future view making its own color decisions.
- **A local token file instead of NexusKit.** Avoids a dependency but forks the
  design system; token drift is the exact failure the shared package prevents.
- **Nexus tokens only, no components.** Considered, and this is the fallback if
  NexusKit's components do not fit a menu bar panel's constraints. Tokens are the
  non-negotiable part; components are adopted where they fit.

## Consequences

- **Raises the deployment floor to macOS 26.** This is the main cost and it gets
  its own decision — see [0004](0004-macos-26-floor.md).
- Adds a second SwiftPM dependency (after `KeyboardShortcuts`), so the Dependabot
  `swift` ecosystem starts earning its keep.
- The restyling touches `PanelView`, `TaskDetailView`, `SettingsView`, and
  `QuickCaptureView` — all in the untested App target. Visual regressions are
  caught by screenshots in the PR, not by the test suite, which is why the
  evidence bar requires a screenshot for any UI change.

## As implemented

NexusKit is vendored at `Vendor/NexusKit/` (see
[`VENDORED.md`](../../Vendor/NexusKit/VENDORED.md)) and wired as a local SwiftPM
package in both `Package.swift` and the Xcode project. `NexusFonts.register()`
runs in `LifeOSMenubarMain.main()` before anything can render, and
`.nexusTheme(family: .nexus)` is applied once per hosted SwiftUI tree — in
`PanelController`, `QuickCaptureWindowController`, and
`SettingsWindowController`. Applying it at the host rather than inside each
view matters: `NexusThemeModifier` writes `\.nexus` into the environment of
its *children*, so a view that applied the theme to itself would still read
the default light palette.

Three deviations from the Nexus macOS patterns, all forced rather than chosen:

1. **The panel host stays `NSStatusItem` + `NSPopover`**, not `MenuBarExtra`
   with `.window` style. Keyboard-first focus is why the panel host was chosen;
   the visuals follow `MacMenuBarExtra` regardless. This one was planned.
2. **Quick capture stays an activating window**, not `MacQuickAsk`'s
   `.nonactivatingPanel`. The title field has to take first responder the
   moment the hotkey fires.
3. **Quick capture stays opaque**, so the bar does not show the desktop
   through it. `NexusThemeModifier` ends with `.background(p.surfaceCanvas)`
   unconditionally, so a see-through bar would mean editing a vendored file —
   which is the one thing vendoring forbids. Glass is applied to the ask row,
   and the rest of the window sits on paper, which is the rule the macOS
   guideline actually states: glass for controls, paper for content.

Two places keep raw values on purpose, both documented at the call site:
the 1pt hairline on `line` borders (NexusKit's own components use the same
literal, and there is no stroke-width token), and `StatusItemBadgeRenderer`,
which draws a **template** image — its black is a mask that macOS tints to
match the menu bar, not a color choice, and Nexus has no menu-bar type scale.
