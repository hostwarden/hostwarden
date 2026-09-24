---
id: 20260924-one-shared-known-hosts-file
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [ssh, security]
---

# One shared `known_hosts`, never per-machine TOFU

## Context

Decided 2026-09-23 in PR #166. Heinzel checks a host key against
whatever `known_hosts` the local OS user already has, so a fresh
machine or a new teammate has to log in by hand once before
Hostwarden can reach a host at all — which had annoyed the user.
Seven other open pull requests touched `first-connection.md` at the
time, so the design had to add one check, not a new pipeline step.

## Decision drivers

- Trust-on-first-use once per machine repeats the same manual login
  for every workstation and every teammate.
- Host memory, and so host keys, are already shared in team mode.
- A key typed or pasted by hand is one wrong character from
  trusting the wrong host, or locking it out.

## Considered options

### `memory/known_hosts` in the workspace, checked and imported — chosen

One file, checked on every call and shared like the rest of team
mode. A missing key is resolved by a verified path first (the
hypervisor console), then offered from the user's own OS
`known_hosts`, then asked for. Against it: the file needs its own
write discipline (a command, never a hand-typed line) so a bad
paste cannot reach it.

### Trust-on-first-use per machine (the prior default)

Accept whatever the OS's own `known_hosts` already trusts, machine
by machine. Lost: it is what caused the manual-login annoyance in
the first place — once per team beats once per machine.

## Decision

`memory/known_hosts` is the only host-key file Hostwarden checks,
shared in team mode, filled by a verified path, then an offered
import, then asking — never by a hand-typed line.

## Consequences

`rules/host-keys.md` carries the file, its resolution order and the
write discipline; `AGENTS.md` → SSH Options names it on every SSH,
scp and rsync call. A workspace `ssh_config` for ports, users and
`ProxyJump` was split off as its own task, since it can run
commands and its settings are personal. CA trust in this file is
governed separately
([20260924-ssh-ca-audit-and-consistent-use](20260924-ssh-ca-audit-and-consistent-use.md)).

## Confirmation

A report of a login prompt reappearing on a known host, or a
proposal to fall back to the OS's own `known_hosts`, is the moment
to reread this record.
