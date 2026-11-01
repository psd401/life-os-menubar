---
okf_version: "0.1"
---

# 0005 — Make the task repo user-configurable and publish the repo standard

**Date:** 2026-10-31 · **Status:** Accepted, not implemented
([#21](https://github.com/psd401/life-os-menubar/issues/21))

## Context

`krishagel/life-os` is hardcoded as a default parameter on every GitHub client:

```
Sources/LifeOSMenubarCore/GitHubIssueClient.swift:48          owner: String = "krishagel"
Sources/LifeOSMenubarCore/GitHubIssueDetailClient.swift:48    owner: String = "krishagel"
Sources/LifeOSMenubarCore/GitHubIssueMutationClient.swift:63  owner: String = "krishagel"
Sources/LifeOSMenubarCore/GitHubProjectFieldClient.swift:44   owner: String = "krishagel"
```

Two error messages name the repo in user-facing text, and
`KeychainTokenStore` uses `com.krishagel.LifeOSMenubar` as its service name.

The repo is now public. Anyone who clones it gets an app that points at a repo
they cannot read. Worse, the app assumes a task repo already shaped the right way
— the `status:` / `priority:` contract, the six status values, the filter label
families, and optionally Project v2 Due Date / Defer Until fields — and none of
that is written down anywhere a new user would find it.

## Decision

Two halves, and both are required for the app to be genuinely usable by someone
else:

1. **Configurable repo.** Owner and repo become a user setting, stored alongside
   the other preferences and threaded through the clients instead of defaulted.
2. **A written task-repo standard**, `docs/life-os-repo-standard.md`, covering the
   label families, the contract invariants, the optional Project v2 fields, and
   bootstrap commands that create a conforming repo from scratch. The acceptance
   bar is that a fresh repo built by following the doc works end to end with the
   app — not that the doc exists.

## Alternatives rejected

- **Configurable repo without the standard.** The app would accept any repo and
  then misbehave against one that lacks the contract labels. `LabelRules` repairs
  missing contract labels on write, but nothing creates the label *definitions*,
  so filtering and grouping would silently show empty sections.
- **Auto-provision the labels on first run.** Convenient, but it means the app
  writes schema into a user's repo on launch. A documented bootstrap the user
  runs deliberately is the smaller, more honest system.
- **Support multiple task repos in one install.** Out of scope for the epic; one
  repo per install until there is a reason for more.

## Consequences

- Every client's call sites change, and the clients stop carrying a default — a
  missing configuration becomes an explicit "not configured yet" state the UI has
  to handle rather than a silent fallback to someone else's repo.
- The two error strings that name `krishagel/life-os` must become generic or
  interpolate the configured repo.
- The Keychain service name is a migration hazard: changing it orphans the
  already-stored token. Either keep the existing service string as-is, or migrate
  deliberately — do not rename it as drive-by cleanup.
- README's "change the defaults in the clients" workaround is removed once this
  lands.
