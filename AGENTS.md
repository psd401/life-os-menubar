# AGENTS.md — life-os-menubar

Native macOS menubar app that fronts a GitHub Issues repo as a task list.
Owner: `krishagel`. Tier: `c-experiment`. Standards: psd401/psd-dev-standards.

This file is a map, not a manual. Depth lives in [`openwiki/`](openwiki/index.md).

## Build, test, lint (exact commands)

Run from the repo root. These are the same commands CI runs
(`.github/workflows/ci.yml`) and the same ones in `.psd/verify.json`.

```sh
# Lint — zero warnings required, no suppressions
swift format lint --strict --recursive Sources Tests Package.swift

# Unit tests (SwiftPM, fast — 128 tests in LifeOSMenubarCoreTests)
swift test

# Full test run through the Xcode project (the authoritative test gate)
xcodebuild test \
  -project LifeOSMenubar.xcodeproj \
  -scheme LifeOSMenubar \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

# Release build of the .app
xcodebuild build \
  -project LifeOSMenubar.xcodeproj \
  -scheme LifeOSMenubar \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Auto-format with `swift format --in-place --recursive Sources Tests Package.swift`.
There is no separate typecheck step: in Swift the build *is* the typecheck, which
is why `.psd/verify.json` configures no `typecheck` command.

There is no package manager step: the single dependency (KeyboardShortcuts)
resolves through SwiftPM. Toolchain and OS requirements live in the
[README](README.md#requirements) — one copy, because the deployment floor is
about to move ([decision 0004](openwiki/decisions/0004-macos-26-floor.md)).

## Architecture map

Two targets, one dependency edge. `Package.swift` and the Xcode project build
the same sources; the Xcode project is what produces the shippable `.app`.

```
Sources/LifeOSMenubarCore/   → library target. No AppKit/SwiftUI. All testable logic.
scripts/                     → the task-repo label bootstrap (`gh`); `--dry-run` prints, never writes.
Sources/LifeOSMenubarApp/    → executable target. AppKit + SwiftUI only. Depends on Core and NexusKit.
Tests/LifeOSMenubarCoreTests/ → swift-testing suites. Core only; the App target is untested by design.
Vendor/NexusKit/             → vendored design system. NEVER hand-edit; see Vendor/NexusKit/VENDORED.md.
Resources/Info.plist         → LSUIElement = true (accessory app, no Dock icon)
```

**Core, by layer** — the layering is the contract; keep each file in its layer:

| Layer | Files | Role |
|-------|-------|------|
| Model | `LifeOSIssue`, `IssueDetail`, `ProjectFields`, `TaskFilter`, `LabelRules`, `TaskRepository` | Value types + the label-contract rules (one `status:*`, one `priority:*`) and the required-label list |
| Clients | `GitHubIssueClient`, `GitHubIssueDetailClient`, `GitHubIssueMutationClient`, `GitHubProjectFieldClient`, `GitHubTokenValidator`, `TaskRepositoryValidator` | GitHub I/O. Reads use GraphQL; mutations use REST. Each is behind a protocol so tests inject a fake |
| Sync / storage | `IssueSyncEngine` (actor), `IssueCacheStore`, `TaskFilterStore`, `KeychainTokenStore`, `UserDefaultsTaskRepositoryStore`, `UserDefaultsMenuBarCountPreferenceStore`, `LaunchAtLoginController` | Watermarked delta sync with a ≥24h full reconcile; JSON caches in Application Support; token in the Keychain; repo slug in `UserDefaults` |
| View models | `TaskListViewModel`, `TaskDetailViewModel`, `SettingsViewModel`, `QuickCaptureViewModel` | `@MainActor` observable state the views bind to |

**App target** — `LifeOSMenubarMain` → `AppDelegate` is the single composition
root: it constructs every store, client, sync engine, and view model and wires
them to `StatusItemController` (menu bar item + its count badge),
`PanelController`/`PanelView` (the panel), `TaskDetailView`,
`SettingsWindowController`/`SettingsView`, and
`QuickCaptureWindowController`/`QuickCaptureView` (global hotkey). Views hold no
business logic; if logic is needed, it belongs in a Core view model with a test.

State on disk: `~/Library/Application Support/LifeOSMenubar/{issues,filters}.json`.

## Rules that are not negotiable

- **Design system:** every color, font, spacing, radius, and motion value in the
  App target comes from NexusKit — `NexusFont`, `NexusSpace`, `NexusRadius`,
  `NexusSize`, `NexusMotion`, and the palette on `@Environment(\.nexus)`. No raw
  hex, font family, or pixel value where a token exists; the two documented
  exceptions are the 1pt `line` hairline and the menu bar's template image.
  `.nexusTheme(family: .nexus)` is applied once per hosted SwiftUI tree, in the
  window/popover controller, never inside the view itself — the modifier writes
  the palette into its *children's* environment.
- **Vendored code is read-only.** Nothing under `Vendor/` is ever hand-edited.
  Changes flow one way: design-system artifact → `psd-dev-standards` → here.
  Refresh with the recipe in `Vendor/NexusKit/VENDORED.md` and record the new
  source commit SHA.
- **Copy follows the Nexus writing rules:** sentence case, no emoji, buttons are
  verbs with objects (`Add task`, `Close task`), and a status color is always
  paired with a word or an icon.
- **Secrets:** the GitHub token lives only in the macOS Keychain
  (`KeychainTokenStore`). Never a `.env`, a plist, a default, or a log line
  (standard 04, rule 15a).
- **Label contract:** any mutation normalizes to exactly one `status:*` and one
  `priority:*`; missing values are repaired to `status:inbox` / `priority:p2`.
  Local list and cache state change only after GitHub accepts the mutation.
- **No default task repo.** Nothing in `Sources/` may hardcode an owner or repo.
  The clients resolve the configured `TaskRepository` per request and throw
  `TaskRepositoryConfigurationError.notConfigured` when there is none; the panel
  shows a setup card for that state. The contract a repo must satisfy is
  [`docs/life-os-repo-standard.md`](docs/life-os-repo-standard.md), and
  `LabelRules.requiredLabelNames` is its single source of truth — the bootstrap
  script in `scripts/` is held to it by a test.
- **Project v2 fields are read-only.** The app reads Due Date / Defer Until; it
  sends no Project mutations. A token without `read:project` must degrade, not fail.
- **Test-first for Core logic.** New behavior in Core lands with a swift-testing
  test that failed before the change.
- **No suppressions.** No `// swift-format-ignore`, no disabled or deleted tests
  to get green. Weakening CI is an automatic blocker.
