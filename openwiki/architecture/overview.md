---
okf_version: "0.1"
---

# Architecture overview

## Two targets, one dependency edge

| Target | Path | Contains | Tested |
|--------|------|----------|--------|
| `LifeOSMenubarCore` | `Sources/LifeOSMenubarCore` | Models, GitHub clients, sync engine, stores, view models. No AppKit, no SwiftUI. | Yes — `Tests/LifeOSMenubarCoreTests`, swift-testing suites |
| `LifeOSMenubar` | `Sources/LifeOSMenubarApp` | AppKit/SwiftUI shell: status item, panel, detail, settings, quick capture. Depends on Core, `KeyboardShortcuts`, and NexusKit. | No — by design |

The split exists so the whole task-management behavior is testable without a
running UI. Anything with a branch in it belongs in Core; the App target is
composition and presentation only. The App target is deliberately untested, so
putting logic there means putting it beyond the test gate.

`Package.swift` (swift-tools 6.2, platform `.macOS(.v26)`) and the Xcode project
build the same sources. The Xcode project is what produces the `.app`; SwiftPM is
what makes `swift test` fast. Both must stay green — see
[repo-plumbing.md](repo-plumbing.md).

Two dependencies:

- `sindresorhus/KeyboardShortcuts`, pinned to an exact version in
  `Package.swift` (Dependabot bumps it), used only for the global quick-capture
  hotkey.
- **NexusKit**, vendored at `Vendor/NexusKit/` as a local SwiftPM package — the
  Nexus design system's SwiftUI tokens and components. It is a verbatim copy of
  `design-system/nexus/apple/NexusKit` from `psd401/psd-dev-standards`;
  [`Vendor/NexusKit/VENDORED.md`](../../Vendor/NexusKit/VENDORED.md) records the
  source commit and the refresh procedure. **Nothing in that directory is ever
  hand-edited** — changes flow one way, from the design system down. NexusKit is
  also where the macOS 26 floor comes from
  ([decision 0004](../decisions/0004-macos-26-floor.md)).

The App target takes every color, font, spacing, radius, and motion value from
NexusKit (`NexusFont`, `NexusSpace`, `NexusRadius`, `NexusSize`, `NexusMotion`,
and the palette on `@Environment(\.nexus)`). `LifeOSMenubarCore` does not import
NexusKit and must not: the design system is presentation, and Core has no
presentation in it.

## Core, by layer

```
Model      LifeOSIssue · IssueDetail · ProjectFields · TaskFilter · LabelRules
Clients    GitHubIssueClient · GitHubIssueDetailClient · GitHubIssueMutationClient
           GitHubProjectFieldClient · GitHubTokenValidator
Sync       IssueSyncEngine (actor)
Storage    IssueCacheStore · TaskFilterStore · KeychainTokenStore
           MenuBarCountPreferenceStore · LaunchAtLoginController
ViewModel  TaskListViewModel · TaskDetailViewModel · SettingsViewModel · QuickCaptureViewModel
```

Every client sits behind a protocol (`GitHubIssueFetching`,
`GitHubProjectFieldFetching`, `IssueCacheStoring`, …) so tests inject a fake and
no test ever touches the network. Reads go through GitHub's **GraphQL** API;
mutations go through **REST**. View models are `@MainActor`; the sync engine is an
`actor`.

## The App target's composition root

`LifeOSMenubarMain` installs `AppDelegate`, which is the single place anything is
constructed. `applicationDidFinishLaunching` sets the activation policy to
`.accessory`, builds the stores, clients, sync engine, and view models, and wires
them into:

- `StatusItemController` — the menu bar item and its count badge (Today, Inbox
  or off, per Settings). Its badge renderer is deliberately outside the Nexus palette: the image is a
  **template** image, so its black is a mask macOS tints to match the menu bar
- `PanelController` + `PanelView` — the task panel, with `TaskDetailView` inside
- `SettingsWindowController` + `SettingsView` — token entry, the task repository
  field and its validation, launch at login, the menu bar count picker
- `QuickCaptureWindowController` + `QuickCaptureView` — the global-hotkey capture window

It then starts background refresh and kicks a first refresh. There is no DI
container and no service locator: if a new collaborator is needed, it is
constructed here and passed down.

`Resources/Info.plist` sets `LSUIElement = true`, which is what makes the app an
accessory with no Dock icon. `applicationShouldTerminateAfterLastWindowClosed`
returns `false` so closing the panel does not quit.

## On-disk state

| Path | Written by | Contents |
|------|-----------|----------|
| `~/Library/Application Support/LifeOSMenubar/issues.json` | `IssueCacheStore` | The task cache snapshot and sync watermarks |
| `~/Library/Application Support/LifeOSMenubar/filters.json` | `TaskFilterStore` | Active and saved filters |
| macOS Keychain, service `com.krishagel.LifeOSMenubar` | `KeychainTokenStore` | The GitHub token — **nowhere else** |

All of it is reconstructible from the task repo plus a token. Nothing here is a
system of record.

## How the task repo reaches the clients

There is **no default repository anywhere in `Sources/`**
([decision 0005](../decisions/0005-configurable-task-repo.md),
[#21](https://github.com/psd401/life-os-menubar/issues/21)). All four GitHub
clients take a `TaskRepositoryStoring` and resolve the configured repo with
`requireRepository()` on **every request**, which has two consequences worth
knowing:

- Saving a new repo in Settings takes effect immediately — the clients are not
  rebuilt, and nothing caches the slug.
- An unconfigured install throws `TaskRepositoryConfigurationError.notConfigured`
  before any network call. `PanelView` shows a setup card for that state instead
  of an empty task list, and `SettingsView`'s "Task repository" section is where
  it gets fixed.

The slug lives in `UserDefaults` under `taskRepository`
(`UserDefaultsTaskRepositoryStore`) — it is in every API URL the app sends, so it
is not a secret and does not belong in the Keychain.

`TaskRepositoryValidator` is what Settings calls before saving: it lists the
repo's labels over REST, which proves access and conformance in one request, and
a repo that fails is never written to the store. The required label set is
`LabelRules.requiredLabelNames`, derived from `TaskStatusSection` plus
`status:done`, the four priorities, `type:task`, and `source:manual`, and
documented in [the task-repo standard](../../docs/life-os-repo-standard.md).

Changing the repo also clears the issue cache
(`TaskListViewModel.resetForRepositoryChange()`): the cache is keyed by issue
number only, so the old repo's tasks would otherwise sit beside the new repo's,
and the delta watermark would suppress the fetch that could correct it.

The Keychain service string is still `com.krishagel.LifeOSMenubar`. It is
deliberately **not** renamed: it is an identifier, not a task-repo default, and
changing it orphans every already-stored token (decision 0005).

## See also

- [The Life OS task-repo standard](../../docs/life-os-repo-standard.md)
- [Sync and the label contract](sync-and-label-contract.md)
- [Repo plumbing](repo-plumbing.md)
- [Decisions](../decisions/index.md)
