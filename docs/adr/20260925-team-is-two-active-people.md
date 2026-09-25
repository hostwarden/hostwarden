---
id: 20260925-team-is-two-active-people
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [coordination, workspace]
---

# A team is two active people, not a workspace remote

## Context

Decided in the design of #226, reviewed by the maintainer on
2026-09-24, built by its fourth pull request. An announced step must
reach sessions on other workstations, which no local presence map
sees, so it has to be written onto the hosts it reaches: one login
per host, thirty on a busy hypervisor. Until then "team mode" meant
that the workspace has a remote, which is also true of one person
who keeps the same memory on two machines.

## Decision drivers

- Remote writes cost logins, rate limits and fail2ban counts on
  jump hosts; they have to buy something.
- One person knows where they work in parallel, and the local map
  covers their sessions.
- A handle must stay reserved once journals and decisions name it.

## Considered options

### Two or more active handles in `operators.md` — chosen

Each handle may carry `(inactive since <date>)`, set only when the
user says so, or `(operations host)`. Two or more lines with neither
make a team. Against it: a person who stops without telling anyone
keeps the workspace a team.

### A remote on the workspace

Rejected: one person with several devices would pay the logins for
nobody. The meaning it had is kept under its own name, shared
workspace, for what really depends on it: sharing, the required
`Operator:` line, `ssh_hosts`.

### Removing an inactive handle, or dating it on activation

Rejected: journals, `Decided:` and `Planned:` lines still name it,
and a freed handle could be taken by someone else; git already
dates each reservation.

### Impact entries on remote hosts in solo use too

Rejected: the logins buy nothing the local map does not.

## Decision

`bin/hostwarden-impact announce` writes a register entry and a
journal line on each radius host it may reach only in a team, and
`done` removes the entries. "Team" means that and nothing else; a
workspace with a remote is a shared workspace.

## Consequences

`rules/coordination.md` → Teams defines the term and the writes,
`rules/session-start.md` → The operator handle the statuses, and
`bin/hostwarden-fleet-run` refuses a handle marked inactive. The
rules that said "team mode" say "shared workspace". One person on
two workstations at the same moment is not covered.

## Confirmation

`scripts/coordination-test.sh` writes to radius hosts with two active
handles and to none with one active and one inactive.
