---
okf_version: "0.1"
---

# Glossary

Terms used in this repo's code, issues, and wiki.

## Task model

**Task** — a GitHub issue in the task repo. The app never stores a task that does
not exist as an issue.

**Task repo** — the GitHub repo whose issues are the task list. Configured per
install as `owner/repo` (`TaskRepository`, stored in `UserDefaults`); there is no
default. What a conforming repo must contain is
[the task-repo standard](../docs/life-os-repo-standard.md); see
[decision 0005](decisions/0005-configurable-task-repo.md).

**Required label** — one of the thirteen label *definitions* a task repo must
already have (`LabelRules.requiredLabelNames`). `TaskRepositoryValidator` checks
them before Settings saves a repo; the app never creates them.

**Contract label** — a label in the `status:` or `priority:` family. Exactly one
of each must be present on every task; `LabelRules` enforces this on every write
and repairs a missing one to `status:inbox` / `priority:p2`. Contract labels can
only be changed through their dedicated control, never the generic label editor.

**Non-contract label** — any other label. The families the filter UI understands
are `area`, `context`, `person`, `energy`, `estimate`, and `type`
(`TaskFilterFamily`). Values are discovered from the local cache, not hardcoded.

**Status section** — one of the six panel sections, in fixed order: Inbox, Next,
Active, Waiting, Scheduled, Someday (`TaskStatusSection`). Each maps to
`status:<name>`.

**Today** — the derived view of tasks due today or overdue, excluding tasks
deferred to a later date. Drives the menu bar badge count.

**Project fields** — the Due Date and Defer Until date fields on the GitHub
Project v2 items attached to open issues. Read-only; requires the `read:project`
token scope. See `ProjectFields`.

## Sync

**Snapshot** — `IssueCacheSnapshot`: the cached issue list plus the
`lastSyncedAt` and `lastFullSyncedAt` watermarks and the project-field access
level. Persisted as `issues.json`.

**Watermark** — `lastSyncedAt`, sent as `updatedAfter` so a refresh fetches only
changed issues.

**Delta refresh** — a watermarked fetch. Includes closed issues so closures can be
evicted from the cache.

**Full reconcile** — an unwatermarked fetch, run on first sync and at least every
24 hours. Necessary because label metadata changes (a repo-wide rename) need not
bump an issue's `updatedAt`, so a delta-only cache could stay stale forever.

**Project-field access** — `.available`, `.missingScope`, or `.unknown`. Decides
whether project dates are applied, cleared, or left untouched on merge.

## Repo and process

**DoD / verify gate** — the Definition of Done in `.psd/verify.json`: the build,
lint, and test commands that must pass. Mirrors CI.

**Evidence bar** — what a PR body must show for the change to be reviewable.
Defined in [AGENTS.md](../AGENTS.md).

**SHA pinning** — pinning a GitHub Action to a full commit SHA instead of a tag.
Required org-wide; a tag-pinned action makes the workflow run fail at startup.

**Accessory app** — a macOS app with `LSUIElement = true`: menu bar presence, no
Dock icon, no app switcher entry.

**Tier C / `c-experiment`** — the repo's org custom property. A single-maintainer
experiment, not a service with an SLA.
