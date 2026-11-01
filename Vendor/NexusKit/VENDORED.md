# NexusKit — vendored copy

This directory is a **verbatim copy** of the NexusKit SwiftUI package from the
PSD design-system repo. It is a local SwiftPM package (`.package(path:)` in
[`Package.swift`](../../Package.swift), `XCLocalSwiftPackageReference` in
`LifeOSMenubar.xcodeproj`).

| | |
|---|---|
| Source repo | `psd401/psd-dev-standards` (internal) |
| Source path | `design-system/nexus/apple/NexusKit` |
| Source commit | `2cf88797ac80afc61c51cf1e2dedb81386514fd6` ([psd-dev-standards#194](https://github.com/psd401/psd-dev-standards/pull/194): Xcode 26.6 type-check fix in `NexusGallery2.swift`) |
| Vendored on | 2026-11-01 (first copy 2026-10-31, from `4affbd159b3db58a8fc34c3ac6fdc7a13eec1eac`) |
| Vendored for | [#19](https://github.com/psd401/life-os-menubar/issues/19) |

## Do not edit anything in this directory

Changes flow one way: design-system artifact → `psd-dev-standards` →
here. A local edit forks the design system, which is the exact failure
[decision 0003](../../openwiki/decisions/0003-nexus-design-system.md) adopts a
shared package to avoid. `VENDORED.md` is the only file in `Vendor/NexusKit/`
that this repo owns.

## Refreshing the copy

```sh
# From the repo root. Replace <sha> with the commit you are vendoring.
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/psd401/psd-dev-standards.git /tmp/psd-dev-standards
git -C /tmp/psd-dev-standards sparse-checkout set design-system/nexus
git -C /tmp/psd-dev-standards rev-parse HEAD        # record this as the source commit

rm -rf Vendor/NexusKit/Sources Vendor/NexusKit/Package.swift Vendor/NexusKit/README.md
cp -R /tmp/psd-dev-standards/design-system/nexus/apple/NexusKit/. Vendor/NexusKit/
# Then update the source commit in the table above and re-run the verify gate.
```

Verify the copy is unmodified with:

```sh
diff -r /tmp/psd-dev-standards/design-system/nexus/apple/NexusKit Vendor/NexusKit \
  | grep -v 'VENDORED.md'
```

## Floor

NexusKit declares `swift-tools-version: 6.2` and
`platforms: [.iOS(.v26), .macOS(.v26)]`. That is where this app's macOS 26
deployment floor comes from — see
[decision 0004](../../openwiki/decisions/0004-macos-26-floor.md).
