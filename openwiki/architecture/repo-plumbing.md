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

`.github/workflows/ci.yml` — `CI / Swift validation`, `xcode-27`, 20-minute
timeout, triggered on `pull_request` and `push` to `main`. A change that touches
only docs (`**/*.md`, `openwiki/**`, `docs/**`, `.verification/**`, `LICENSE`)
skips it, so docs don't spend macOS runner minutes. CodeQL default setup is not
affected and still scans every PR. Four steps, in order:

1. `swift format lint --strict --recursive Sources Tests Package.swift`
2. `swift test`
3. `xcodebuild test … -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
4. `xcodebuild build -configuration Release … CODE_SIGNING_ALLOWED=NO`

`CODE_SIGNING_ALLOWED=NO` is what lets an unsigned runner build and test the app;
signing and notarization are a separate pipeline and out of scope here.

The runner is `xcode-27` (macOS 27 / Xcode 27), the toolchain the app is
developed against — see [decision 0004](../decisions/0004-macos-26-floor.md).
`macos-26` (Xcode 26.6) failed on a vendored NexusKit preview file until NexusKit
`2cf8879` fixed it upstream; Xcode 26.6 now builds the app, and CodeQL's autobuild
(below) proves that on every PR. `xcode-27` is a preview image today; move to
the stable macOS 27 label when there is one.

### AI review

`claude-review.yml` is the org's caller template, copied unchanged from
`psd401/.github` `workflow-templates/claude-review.yml`. It calls the org
reusable `reusable-claude-review.yml`, pinned by SHA, on every push to a PR.
The reusable runs Claude Haiku 5.5 on Amazon Bedrock with the org
`BEDROCK_API_KEY` secret and posts one severity-tiered comment as
`claude[bot]` (standards/03). Dependabot PRs get a no-op job with the same
`claude-review` name instead, because Dependabot runs cannot grant
`id-token: write`. To change the prompt or model, change the reusable
upstream; this repo only bumps the pin.

The stock Anthropic `claude-code-review.yml` it replaced never posted
anything: it allowed the agent no `gh` commands, so each run ended "success"
with permission denials and the review stayed in the hidden job log.

`claude-code-action` validates that the workflow file in the PR is
**identical to the copy on the default branch**, and skips itself when it is
not. A PR that edits `claude-review.yml` therefore gets no review posted —
the job logs "Skipping action due to workflow validation". That is a
deliberate safety measure, not a failure. Reviews resume on the next PR that
leaves the workflow alone.

`claude.yml` responds to `@claude` mentions and still uses
`anthropics/claude-code-action` directly.

GitHub's Copilot code reviewer also reviews PRs here, but only when it is
requested (it reviewed #25 and #26). `.psd/verify.json`'s `reviewers` lists
only `claude[bot]`, which posts on every PR. Do not add a login that posts only
on request, or the watch-until-clean loop will spin waiting for it.

### CodeQL

CodeQL runs as GitHub default setup. The org's enforced "PSD Baseline -
Public" security configuration requires default setup and disallows advanced
setup (`allow_advanced: false`), so this repo cannot carry its own CodeQL
workflow or a `paths-ignore` config — standards/04 rule 1. Default setup
autobuilds Swift on GitHub's standard macOS runner with that image's default
Xcode (`macos-26-arm64`, Xcode 26.6, as of 2026-11-01), so everything the app
compiles, vendored code included, must build with that toolchain.

NexusKit at `4affbd15` did not: the `#Preview` at
`Vendor/NexusKit/Sources/NexusKit/NexusGallery2.swift:223` failed to type-check
on Xcode 26.6, and `Analyze (swift)` failed. Moving the scan to `xcode-27` was no
way out: Xcode 27 ships Swift 6.4, and CodeQL supports Swift up to 6.3. So the
fix went upstream — the Nexus artifact, then
[psd-dev-standards#194](https://github.com/psd401/psd-dev-standards/pull/194),
re-vendored here at `2cf8879`. The standing lesson: a NexusKit change that
compiles only on Xcode 27 breaks this repo's code scanning.

Autobuild still reports one "Detected build command failed" diagnostic. It
builds with `xcodebuild -target`, which does not produce SwiftPM resource
bundles, so the last step — copying `KeyboardShortcuts_KeyboardShortcuts.bundle`
and `NexusKit_NexusKit.bundle` — fails after every Swift file has compiled. The
analysis itself succeeds. This predates NexusKit: `main` at v1 shows the same
diagnostic for the KeyboardShortcuts bundle.

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
| `swift` | the remote SwiftPM dependency (`KeyboardShortcuts`), via `Package.resolved` | `chore(deps)` |
| `github-actions` | the pinned action SHAs in `.github/workflows/` | `chore(ci)` |

`target-branch` is deliberately **not** set. `main` is the default branch so it
would be redundant — and setting `target-branch` also turns off Dependabot
security updates for that ecosystem, which is a real loss for no gain.

Note that `Package.swift` pins `KeyboardShortcuts` with `exact:`, so a Dependabot
bump has to change `Package.swift` as well as the resolved files — review those
PRs rather than merging them blind.

Dependabot does **not** see NexusKit. It is a vendored local package
(`.package(path: "Vendor/NexusKit")`), not a resolved remote one, so refreshing
it is a manual step — the procedure and the recorded source commit are in
[`Vendor/NexusKit/VENDORED.md`](../../Vendor/NexusKit/VENDORED.md).

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

`strictness` is `block`, which means an agent session running the
`psd-coding-system` plugin cannot finish until the gate is green. **The gate is
only satisfiable on macOS with Xcode installed** — two of its three commands are
`xcodebuild`. An agent working from a Linux container cannot run it and will
block with no path to green; that is the right answer for a macOS-only app, but
it means agent-assisted work on this repo has to happen on a Mac. For anyone
without the plugin the file is inert: nothing in CI reads `.psd/verify.json`.

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
