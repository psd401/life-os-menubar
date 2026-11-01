---
okf_version: "0.1"
---

# Decision record

One page per decision. Each records the date it was made, its status, what was
chosen, what was rejected, and what it costs. A decision whose code has not
landed yet says so — "accepted" is not "implemented".

| # | Decision | Date | Status |
|---|----------|------|--------|
| [0001](0001-single-main-branch.md) | Single `main` branch; `dev` merged and deleted | 2026-10-31 | Implemented |
| [0002](0002-oauth-device-flow.md) | Replace PAT entry with the OAuth device flow | 2026-10-31 | Accepted — not implemented ([#18](https://github.com/psd401/life-os-menubar/issues/18)) |
| [0003](0003-nexus-design-system.md) | Adopt the Nexus design system via NexusKit | 2026-10-31 | Accepted — not implemented ([#19](https://github.com/psd401/life-os-menubar/issues/19)) |
| [0004](0004-macos-26-floor.md) | Raise the deployment floor to macOS 26 | 2026-10-31 | Accepted — not implemented ([#19](https://github.com/psd401/life-os-menubar/issues/19)) |
| [0005](0005-configurable-task-repo.md) | Make the task repo user-configurable and publish the repo standard | 2026-10-31 | Accepted — not implemented ([#21](https://github.com/psd401/life-os-menubar/issues/21)) |

Standing decisions that predate this record and are enforced in code rather than
argued here: GitHub Issues as the task store, the one-`status:`/one-`priority:`
label contract, GraphQL for reads and REST for mutations, Keychain-only token
storage, and the Core/App target split that keeps all logic testable. Those are
documented in [architecture](../architecture/overview.md).
