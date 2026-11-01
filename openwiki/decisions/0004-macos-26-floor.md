---
okf_version: "0.1"
---

# 0004 — Raise the deployment floor to macOS 26

**Date:** 2026-10-31 · **Status:** Implemented
([#19](https://github.com/psd401/life-os-menubar/issues/19))

## Context

The app currently targets macOS 15: `Package.swift` declares
`platforms: [.macOS(.v15)]` and the Xcode project sets
`MACOSX_DEPLOYMENT_TARGET = 15.0` in six places in `project.pbxproj` (the
project-level Release config plus Debug and Release for each of the three
targets). CI runs on the `macos-15` runner.

Adopting NexusKit ([0003](0003-nexus-design-system.md)) requires macOS 26 APIs.
That makes the floor a consequence of the design decision rather than an
independent choice — but it is a user-visible break, so it is recorded on its own.

## Decision

Raise `MACOSX_DEPLOYMENT_TARGET` to 26.0 and `Package.swift` to the matching
platform when NexusKit lands. Do not ship a compatibility path for macOS 15.

## Alternatives rejected

- **Stay on macOS 15 and skip Nexus.** Rejected: being off the design-system
  standard is a worse outcome than a floor bump for an app with one install.
- **Conditional availability (`if #available(macOS 26)`) with a styled and an
  unstyled path.** Two visual code paths in views that have no test coverage, for
  the benefit of users who do not exist. This is the kind of configuration
  surface standard 02's "smallest system that works" tells us not to build.
- **Bump to macOS 26 now, ahead of NexusKit.** Pointless: the break buys nothing
  until the dependency that needs it arrives.

## Consequences

- Anyone on macOS 15 cannot run versions from #19 onward. The pre-Nexus commits
  on `main` remain buildable for macOS 15 if that is ever needed.
- **CI must move off the `macos-15` runner** to one that can build for macOS 26.
  `.github/workflows/ci.yml` pins `runs-on: macos-15`; that line changes in the
  same PR as the deployment target, or CI fails. This is the easiest part of #19
  to forget.
- **Every** `MACOSX_DEPLOYMENT_TARGET` entry in `project.pbxproj` and the
  `Package.swift` platform must move together; a mismatch produces an app that
  builds through SwiftPM and fails through Xcode, or vice versa. Do not trust a
  count from this page — run
  `grep -c MACOSX_DEPLOYMENT_TARGET LifeOSMenubar.xcodeproj/project.pbxproj`
  and change them all (six at the time of writing).

## As implemented

All six `MACOSX_DEPLOYMENT_TARGET` entries moved to `26.0` in one commit,
alongside `platforms: [.macOS(.v26)]` and `swift-tools-version: 6.2` in
`Package.swift` — the tools version is NexusKit's floor, not just the
platform. The Release `xcodebuild build` reports
`--deployment-target 26.0`, which is how the move was verified rather than
assumed.

CI moved off `runs-on: macos-15` — that image ships Xcode 16 and cannot build
for macOS 26 at all, so leaving the line alone would have failed every check.

The first attempt was `macos-26`, and it failed, which is worth recording
because the obvious choice is the wrong one. The Xcode 26 type checker gives
up on one of NexusKit's canvas-preview files:

```
Vendor/NexusKit/Sources/NexusKit/NexusGallery2.swift:223:13: error: the
compiler is unable to type-check this expression in reasonable time; try
breaking up the expression into distinct sub-expressions
```

The same file compiles on the dev machine's Xcode 27.2. The file is vendored,
so "break up the expression" is not available: editing it would fork the
design system, and it is a `NexusGallery2` preview rather than anything the
app calls, so there is nothing to work around in our own code either.

CI therefore runs on **`xcode-27`** — macOS 27 with Xcode 27, the toolchain the
app is developed against. That label is currently a GitHub **preview** image;
move to the stable macOS 27 label when one exists.

The practical rule this leaves behind: **the CI runner has to match the
toolchain NexusKit compiles on, not merely the one that can target the
deployment floor.** Those are different constraints, and only the second one
is obvious from the deployment target.

The README's requirements block — the single copy of the floor — now reads
macOS 26 / Xcode 26 / Swift 6.2 and links here for the reason.

### Update — 2026-11-01: fixed upstream

"Break up the expression" was not available *here*, but it was upstream.
CodeQL default setup autobuilds Swift on `macos-26-arm64` with Xcode 26.6, and
the org's enforced security configuration rules out any other CodeQL setup, so
the same type-check failure also failed `Analyze (swift)` on #26. The closure
was split in the Nexus design-system artifact, exported to
[psd-dev-standards#194](https://github.com/psd401/psd-dev-standards/pull/194),
and re-vendored at `2cf8879`. Xcode 26.6 now builds the app: `Analyze (swift)`
passed on #26 (run 41325447768). CI stays on `xcode-27`; the Xcode 26 minimum
in the README is now exercised by CodeQL's autobuild on every PR.
