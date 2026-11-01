# Life OS Menubar

Native macOS menubar app that turns a GitHub Issues repo into a task list you
can reach from anywhere, without opening a browser.

**Owner:** [@krishagel](https://github.com/krishagel) · **License:** [MIT](LICENSE)

## Why

GitHub Issues is already a good task store — labels, comments, Projects dates,
an API, and history for free. What it lacks is a two-second path to "what should
I do next?" and to capturing a thought before it is gone. This app is that path:
a menu bar item with a cached, filterable task panel, a Today count on the icon,
inline detail and actions, and a global quick-capture hotkey. It is a read-mostly
client over GitHub's API — GitHub stays the source of truth, and nothing here
holds state you cannot rebuild from the repo.

Today it reads `krishagel/life-os`. Making the task repo user-configurable is
tracked in [#21](https://github.com/psd401/life-os-menubar/issues/21); until that
lands, point it at your own repo by changing the `owner`/`repo` defaults in the
clients under `Sources/LifeOSMenubarCore/`.

## Requirements

- macOS 15 or later
- Xcode 16 or later with Swift 6
- A GitHub fine-grained personal access token with access to your task repo, and
  the `read:project` scope if you want the Today view's Project dates

## Build and test

```sh
# Lint (zero warnings required)
swift format lint --strict --recursive Sources Tests Package.swift

# Unit tests
swift test

# Full test run through the Xcode project
xcodebuild test \
  -project LifeOSMenubar.xcodeproj \
  -scheme LifeOSMenubar \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Install

There is no signed release yet (distribution is out of scope for v1.1), so build
and install it locally:

```sh
git clone https://github.com/psd401/life-os-menubar.git
cd life-os-menubar

xcodebuild build \
  -project LifeOSMenubar.xcodeproj \
  -scheme LifeOSMenubar \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO

cp -R build/Build/Products/Release/LifeOSMenubar.app /Applications/
open /Applications/LifeOSMenubar.app
```

Then open **Settings** from the panel and paste your token. The app runs as an
accessory application with no Dock icon — look for its menu bar item. The token
is stored only in the macOS Keychain, never on disk in the clear. Enable **Launch
at Login** in Settings if you want it always running.

To contribute, see [AGENTS.md](AGENTS.md) for the build/test/lint commands, the
architecture map, and the evidence a PR must carry.

## Task sync

The panel reads all open issues from `krishagel/life-os` through GitHub GraphQL
and groups them into Inbox, Next, Active, Waiting, Scheduled, and Someday.
Results are searchable by title and sorted by priority, then most-recent update.

Tasks are cached at:

```text
~/Library/Application Support/LifeOSMenubar/issues.json
```

The cache is loaded before the panel is shown, so tasks remain available during
network failures. Successful refreshes use the previous sync watermark to fetch
only changed issues. A full reconciliation runs at least once every 24 hours so
repo-wide label renames and other label metadata changes cannot leave the cache
stale indefinitely. Refresh runs when the panel opens, every five minutes while
the app is running, or when **Refresh** is selected in the panel.

## Filtering

Expand **Filters** beneath the search field to select values from the status,
priority, area, context, person, energy, estimate, and type label families.
Values come from labels in the local issue cache. Multiple values in one family
are combined with OR; selections in different families and the search query are
combined with AND. **Clear** removes every active filter in one action.

Enter a name and select **Save** to store the current selection. Saved filters
can be applied or deleted from the **Saved** menu. Active and saved filters are
restored across app launches from:

```text
~/Library/Application Support/LifeOSMenubar/filters.json
```

## Task detail and actions

Select a task to read its Markdown description, grouped labels, and complete
comment thread. Comments are loaded 100 at a time until every page is present
and are displayed chronologically.

Task changes use GitHub's REST API. The detail view can add a comment, change
status or priority, add or remove non-contract labels, and close a task.
Status and priority changes always normalize labels to exactly one
`status:*` and one `priority:*`; missing contract labels are repaired with
`status:inbox` and `priority:p2`. Closing sends `status:done`, the complete
normalized label set, and the closed state in one request. Local list and cache
state are updated only after GitHub accepts a mutation.

## Quick capture

Choose a global shortcut in Settings, then use it from any app to open the
keyboard-focused Quick Capture window. Enter a required title, optional notes,
and optionally override the default P2 priority. Creating a task writes it to
`krishagel/life-os` with `status:inbox`, `type:task`, `source:manual`, and the
selected `priority:*` label. Failed requests keep the draft intact so they can
be retried; Escape cancels and clears the draft.

## Today and Project fields

Each sync reads the **Due Date** and **Defer Until** date fields from the GitHub
Project v2 items attached to open tasks. The **Today** view includes tasks due
today or overdue, except tasks deferred until a later date. Project fields are
read-only: the app does not send Project v2 mutations.

Project date access requires the GitHub `read:project` scope. If the saved token
does not have that scope, normal task sync, filtering, detail actions, and quick
capture continue to work. The panel and Settings show a remediation message
until a token with `read:project` is saved.

The menu bar icon shows the unfiltered Today task count after each successful
sync. The badge can be disabled under **Settings → General**.

## Documentation

- [AGENTS.md](AGENTS.md) — build/test/lint commands, architecture map, PR evidence bar
- [openwiki/](openwiki/index.md) — architecture notes and the decision record
- [Contributing](https://github.com/psd401/.github/blob/main/CONTRIBUTING.md) and
  [Security policy](https://github.com/psd401/.github/blob/main/SECURITY.md) —
  org-wide defaults from `psd401/.github`

## Owner and license

Owned by [@krishagel](https://github.com/krishagel) (repo custom property
`owner`). Built to the [PSD engineering standards](https://github.com/psd401/psd-dev-standards).
Licensed under the [MIT License](LICENSE).
