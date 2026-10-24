---
id: 20261024-ops-host-read-only-while-no-write-key
status: accepted
supersedes: 20260924-fleet-read-via-signed-bundle
superseded-by:
waiting-on:
tags: [operations, access-control, ssh, keys]
---

# Operations host read-only while no write key is unlocked

## Context

Issue #517, 2026-10-24, replacing
[20260924-fleet-read-via-signed-bundle](20260924-fleet-read-via-signed-bundle.md).
The operations host reached the fleet only through fleet read's
forced command, so an interactive session there could change
nothing: the operator had to go back to the workstation.
The account that runs Hostwarden there holds none of the admin's own
keys, a separation the workstation cannot offer. A lab run (OpenSSH
10.0) showed that a shared connection opened with a key outlives the
key's lifetime in the agent.

## Decision drivers

- The nightly run keeps the fleet key alone and never writes.
- No write key usable at rest, none for the timer, no agent
  forwarding to the operations host.
- The operator unlocks write access, for a time they choose.
- The `authorized_keys` line stays the operator's own step.

## Considered options

### A write key unlocked for a time, beside the forced fleet key — chosen

Hostwarden's own SSH identity on the operations host, an encrypted
key file the operator loads with `ssh-add -t` in their own login as
that account, or a certificate their CA issues for a few hours. Each
host gets its line from the operator. The fleet run's ssh file,
which jump hosts read too, sets no agent and a connection path of
its own, so it never offers the write key or rides a connection
opened with it. Against
it: while unlocked, anything running as that account can use the
key, and a shared connection stays open until it ends or is closed.

### Fleet read alone, as before

The signed bundle through the forced command, nothing else. Lost: every
change waits for the workstation, although the operations host
separates the admin's keys better than the workstation does.

### Agent forwarding from the workstation

The operator's agent reaches the operations host for a session.
Lost: anything there with access to the socket signs with the admin's
own keys for as long as the connection lasts.

### A write key at rest, or one the timer uses

Lost: a thief of the machine, or a fault in the nightly run, would
hold write access to every host.

## Decision

The operations host reads the fleet through the forced-command
wrapper and the operator-signed bundle, and is read-only while no
write key is unlocked and no connection opened with one is still
open. The fleet run never uses a write key, and no write key is
usable at rest.

## Consequences

`.agents/skills/hostwarden-fleet-read/references/operations-host.md`
carries the write identity, how it is unlocked and locked, the
check before each change that ends a busy session's shared
connections, and `memory/readonly.md` without `*` but with the
machine's own names, which the operator edits alone (Julian's
choice, 2026-10-24);
`lib/hostwarden-fleet-run/judge.sh` keeps the fleet run off the
write key and its connections. Each host carries a second line for
the operations host, its write key's.

## Confirmation

`tests/bin/hostwarden-fleet-run.sh` holds the fleet run's options.
A request for a write key the timer may use, a key without a
passphrase there, or agent forwarding to the operations host is the
moment to reread this record.
