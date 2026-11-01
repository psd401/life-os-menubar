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

You point it at your own task repo in Settings. What that repo has to look like
— the label contract, the optional filter families, the optional Project v2 date
fields, and a bootstrap script for a fresh repo — is documented in
[the Life OS task-repo standard](docs/life-os-repo-standard.md). The app ships no
default repository: an install with nothing configured says so and sends you to
Settings.

## Requirements

- macOS 26 or later — the NexusKit design-system package sets this floor
  ([decision 0004](openwiki/decisions/0004-macos-26-floor.md))
- Xcode 26 or later with Swift 6.2
- A GitHub account that can reach your task repo, and one of the two sign-in
  paths below

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

# Release build
xcodebuild build \
  -project LifeOSMenubar.xcodeproj \
  -scheme LifeOSMenubar \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

These four are exactly what CI runs — see `.github/workflows/ci.yml` and
`.psd/verify.json`. The install steps below add `-derivedDataPath build` to the
same release build so the output lands somewhere predictable.

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

rm -rf /Applications/LifeOSMenubar.app
ditto build/Build/Products/Release/LifeOSMenubar.app /Applications/LifeOSMenubar.app
open /Applications/LifeOSMenubar.app
```

Remove the old bundle first and copy with `ditto` rather than `cp -R`: copying a
`.app` directory over an existing one **merges** the two, which leaves stale
binaries and resources from the previous build inside the bundle and fails
silently. This matters on every upgrade, not just the first install.

### First run: connect a task repo

The app has no task repository until you choose one, and the panel shows a setup
card until you do.

1. **Create or pick a task repo.** Any GitHub repo you can read, with issues
   enabled — private is recommended. It needs no code.
2. **Bootstrap its labels.** The app validates the label contract and never
   creates it:

   ```sh
   # Preview the commands without touching the repo:
   scripts/bootstrap-task-repo.sh --repo owner/repo --dry-run

   # Create the 13 required labels:
   scripts/bootstrap-task-repo.sh --repo owner/repo
   ```

   The copy-paste `gh label create` equivalent is in
   [the standard](docs/life-os-repo-standard.md#6-bootstrap-a-fresh-repository).
3. **Sign in.** Open **Settings** from the panel's `…` menu and either select
   **Sign in with GitHub** or open **Advanced** and paste a token. See
   [Signing in](#signing-in) for what each path grants. Either way, the token is
   stored only in the macOS Keychain, never on disk in the clear and never in a
   log.
4. **Save the repo.** Under **Task repository**, enter `owner/repo` and select
   **Save and validate repository**. Validation confirms the token can read the
   repo and that every required label exists, and names anything missing. A repo
   that fails validation is not saved.

Enable **Launch at Login** in Settings if you want it always running.

Full details, including the optional label families and Project v2 fields, are in
[the Life OS task-repo standard](docs/life-os-repo-standard.md).

**If nothing seems to happen:** that is expected. The app is an accessory
application — no Dock icon, no app-switcher entry, no window on launch. Its only
affordance is a menu bar item, which is easy to miss on a crowded menu bar.
Confirm it is running with `pgrep -x LifeOSMenubar`.

The build is unsigned (`CODE_SIGNING_ALLOWED=NO`). A locally built app carries no
quarantine attribute, so Gatekeeper does not block it — but it is also not
notarized, so do not expect it to survive being zipped and sent to another Mac.
Signing and notarization are out of scope for v1.1.

To contribute, see [AGENTS.md](AGENTS.md) for the build/test/lint commands, the
architecture map, and the evidence a PR must carry.

## Signing in

There are two paths, and they trade convenience against blast radius. Pick with
the table in front of you rather than taking the default blind.

| | **Sign in with GitHub** (default) | **Use a token instead** (advanced) |
|---|---|---|
| How | Settings → **Sign in with GitHub**. The app shows a code, opens `github.com/login/device`, you approve, done. | Settings → **Advanced → Use a token instead**. Paste a fine-grained personal access token. |
| What it grants | Classic scopes `repo` and `read:project`. | Exactly what you scope the token to. |
| Breadth | **Broad.** `repo` grants **read and write on every repository your GitHub account can reach** — public, private, and every organization repository your account has access to. There is no narrower classic scope that can read and write issues on a private repo. | **Narrow.** Scope it to **Issues: read and write** on your one task repository and the app can do nothing else, anywhere. |
| Today view and the Today menu bar count | Works. `read:project` reaches your user-owned Project v2 dates. | **Off.** Fine-grained tokens expose Projects as an organization-only permission, so a user-owned project is unreachable. Settings says so; everything else works. |
| Expiry | None. OAuth App tokens do not expire. | Whatever expiry you set on the token. |

Both paths end in the same place: the token goes into the macOS Keychain
(`KeychainTokenStore`) and nowhere else. **Sign out** in Settings removes the
Keychain item. A token saved by an earlier version of the app keeps working
after an update — there is no forced re-authentication — until you sign out.

Why `repo` at all: the Today view needs **user-owned** Projects v2, which only a
classic scope can reach. Fine-grained tokens cannot, and a GitHub App cannot
either (verified 2026-10-31). The reasoning is in
[decision 0002](openwiki/decisions/0002-oauth-device-flow.md).

### Registering the OAuth App (one time, by the repo owner)

Device-flow sign-in needs an OAuth App to point at. Its **client ID is public by
design** — the device flow has no client secret, and the ID alone authorizes
nothing until a user approves a code — so it ships as the single constant
`GitHubOAuthApp.clientID` in `Sources/LifeOSMenubarCore/DeviceFlowClient.swift`.
It is not a secret and does not belong in the Keychain or Secrets Manager.

1. Go to the **psd401** org → **Settings** → **Developer settings** →
   **OAuth Apps** → **New OAuth App**.
2. **Application name:** `Life OS Menubar`. **Homepage URL:** this repository's
   URL.
3. **Authorization callback URL:** required by the form but unused — the device
   flow never redirects. Any `https` URL you control is fine; the homepage URL
   works.
4. Register the app, then open it and tick **Enable Device Flow**. Sign-in
   returns `device_flow_disabled` without this.
5. Copy the **Client ID** into `GitHubOAuthApp.clientID` and open a PR. Do not
   generate a client secret; nothing in this app uses one.

This is done: the psd401 app "Life OS Menubar" is registered with Device Flow
enabled, and its client ID `Ov23liwioDuanmFQLbcZ` is in the constant. The steps
stay here for anyone who forks the app and registers their own. If the constant
is empty, **Sign in with GitHub** is disabled and Settings explains why; the
advanced token path works regardless.

## Task sync

The panel reads all open issues from your configured task repo through GitHub
GraphQL and groups them into Inbox, Next, Active, Waiting, Scheduled, and Someday.
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
the configured task repo with `status:inbox`, `type:task`, `source:manual`, and
the selected `priority:*` label. Failed requests keep the draft intact so they can
be retried; Escape cancels and clears the draft.

## Today and Project fields

Each sync reads the **Due Date** and **Defer Until** date fields from the GitHub
Project v2 items attached to open tasks. The **Today** view includes tasks due
today or overdue, except tasks deferred until a later date. Project fields are
read-only: the app does not send Project v2 mutations.

Project date access requires the GitHub `read:project` scope, which only the
device-flow path grants (see [Signing in](#signing-in)). Without it — the normal
state of the advanced fine-grained-token path — task sync, filtering, detail
actions, and quick capture all continue to work; only Today and the menu bar
count are off. The panel and Settings say so and point at sign-in as the remedy.

The menu bar icon shows a count you pick under **Settings → General → Menu bar
count**:
- **Today** (the default): open tasks due today or overdue.
- **Inbox**: tasks in Inbox.
- **Off**: no count.

Either count ignores the panel's search and filters, and it updates after each
successful sync.

## Documentation

- [docs/life-os-repo-standard.md](docs/life-os-repo-standard.md) — what a task repo must contain, and how to bootstrap one
- [AGENTS.md](AGENTS.md) — build/test/lint commands, architecture map, PR evidence bar
- [openwiki/](openwiki/index.md) — architecture notes and the decision record
- [Contributing](https://github.com/psd401/.github/blob/main/CONTRIBUTING.md) and
  [Security policy](https://github.com/psd401/.github/blob/main/SECURITY.md) —
  org-wide defaults from `psd401/.github`

## Owner and license

Owned by [@krishagel](https://github.com/krishagel) (repo custom property
`owner`). Built to the [PSD engineering standards](https://github.com/psd401/psd-dev-standards).
Licensed under the [MIT License](LICENSE).
