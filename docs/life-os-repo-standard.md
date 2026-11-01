# The Life OS task-repo standard

What a GitHub repository must look like for Life OS Menubar to use its issues as
a task list, written for someone starting from nothing.

The app **validates** this standard and never creates it. When you save an
`owner/repo` in Settings, the app lists the repository's labels and refuses the
repository if any required label is missing, naming each one
([decision 0005](../openwiki/decisions/0005-configurable-task-repo.md)).

Terms used here are defined in the [glossary](../openwiki/glossary.md).

## 1. The repository

Any GitHub repository you can read, with issues enabled. Private is fine, and
recommended — a task list is personal. One repository per install; there is no
multi-repo mode.

Nothing else about the repository matters: it needs no code, no branches, and no
README. A repository created empty, used only for issues, is the normal case.

## 2. Required labels

Thirteen label definitions must exist. The app will not sync against a
repository that is missing any of them.

| Label | Meaning |
|-------|---------|
| `status:inbox` | Captured, not yet triaged. The default for anything the app creates. |
| `status:next` | Ready to work on next. |
| `status:active` | In progress right now. |
| `status:waiting` | Blocked on someone or something else. |
| `status:scheduled` | Starts on a date. |
| `status:someday` | Parked, no commitment. |
| `status:done` | Finished. The issue is also closed. |
| `priority:p0` | Drop everything. |
| `priority:p1` | Important this week. |
| `priority:p2` | Default priority. |
| `priority:p3` | Nice to have. |
| `type:task` | An actionable task. |
| `source:manual` | Created by a person, not an automation. |

The first six `status:` values are the panel's six sections, in that order.
`status:done` is not a section — a done task is closed and leaves the panel — but
closing a task writes the label, so the definition has to exist.

Label **colors and descriptions are yours to choose**; only the names are part
of the contract. Names are matched case-insensitively.

## 3. Contract invariants

These are enforced in code (`LabelRules`), not by convention:

- **Exactly one `status:*` and exactly one `priority:*` per task.** Every write
  the app makes normalizes the label set to one of each.
- **A missing contract label is repaired, not reported.** A task with no
  `status:*` is written back with `status:inbox`; with no `priority:*`, with
  `priority:p2`. This repairs tasks, not the repository — it never creates a
  label definition.
- **Contract labels change only through their own control.** The generic label
  editor in the task detail refuses a `status:` or `priority:` label.
- **Closing a task means `status:done` and closed**, sent in one request.
- **Comments are the audit trail.** The app appends comments and never edits or
  deletes an existing one.
- **GitHub is the source of truth.** Local list and cache state change only
  after GitHub accepts a mutation, and nothing the app stores locally cannot be
  rebuilt from the repository.

## 4. Optional label families

Beyond the contract, the filter UI understands these families and populates its
chips from whatever values your issues actually carry. Nothing here is required,
and no values are hardcoded — create the ones you want and ignore the rest.

| Family | Example values |
|--------|----------------|
| `area:` | `area:work`, `area:home`, `area:health` |
| `context:` | `context:office`, `context:errand`, `context:online` |
| `person:` | `person:jane`, `person:board` |
| `energy:` | `energy:high`, `energy:low` |
| `estimate:` | `estimate:5m`, `estimate:1h` |
| `type:` | `type:task` (required), plus any others you add |

A family with no labels in the cache shows "No labels in cache" and filters
nothing. Values in one family are combined with OR; different families and the
search query are combined with AND.

Labels outside these families are shown on a task and can be added or removed,
but they get no filter chips.

## 5. Optional Project v2 fields

The **Today** view and the menu bar's Today count come from two date fields on
the GitHub Project v2 items attached to your issues:

| Field name | Effect |
|------------|--------|
| `Due Date` | A task due today or overdue appears in Today. |
| `Defer Until` | A task deferred to a later date is held out of Today. |

Both are optional, and **read-only to the app** — it sends no Project v2
mutations. To use them: create a Project v2, add a date field named exactly
`Due Date` (and optionally `Defer Until`), and add your task issues to it.

