---
id: 20260924-opaque-jump-path-is-listed
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [access-control, ssh]
---

# An unreadable jump path counts as a blacklisted hop

## Context

Decided in #211 on 2026-09-23. The blacklist check has to know every
host a connection passes. A `ProxyCommand` can hide them: a tunnel
client, a script, a `$`, a nested `ProxyCommand`, a long chain. Two
answers had been tried in review, and each drew a P1.

## Decision drivers

- A blacklisted host must never be reached through a path the check
  could not read.
- Host memory is shared with teammates and with an operations host.
- A `ProxyCommand` line can hold a password.

## Considered options

### Count it as a listed hop, ask once per session — chosen

A session names the program alone and asks the user once per
session; nothing is recorded, and `hostwarden-fleet-run` skips the
host. Against it: a host behind such a tunnel is never read
unattended, and the question comes back in every session.

### Record the user's answer in host memory

A `Jump path:` line lifts the refusal for good. Lost: one user's
answer lifted it for every teammate and the operations host, and it
went stale when someone edited the blacklist by hand.

### Guess hosts from the command's other words

Treat anything that looks like a host name as a hop. Lost: the
words included arguments that carried secrets, which then reached
the conversation.

## Decision

Only `ssh`, `nc`, `ncat`, `netcat`, `socat` and `connect` are read.
Any other jump path counts as a listed hop: the session names the
program, asks once and records nothing; the fleet run skips the
host as "jump path not readable".

## Consequences

`rules/access-control.md` → Server Blacklist carries the rule, and
`bin/hostwarden-fleet-run` does the same with its test matrix.
A proposal to store the answer or to guess from other words is
answered with this record.

## Confirmation

`scripts/fleet-run-test.sh` covers each form; a stored answer would
have to change the rule and the matrix together.
