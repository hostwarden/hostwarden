---
id: 20260924-wsl-root-is-passwordless-sudo
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [platforms, windows, privilege-escalation]
---

# `wsl.exe -u root` is treated like passwordless sudo

## Context

Decided 2026-09-22 while designing WSL support. Inside a WSL
instance, `wsl.exe -d <distribution> -u root` run through Windows
interop gives root in that instance without a password, the same
shape of access passwordless sudo already gives on every other
platform Hostwarden manages.

## Decision drivers

- The instance is already a target Hostwarden manages; a second
  privilege model for it differs from sudo in name only.
- Passwordless sudo elsewhere already runs without a confirmation
  prompt.
- The security audit already reports how a host reaches root, on
  every platform.

## Considered options

### Treat it exactly like passwordless sudo — chosen

No confirmation prompt before using `wsl.exe -u root`; the security
audit reports it exists, same as it reports passwordless sudo
elsewhere. Against it: a Windows host and its WSL instances share
one root-equivalent lever available to anyone with interop access,
which the audit has to keep surfacing rather than a one-time design
decision hiding it.

### A separate privilege model for WSL, confirmed each time

Ask before every `wsl.exe -u root` call, distinct from how
Hostwarden treats sudo. Dropped: the access it grants is no
different from the passwordless sudo Hostwarden already uses
without asking, so a separate model would be a distinction that
changes nothing about the actual risk.

## Decision

`wsl.exe -u root` is used like passwordless sudo: no confirmation
prompt, and the security audit reports that it is available, the
same as it reports passwordless sudo on any other platform.

## Consequences

`rules/platform/wsl.md` carries the mechanics and the audit line;
`rules/privilege-escalation.md` → Stand-ins for sudo lists it beside
the platform's other sudo equivalents.

## Confirmation

A WSL privilege-escalation incident traced to this lever, or a
request to confirm it each time, is the moment to reread this
record.
