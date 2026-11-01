---
okf_version: "0.1"
---

# Repo plumbing

What enforces quality on this repo, and where each piece lives.

## Branches

`main` is the default branch and the only long-lived branch. `dev` held all of v1
and was merged into `main` (merge commit, history preserved) and deleted — see
[decision 0001](../decisions/0001-single-main-branch.md). Work branches are
`feature/<issue>-<slug>` or `fix/<slug>`, cut from `main`, merged by PR.

## CI

`.github/workflows/ci.yml` — `CI / Swift validation`, `macos-15`, 20-minute
timeout, triggered on `pull_request` and `push` to `main`. Four steps, in order:

1. `swift format lint --strict --recursive Sources Tests Package.swift`
2. `swift test`
3. `xcodebuild test … -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
4. `xcodebuild build -configuration Release … CODE_SIGNING_ALLOWED=NO`

`CODE_SIGNING_ALLOWED=NO` is what lets an unsigned runner build and test the app;
signing and notarization are a separate pipeline and out of scope here.

Also on the repo: `claude-code-review.yml` (AI review on every PR) and
`claude.yml` (responds to `@claude` mentions), both using
`anthropics/claude-code-action`, plus GitHub's CodeQL default setup.

### Actions must be SHA-pinned

The `psd401` org sets `sha_pinning_required: true` on Actions. A workflow that
pins an action by tag (`actions/checkout@v6`) does not fail a step — the whole run
fails at startup with "This run likely failed because of a workflow file issue."
This is exactly how `claude.yml` was failing before this repo was standardized.

Pin the full 40-character commit SHA and leave the human-readable version in a
trailing comment:

```yaml
uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6.1.0
```

Dependabot keeps pinned SHAs current, so the comment is the only thing a human
needs to read.

Allowed actions are restricted org-wide to a pattern list that includes
`anthropics/*` and GitHub-owned actions; an action outside it will also fail at
startup.

## Dependabot

`.github/dependabot.yml` covers two ecosystems, both weekly on Monday:

| Ecosystem | What it updates | Commit prefix |
|-----------|-----------------|---------------|
| `swift` | the SwiftPM dependency (`KeyboardShortcuts`), via `Package.resolved` | `chore(deps)` |
| `github-actions` | the pinned action SHAs in `.github/workflows/` | `chore(ci)` |

`target-branch` is deliberately **not** set. `main` is the default branch so it
would be redundant — and setting `target-branch` also turns off Dependabot
security updates for that ecosystem, which is a real loss for no gain.

Note that `Package.swift` pins `KeyboardShortcuts` with `exact:`, so a Dependabot
bump has to change `Package.swift` as well as the resolved files — review those
PRs rather than merging them blind.

## The verify gate

`.psd/verify.json` is the machine-checkable Definition of Done, read by the
`psd-coding-system` plugin's gate script and its Stop hook. It mirrors CI:

| Key | Command |
|-----|---------|
| `build` | the Release `xcodebuild build` |
| `lint` | `swift format lint --strict …` |
| `test` | `swift test && xcodebuild test …` |

There is intentionally **no `typecheck`** command: in Swift the compile *is* the
typecheck, so a separate step would only duplicate `build`. The gate skips keys
that are not configured.

`e2e_required` is `false` — this is a native menu bar app with no browser surface,
so there is no Playwright equivalent to run. UI changes are verified by a
screenshot of the running app instead (see the PR evidence bar in
[AGENTS.md](../../AGENTS.md)).

`commit_learnings` is `false` because this is a public repo; agent session notes
stay out of its history.

## Community health files

This repo carries only `LICENSE` (MIT) locally. `CONTRIBUTING.md`,
`SECURITY.md`, `CODE_OF_CONDUCT.md`, and the pull-request template all resolve
from the org-wide defaults in
[`psd401/.github`](https://github.com/psd401/.github) — GitHub falls back to that
repo for any member repo that has no local copy. Verified via
`gh api repos/psd401/life-os-menubar/community/profile`, whose `html_url` for each
file points into `psd401/.github`. Add a local copy only to say something that
differs from the org default.

## Repo properties

Set at the org level, not in the repo: `tier: c-experiment`,
`lifecycle: active`, `owner: krishagel`, `iac: none`, plus discovery topics.
Visibility is public; the license is MIT.
