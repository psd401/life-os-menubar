---
okf_version: "0.1"
---

# 0002 — OAuth device flow by default, token entry as the advanced path

**Date:** 2026-10-31 · **Amended:** 2026-11-01 · **Status:** Accepted,
implemented ([#18](https://github.com/psd401/life-os-menubar/issues/18))

> **Amended 2026-11-01.** The original decision removed token entry outright.
> It is kept, as a deliberately advanced least-privilege path, because a
> fine-grained token scoped to Issues on one repository is narrower than any
> classic scope the device flow can ask for. The reasoning below is otherwise
> unchanged; the rejected-alternatives and consequences sections are updated to
> match the two-path design and what was verified about GitHub Apps.

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

Set against that, a fine-grained token is the only way to run this app on
*narrow* access. The Today view needs user-owned Projects v2, and only a classic
scope can reach it, so the device flow has to ask for `repo` — which grants read
and write on every repository the signed-in account can reach, private and
organization repositories included. For a user who would rather give up Today
than hand over that much, pasting a token scoped to Issues read/write on one
repository is strictly better.

## Decision

Two paths, with a clear default.

1. **Default — the OAuth device flow**, requesting the `repo` and `read:project`
   scopes. The app shows a code, the user approves it in a browser, and the app
   stores the resulting token in the Keychain exactly as it does today.
2. **Advanced — token entry**, kept for a **fine-grained personal access token
   scoped to Issues read and write on the one task repository**. This is the
   least-privilege option. Fine-grained tokens expose Projects as an
   organization-only permission, so a user-owned project is unreachable on this
   path: Today and the menu bar count stay off, and Settings says so plainly
   rather than looking broken.

The breadth of `repo` is stated in the UI next to the choice and in the README
next to both paths. An informed choice needs the blast radius in front of it,
not in a decision record.

The device flow is the right OAuth variant here specifically because this is a
native app with no server and no custom URL scheme to defend: there is no client
secret to hide and no redirect to intercept. The client ID is public by design
and ships as a single constant in `GitHubOAuthApp`; it is not a secret, so
standard 04 rule 15a does not apply to it.

## Alternatives rejected

- **Remove token entry, device flow only.** The original form of this decision.
  Rejected on amendment: it would force every user onto `repo`, with no narrower
  option at all.
- **Authorization code flow with PKCE and a custom URL scheme.** More moving
  parts (scheme registration, redirect handling) for no gain over the device flow
  in a menu bar app.
- **A GitHub App instead of an OAuth app.** Verified 2026-10-31: a GitHub App
  cannot access user-owned Projects v2 at all, which rules it out for the Today
  view regardless of how well installation-scoped tokens would otherwise fit.

## Consequences

- **No forced re-authentication.** A v1 personal access token already in the
  Keychain keeps working: to every client in the app a token is an opaque
  bearer string, so a stored credential stays valid until the user signs out.
  This is why `SettingsViewModel.isSignedIn` keys off "a credential is stored"
  rather than "the device flow produced one".
- **No refresh machinery.** OAuth App tokens — unlike GitHub App user tokens —
  do not expire, so the app needs no refresh path and no "re-auth required"
  state beyond the existing "token invalid" error. This replaces the original
  decision's expectation that expiry would become a state to handle.
- **Two support paths, not one.** The `read:project` remediation message earns
  its keep: it is now the expected steady state of the advanced path, not just a
  misconfiguration.
- **One manual prerequisite.** An OAuth App has to be registered under the
  psd401 org with device flow enabled before sign-in can work. Until the client
  ID in `GitHubOAuthApp` is filled in, `GitHubDeviceFlowAuthorizer.isAvailable`
  is false, Settings disables sign-in and says why, and token entry is the only
  path. The registration steps are in the README.
- `KeychainTokenStore` stays the only persistence for the credential; this
  decision changes how the token is *obtained*, not where it lives.
