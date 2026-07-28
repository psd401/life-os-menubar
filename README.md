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
