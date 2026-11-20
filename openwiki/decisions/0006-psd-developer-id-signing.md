---
okf_version: "0.1"
---

# 0006 — Sign local builds with the PSD Developer ID

**Date:** 2026-11-19 · **Status:** Implemented

## Context

Local installs were built with `CODE_SIGNING_ALLOWED=NO`, the same flag CI
uses. The linker signs that build ad hoc: its signing identifier is the bare
`LifeOSMenubar`, and its designated requirement is one code hash,
`cdhash H"…"`.

The GitHub token item (service `com.krishagel.LifeOSMenubar`, account
`github-personal-access-token`) is in the file-based login keychain. An item
there trusts an app in two places, and both pinned that one build:

- Its **access list** stores each trusted app's designated requirement. An ad
  hoc requirement is a code hash, so it matches exactly one binary.
- Its **partition list** stores `cdhash:<hash>` for ad hoc code, or
  `teamid:<team>` for team-signed code.

So every rebuild was a new app to the Keychain. It got a "wants to use your
confidential information" prompt, or no silent access. That was an annoyance
while the token never changed. It stopped being one when device-flow tokens
started expiring after 8 hours ([decision 0002](0002-oauth-device-flow.md)):
the app renews the token and rewrites the item several times a day, so its
access has to survive every reinstall.

Checked on 2026-11-19 with `security dump-keychain -a`, filtered to the item.
That shows attributes and access lists only, never the token. The partition list
was `cdhash:069176…` alone, which is the installed ad hoc build.

## Decision

The app target signs with **Developer ID Application** from team `87DL7L9GU6`
(Peninsula School District) in both Debug and Release:

```text
CODE_SIGN_IDENTITY = "Developer ID Application";
CODE_SIGN_STYLE = Manual;
DEVELOPMENT_TEAM = 87DL7L9GU6;
```

No provisioning profile is needed: the app has no entitlements that require
one. The designated requirement becomes:

```text
anchor apple generic and identifier "com.krishagel.LifeOSMenubar" and
(certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or
 certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and
 certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and
 certificate leaf[subject.OU] = "87DL7L9GU6")
```

It names the team and the bundle ID, not a binary, so every rebuild satisfies
it, and so does a renewed certificate from the same team. After one
**Always Allow**, the partition list holds `teamid:87DL7L9GU6` and later builds
read the item silently.

The CI gate keeps `CODE_SIGNING_ALLOWED=NO`, unchanged.

## Alternatives rejected

- **The owner's personal Apple Development certificate.** It works: a test build
  signed with it got a stable requirement. But it ties a district repository's
  installs to a personal team. Note that the ID in that certificate's name,
  `7N3H422WM7`, is not a team ID. The team is the certificate's OU
  (`B75Z23JPJ4`), and `DEVELOPMENT_TEAM` takes the OU.
- **Pass the signing settings on the install command line only.** It's a
  docs-only change, but forgetting the flags, or copying the CI command,
  silently brings back an ad hoc build and the prompt. Xcode Run builds would
  stay ad hoc as well.
- **Move the item to the data protection keychain**
  (`kSecUseDataProtectionKeychain`). It needs a keychain access group, so an
  entitlement and a provisioning profile, plus migration code and tests to move
  the existing item. An unsigned CI build could not use the Keychain at all.

## Consequences

- **Building without `CODE_SIGNING_ALLOWED=NO` requires the PSD Developer ID
  identity, with its private key, in the login keychain.** A Mac without it
  stops with `No signing certificate "Developer ID Application" found`. It can
  still build with `CODE_SIGNING_ALLOWED=NO` and accept a prompt after each
  install.
- **CI and code scanning are unaffected.** `ci.yml` passes
  `CODE_SIGNING_ALLOWED=NO` on every `xcodebuild`. So does CodeQL's Swift
  autobuild: it runs
  `xcodebuild build … CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`, as
  seen in the `Analyze (swift)` log of run 43329516680.
- **A distribution certificate signs development builds.** These builds are not
  notarizable: they carry `com.apple.security.get-task-allow`, which Xcode adds
  to every non-archive build, and they have no hardened runtime and no secure
  timestamp. Notarization is still out of scope; whoever takes it on starts from
  this identity.
- **The first signed install asks once.** Existing installs carry an access list
  and partition list for an ad hoc build, so the first signed build gets one
  prompt. Enter the login password and select **Always Allow**.

## As implemented

Verified on 2026-11-19 against the real token item in the owner's login
keychain. Only attributes and access lists were read, never the token:

1. Build 1 (cdhash `9b77a51a…`) was installed and launched, and it prompted once.
   After **Always Allow**, the access list held the team requirement above,
   marked `OK`, and the partition list read
   `cdhash:069176…, teamid:87DL7L9GU6`.
2. Build 2 was rebuilt with a different code hash (`855c9082…`) and installed
   over build 1. It launched with no SecurityAgent prompt. Settings then showed
   **Sign out**, so `SettingsViewModel` loaded a non-empty token from the
   Keychain at startup, and there was no Keychain error.
