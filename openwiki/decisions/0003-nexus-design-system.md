---
okf_version: "0.1"
---

# 0003 — Adopt the Nexus design system via NexusKit

**Date:** 2026-10-31 · **Status:** Accepted, not implemented
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
