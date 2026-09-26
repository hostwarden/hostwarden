---
id: 20260926-release-key-from-the-checked-out-version
status: accepted
waiting-on:
tags: [release, signing, supply-chain]
---

# The updater trusts the release key of the checked-out version

## Context

Release tags are signed from v1.0.0 on
(`20260926-release-tags-signed-with-dedicated-ssh-key`). Every tag
carries `.github/release-signers` in its own tree, so whoever serves
a forged tag, a mirror or the transport, can list their own key
there, and a check against that file passes. Taken in issue #356.

## Decision

`bin/hostwarden-update` verifies a release tag against the
`.github/release-signers` of the commit checked out, copied
before any fetch, never the tag's own; each verified release
between hands on its file.

## Consequences

A new key reaches a checkout only through a release the old key
signed that lists the new one, which `.claude/rules/repo-release.md`
→ VERSION requires before the secret changes. After
a leaked key is removed, a checkout verifies the next tag by hand
with the line from the updates page, as
`website/docs/running-it/setup/updates.md` → Release signatures
says.
