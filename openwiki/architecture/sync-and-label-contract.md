---
okf_version: "0.1"
---

# Sync path and the label contract

## The label contract

The app treats two label families as a contract every task must satisfy:

| Family | Prefix | Cardinality | Repaired to |
|--------|--------|-------------|-------------|
| Status | `status:` | exactly one | `status:inbox` |
| Priority | `priority:` | exactly one | `priority:p2` |

`LabelRules` repairs tasks; it does not create label *definitions*. The thirteen
definitions a task repo must already carry are
`LabelRules.requiredLabelNames` — the six status sections plus `status:done`, the
four priorities, `type:task`, and `source:manual` — checked by
`TaskRepositoryValidator` before Settings will save a repo, and created by
`scripts/bootstrap-task-repo.sh`. Without the definitions, repair still writes
the names, but filtering and grouping show empty sections
([the task-repo standard](../../docs/life-os-repo-standard.md)).

`LabelRules` is the only place the cardinality rule is enforced, and it enforces it on every
write path. `changingStatus`, `changingPriority`, and `editingNonContractLabel`
all funnel through one `normalized(_:status:priority:)` pass that:

- keeps the first `status:*` / `priority:*` slot and drops any duplicates,
- substitutes the requested override into that slot,
- appends the default when the family is missing entirely,
- preserves non-contract labels and their order.

`editingNonContractLabel` refuses a contract label outright
(`contractLabelRequiresDedicatedControl`) — a `status:*` or `priority:*` label can
only change through its dedicated control, never through the generic label editor.
Blank names are rejected. This is why the detail view has separate status and
priority pickers rather than a free-form label field.

Non-contract families exist but are read-only metadata used for filtering:
`area`, `context`, `person`, `energy`, `estimate`, `type` (`TaskFilterFamily`).
Filter values are discovered from the labels present in the local cache — nothing
is hardcoded, so a new label family value appears in the filter UI after the next
sync.

## Status sections

`TaskStatusSection` maps one-to-one onto the status labels and fixes the panel's
section order: `inbox`, `next`, `active`, `waiting`, `scheduled`, `someday`.
`TaskListPresentation.sections` filters to open issues that match both the search
query and the active filter selection, then buckets them by status label.

Filter semantics: multiple selected values **within** one family are OR'd;
different families and the search text are AND'd.

## The sync path

`IssueSyncEngine` is an `actor`; `refresh(token:)` is the whole read path.

1. Load the existing `IssueCacheSnapshot` (or `.empty`).
2. Decide full vs. delta. A **full** refresh happens when there is no
   `lastSyncedAt`, or when `lastFullSyncedAt` is at least `fullRefreshInterval`
   (default 24 h) old. Otherwise it sends `lastSyncedAt` as the watermark.
3. Fetch issues through the GraphQL client. A delta fetch deliberately includes
   **closed** issues so closures can be removed from the cache.
4. Fetch Project v2 date fields, if a project-field client is configured.
5. Merge:
   - full → keep only `.open` issues from the response;
   - delta → `merge(existing:updates:)` keeps open issues, replaces updated ones
     (preserving their already-known project fields via
     `preservingProjectFields(from:)`), and **removes** any issue that came back
     `.closed`.
6. Apply project fields by access level — `.available` overwrites each issue's
   fields (absent issues get empty fields), `.missingScope` clears them all,
   `.unknown` leaves them untouched.
7. Sort by issue number, stamp the watermarks, save, and return the snapshot.

The periodic full reconcile is the important subtlety: a watermark-only sync
cannot see repo-wide label renames or other label metadata edits that do not bump
an issue's `updatedAt`, so without it the cache could stay stale indefinitely.

Refresh is triggered when the panel opens, every five minutes while the app
runs, and from the panel's **Refresh** action.

## Mutations

Mutations go through REST (`GitHubIssueMutationClient`), not GraphQL. The rules:

- Every mutation sends the **complete normalized label set**, not a delta.
- Closing a task sends `status:done`, the normalized labels, and the closed state
  in **one** PATCH — not three requests that can half-fail.
- Local list and cache state are updated **only after** GitHub accepts the
  mutation. There is no optimistic UI.
- Quick capture creates with `status:inbox`, `type:task`, `source:manual`, and the
  selected `priority:*`. A failed create keeps the draft so it can be retried.

## Project v2 fields

Read-only. Each sync reads **Due Date** and **Defer Until** from the Project v2
items attached to open issues. The Today view = due today or overdue, minus
anything deferred to a later date. Project reads need the `read:project` scope; a
token without it must degrade — sync, filtering, detail actions, and quick
capture keep working, and the UI shows a remediation message. The app never sends
a Project v2 mutation.

## Failure posture

The cache is loaded before the panel is shown, so tasks remain visible through a
network failure. A failed refresh leaves the last good snapshot in place.
