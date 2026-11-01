---
okf_version: "0.1"
---

# 0001 — Single `main` branch; `dev` merged and deleted

**Date:** 2026-10-31 · **Status:** Implemented ([#17](https://github.com/psd401/life-os-menubar/issues/17))
· **Driver:** psd-dev-standards 01 (repo lifecycle), 06 (CI/CD enforcement)

## Context

v1 shipped entirely on `dev` (phases #2–#7, PRs #8–#15). `main` was the default
branch but held only the Claude workflows, the README stub, and the MIT LICENSE
added when the repo was transferred to `psd401` and made public. The two branches
had diverged: `main` was 6 commits ahead and 21 behind.

That split is actively harmful once the repo is public and standardized:

- The default branch is what a visitor clones. Anyone following the README got a
  repo with no app in it.
- CI triggered on `dev` only, so nothing validated the default branch.
- Two long-lived branches means every future PR needs a base-branch decision.

## Decision

`main` is the default and the only long-lived branch. `dev` was merged into
`main` with a **merge commit** (`--no-ff`) so v1's history is preserved and
reachable from `main`, then deleted. CI triggers moved from `dev` to `main`.

## Alternatives rejected

- **Fast-forward or reset `main` to `dev`.** Would have discarded the LICENSE and
  Claude-workflow commits that exist only on `main`.
- **Squash the merge.** Collapses 21 commits of v1 history into one and leaves
  `dev` not an ancestor of `main`. The history is the record of how the label
  contract and sync path were arrived at; it is worth keeping.
- **Keep `dev` as an integration branch.** A one-maintainer, tier-C experiment
  does not have the release cadence that justifies a second long-lived branch.

## Consequences

- Every PR bases on `main` and CI runs on it. Branch names are
  `feature/<issue>-<slug>` or `fix/<slug>`.
- Local clones that tracked `dev` need `git remote prune origin` and a
  re-checkout of `main`.
- No release branch exists. When signing and distribution arrive, tags on `main`
  are the intended mechanism, not a branch.
