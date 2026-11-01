---
okf_version: "0.1"
---

# Architecture

- [Overview](overview.md) — the two targets, Core's layering, the App target's
  composition root, and what is stored where.
- [Sync and the label contract](sync-and-label-contract.md) — the one-`status:` /
  one-`priority:` contract, the delta-plus-reconcile sync path, and the mutation
  rules.
- [The Life OS task-repo standard](../../docs/life-os-repo-standard.md) — the
  contract a configured task repo has to satisfy, and the bootstrap for a fresh
  one.
- [Repo plumbing](repo-plumbing.md) — branches, CI, SHA-pinned actions,
  Dependabot, the verify gate, and the community health files.
