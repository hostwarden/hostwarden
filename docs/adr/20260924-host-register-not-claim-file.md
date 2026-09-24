---
id: 20260924-host-register-not-claim-file
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [parallel-sessions, sync]
---

# Sessions register on the host, not a claim file

## Context

PR #35 (parallel sessions, team mode) was rebuilt on 2026-09-21 on
`hostwarden-sync` (#33) and the host register (#37). The original
design used a workstation claim file
(`memory/servers/<host>/.session`), `starting:`/`working:` journal
lines, and a commit per change to keep two sessions on the same
host from colliding. `hostwarden-sync`'s `add -A` and `--autostash`
were exactly what swept up or disturbed another session's files in
a shared workspace.

## Decision drivers

- A shared workspace's git history must never carry another
  session's uncommitted files.
- Two sessions on different workstations, not only two windows on
  one, must see each other.
- Coordination state must expire on its own, with nobody remembering
  to clean it up.

## Considered options

### Named-file commits plus a host-side register — chosen

`hostwarden-sync commit` touches only the files it is given and
waits out `index.lock`; `pull` never autostashes and leaves a dirty
workspace alone. Every writing session registers a live,
self-expiring entry directly on the managed host, read by any
session that connects, from any workstation.

### A workstation claim file

One file per host, in the workspace, naming the session holding it.
Dropped: it lived on one workstation only, so a teammate on another
one never saw it, and a crashed session left it claimed for good.

### Journal lines plus a commit per change

Announce intent as `starting:`/`working:` lines in the host's own
journal, one commit per change. Dropped: a commit per change turned
routine work into review noise, and a journal line does not expire.

## Decision

Coordination lives on the managed host: a self-expiring register
entry per writing session, or, on a host without one, a token-based
pair of journal lines. `hostwarden-sync` commits only the files it
is given and never autostashes. The original claim file, untokened
journal lines and a commit per change are dropped for good.

## Consequences

`rules/parallel-sessions.md` carries the register format, its
staleness window, and the token-based journal fallback for a host
without one; `bin/hostwarden-sync` carries the named-file commit and
no-autostash behavior. A proposal to track sessions in a workspace
file, or to commit per change, is answered with this record.

## Confirmation

Nothing would tell us on its own. A dirty workspace swept up by
`hostwarden-sync`, or a stale claim outliving its session, is the
moment to reread this record.