- **Workflow actions are SHA-pinned.** Org policy requires it — a tag-pinned
  `uses:` makes the run fail at startup. Pin the 40-char commit SHA with a
  `# vX.Y.Z` comment; Dependabot bumps them.

## Branching and PRs

`main` is the only long-lived branch and the default. Branch `feature/<issue>-<slug>`
or `fix/<slug>` off `main`; CI runs on every PR to `main`.

## PR evidence bar

A PR is reviewable only when its body shows:

1. The tracked issue it closes, and a one-sentence purpose. One concern per PR.
2. **Lint:** `swift format lint --strict …` exited 0 — zero warnings.
3. **Tests:** `swift test` and `xcodebuild test` output, with the pass count —
   the full suite, not a subset.
4. **Build:** the Release `xcodebuild build` exited 0.
5. For any UI change: a screenshot of the panel/window actually running.
6. For a bug fix: the regression test, and why it failed before.
7. Disclosure of AI assistance and its extent (standard 02, agent-PR etiquette).

Assertions are not evidence. Paste the command and its result.

## Where to read more

- [`docs/life-os-repo-standard.md`](docs/life-os-repo-standard.md) — what a task repo must contain, and how to bootstrap one
- [`openwiki/index.md`](openwiki/index.md) — wiki entry point
- [`openwiki/architecture/`](openwiki/architecture/overview.md) — target layout, sync path, label contract
- [`openwiki/decisions/`](openwiki/decisions/index.md) — why OAuth, Nexus, the macOS 26 floor, the configurable repo
- [`README.md`](README.md) — what it is, how to build and install