Reading these fields from a Project you own requires the classic
**`read:project`** scope, which a fine-grained token cannot have (see
[Token scopes](#8-token-scopes)). Without it, task sync, filtering, detail
actions, and quick capture all keep working; the panel and Settings show a
message saying Today dates are unavailable.

## 6. Bootstrap a fresh repository

### With the script

```sh
# Print the commands without touching the repository:
scripts/bootstrap-task-repo.sh --repo owner/repo --dry-run

# Create the labels:
scripts/bootstrap-task-repo.sh --repo owner/repo
```

Re-running is safe: a label that already exists is left alone. Pass `--force`
to overwrite existing labels' colors and descriptions with the script's. Any
other failure — no write access, a mistyped repository, the network — is
printed as `FAILED` and the script exits non-zero.

The script needs the [GitHub CLI](https://cli.github.com) authenticated with
write access to the repository.

### By hand

The same thing, copy-paste, after `export REPO=owner/repo`:

```sh
gh label create status:inbox     --repo "$REPO" --color B60205 --description "Captured, not yet triaged"
gh label create status:next      --repo "$REPO" --color 0E8A16 --description "Ready to work on next"
gh label create status:active    --repo "$REPO" --color 1D76DB --description "In progress right now"
gh label create status:waiting   --repo "$REPO" --color FBCA04 --description "Blocked on someone or something else"
gh label create status:scheduled --repo "$REPO" --color 5319E7 --description "Starts on a date"
gh label create status:someday   --repo "$REPO" --color BFD4F2 --description "Parked, no commitment"
gh label create status:done      --repo "$REPO" --color 0E8A16 --description "Finished; the issue is closed"
gh label create priority:p0      --repo "$REPO" --color B60205 --description "Drop everything"
gh label create priority:p1      --repo "$REPO" --color D93F0B --description "Important this week"
gh label create priority:p2      --repo "$REPO" --color FBCA04 --description "Default priority"
gh label create priority:p3      --repo "$REPO" --color C5DEF5 --description "Nice to have"
gh label create type:task        --repo "$REPO" --color EDEDED --description "An actionable task"
gh label create source:manual    --repo "$REPO" --color EDEDED --description "Created by a person, not an automation"
```

### Check it yourself

The same request the app's validation makes:

```sh
gh api "repos/$REPO/labels?per_page=100" --jq '.[].name' | sort
```

## 7. Connect the app

1. Build and install the app (see the [README](../README.md#install)).
2. Open **Settings** from the panel's `…` menu.
3. Under **GitHub**, paste a token (see [Token scopes](#8-token-scopes) for
   which kind) and select **Save and validate token**. The token is stored
   only in your macOS Keychain.
4. Under **Task repository**, enter `owner/repo` and select
   **Save and validate repository**.

Validation either shows **Valid · owner/repo**, or says exactly what is wrong:
the repository does not exist or the token cannot see it, the token is not
allowed to read it, or these specific labels are missing. A repository that
fails validation is not saved, so the app never syncs against one it would
misread.

## 8. Token scopes

Pick one, by whether you want the Today view:

| Token | Grants | Today view |
|-------|--------|------------|
| **Fine-grained** personal access token, scoped to the task repository only: **Issues** read and write (GitHub adds **Metadata** read automatically) | Exactly that one repository's issues. The least-privilege choice. | **Off.** Fine-grained tokens can reach Projects only through an organization permission, so a Project you own is out of reach. |
| **Classic** personal access token with `repo` and `read:project` | `repo` is read *and write* on **every** repository your account can reach, including private and organization ones. | On. |

Everything except Today works the same on both.

## 9. Troubleshooting

| What you see | What it means |
|--------------|---------------|
| "No task repository is configured" | Nothing saved yet. Settings → Task repository. |
| "owner/repo does not exist, or this token cannot see it" | A typo, or the token has no access to that repository. |
| "This token is not allowed to read owner/repo" | The repository exists but is outside the token's scope. |
| "This repository is missing N required labels: …" | Run the bootstrap above, then validate again. |
| "The GitHub token cannot read owner/repo" | The repository was saved earlier but the token's access has since changed. |
| Empty sections, no error | The repository has the labels but no issues carrying them yet. |
| Today is always empty | No `Due Date` values, or the token lacks `read:project`. |
