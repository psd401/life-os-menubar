# Life OS Menubar

Native macOS menubar app fronting `krishagel/life-os` (GitHub Issues as tasks).

## Requirements

- macOS 15 or later
- Xcode 16 or later with Swift 6

## Build and test

```sh
swift test
swift format lint --strict --recursive Sources Tests
xcodebuild test \
  -project LifeOSMenubar.xcodeproj \
  -scheme LifeOSMenubar \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

The app runs as an accessory application with no Dock icon. Add a fine-grained
GitHub personal access token in Settings; it is stored only in the macOS
Keychain.
