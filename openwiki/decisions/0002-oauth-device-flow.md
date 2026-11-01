---
okf_version: "0.1"
---

# 0002 — Replace PAT entry with the OAuth device flow

**Date:** 2026-10-31 · **Status:** Accepted, not implemented
([#18](https://github.com/psd401/life-os-menubar/issues/18))

## Context

v1 asks the user to create a fine-grained personal access token, copy it, and
paste it into Settings. `SettingsViewModel` validates it with
`GitHubTokenValidator` and `KeychainTokenStore` saves it to the Keychain.

That works, and the token never leaves the Keychain, but it has real problems:

- The user has to understand fine-grained token scoping to get a working token,
  and the `read:project` scope requirement is easy to miss — which is why the app
  needs a whole remediation path for a token that can read issues but not
  Projects.
- A pasted token is a long-lived credential in the user's clipboard and probably
  in a password manager note or a terminal history.
- GitHub's own guidance is that applications should not ask users for PATs, even
  single-user applications.

## Decision

Move to the **OAuth device flow**, requesting the `repo` and `read:project`
scopes. The app shows a code, the user approves it in a browser, and the app
stores the resulting token in the Keychain exactly as it does today. The PAT
entry UI is removed, not kept as a fallback.

The device flow is the right OAuth variant here specifically because this is a
native app with no server and no custom URL scheme to defend: there is no client
secret to hide and no redirect to intercept.

## Alternatives rejected

- **Keep PAT entry.** Contradicts GitHub's guidance and keeps the scope-confusion
  support burden.
- **Authorization code flow with PKCE and a custom URL scheme.** More moving
  parts (scheme registration, redirect handling) for no gain over the device flow
  in a menu bar app.
- **A GitHub App instead of an OAuth app.** Installation-scoped tokens are a
  better fit for automation against an org's repos; this is a single user reading
  their own repo, and a GitHub App adds an installation step for no benefit.

## Consequences

- Breaking for existing installs: the saved PAT stops being how auth works and
  the user re-authenticates once. Acceptable — the only install is the author's.
- Token refresh/expiry becomes a real state the app must handle, where a PAT was
  effectively permanent. The sync and detail paths need a "re-auth required"
  path, not just a "token invalid" error.
- `KeychainTokenStore` stays the only persistence for the credential; this
  decision changes how the token is *obtained*, not where it lives.
