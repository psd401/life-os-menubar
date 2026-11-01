---
okf_version: "0.1"
---

# life-os-menubar wiki

Reference notes for the Life OS menubar app — a native macOS menu bar client over
a GitHub Issues repo used as a task list. Start with [AGENTS.md](../AGENTS.md) for
the commands and the architecture map; this wiki holds the depth behind it.

Owner: `krishagel` · Tier: `c-experiment` · Lifecycle: `active` · IaC: `none`

# Files

- [Glossary](glossary.md) — the label families, contract labels, and app-specific terms.

# Directories

- [architecture](architecture/) — targets, layering, the sync path, the label contract, and repo plumbing.
- [decisions](decisions/) — the decision record: what was chosen, when, and why.

# Quick orientation

| Question | Answer |
|----------|--------|
| What builds the shippable app? | The Xcode project (`LifeOSMenubar.xcodeproj`), scheme `LifeOSMenubar`. `Package.swift` builds the same sources for fast `swift test` runs. |
| Where does testable logic live? | `Sources/LifeOSMenubarCore` — no AppKit, no SwiftUI. |
| Where is the GitHub token? | The macOS Keychain only, via `KeychainTokenStore`. |
| What is the only long-lived branch? | `main`. `dev` was merged into `main` and deleted (see [branch unification](decisions/0001-single-main-branch.md)). |
| Where is the verify gate defined? | [`.psd/verify.json`](../.psd/verify.json) — the same commands `.github/workflows/ci.yml` runs. |
