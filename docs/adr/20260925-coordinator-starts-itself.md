---
id: 20260925-coordinator-starts-itself
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [coordination, sessions]
---

# The coordinator starts itself; the user opts out

## Context

Decided by the maintainer on 2026-09-24 in the design of #226, and
built by its fourth pull request. The hooks of `rules/coordination.md`
hold a disruptive step until the writers on its radius are safe, but
they cannot reach an idle session to ask for its ack, and nothing
keeps the picture of which session works where. A session that
does both has to run before the first announce, or it is missing
exactly when the step comes.

## Decision drivers

- The relay to idle writers only helps when the coordinator already
  runs at the moment of an announce.
- The operations checkout on one Mac often runs more than eight
  sessions at once, the case the design came from.
- Starting it must never block a session start or reach a server.
- A user who does not want it needs one step to be rid of it, for
  good.

## Considered options

### Start with the first operations session, opt out — chosen

The session start starts one in the background where none runs,
says so in one line, and a `Coordinator: off` line in the personal
`memory/user.md` keeps it off. Against it: every operations user
gets a background session they did not ask for, and the start
depends on the `claude` CLI and its `--bg`.

### Start only on request

The user runs `claude --bg "/hostwarden-coordinator"` when they want
one. Rejected: the incident this answers happens when nobody
thought of coordination beforehand, so a coordinator nobody started
is absent in exactly those sessions; the hooks still work, but the
idle writer times out instead of acking.

### Every session coordinates itself

Rejected in the design already: an LLM turn per hop, and nothing is
delivered while the sending session waits.

## Decision

In an operations checkout, `check-session.sh` starts
`/hostwarden-coordinator` in the background with `claude --bg` where
`bin/hostwarden-impact coordinator` finds none and
`memory/user.md` has no `Coordinator: off`. The skill, run in any
operations session, stops it and writes the line, or removes the
line and starts one.

## Consequences

`rules/coordination.md` → The coordinator and
`rules/session-start.md` → The coordinator carry the behaviour, the
`hostwarden-coordinator` skill the run itself. An atomic start lock
and a mark whose older or smaller-id holder stays keep it to one per
checkout. An operations host's `user.md` template carries
`Coordinator: off`. Tools without hooks start none.

## Confirmation

`scripts/coordination-test.sh` starts one from the hook in a fixture
operations checkout, and none with the line, a live coordinator, a
held lock or a development checkout.
