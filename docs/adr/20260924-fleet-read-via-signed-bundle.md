---
id: 20260924-fleet-read-via-signed-bundle
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [operations, access-control]
---

# Fleet read runs a signed bundle, not a shell

## Context

Decided 2026-09-23 for an always-on operations host that runs
Hostwarden's housekeeping unattended, porting Heinzel's
`fsn-ops01` pattern. The host needs to reach every server in the
fleet on a timer with nobody at the keyboard, which is exactly the
shape of access that turns one compromised machine into a
compromised fleet.

## Decision drivers

- The operator wants less standing access than a normal user
  shell, on every host at once.
- The authorized_keys line on a host stays the operator's own step;
  Hostwarden never grants itself access.
- The SSH-key and sshd-config taboos hold on the operations host's
  target hosts exactly as everywhere else.

## Considered options

### A forced command running a signed, read-only bundle — chosen

Each host's key is forced to a wrapper (`fleet-read`) that runs
only a bundle of checks a session builds from the housekeeping
references and the operator signs. Against it: the bundle has to be
rebuilt and re-signed whenever the housekeeping references it draws
from change.

### An unprivileged account with a normal shell

Give the operations host a plain SSH account and let it run
`hostwarden-housekeeping` like an interactive session. Lost: a
normal shell can run anything the account's permissions allow,
which is far more than a nightly read needs.

### A sudo allowlist

Grant the account a narrow list of commands through sudo. Lost:
sudo's own allowlist syntax is easy to widen by accident, and it
still runs whatever exact command line the list permits, not a
fixed, auditable bundle.

## Decision

An operations host reads the fleet only through a forced-command
wrapper and an operator-signed bundle of read-only checks; it never
gets a shell or a sudo rule of its own.

## Consequences

`.agents/skills/hostwarden-fleet-read/SKILL.md` and its
`references/operations-host.md` carry the wrapper and the bundle
workflow, including how a run judges each host's output. Hostwarden
ships no bundle-signing tool: a session builds and shows the bundle,
but only the operator holds the key that signs it, repeated
whenever the housekeeping references it draws from change.

## Confirmation

A request to give the operations host a shell or a sudo rule "just
this once", or a bundle that runs unsigned, is the moment to reread
this record.
