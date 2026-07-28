# Life OS Menubar

Native macOS menubar app fronting `krishagel/life-os` (GitHub Issues as tasks).

## Requirements

- macOS 15 or later
- Xcode 16 or later with Swift 6

## Build and test

```sh
swift test
swift format lint --strict --recursive Sources Tests Package.swift
xcodebuild test \
  -project LifeOSMenubar.xcodeproj \
  -scheme LifeOSMenubar \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

The app runs as an accessory application with no Dock icon. Add a fine-grained
GitHub personal access token in Settings; it is stored only in the macOS
Keychain.

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
