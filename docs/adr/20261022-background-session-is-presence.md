---
id: 20261022-background-session-is-presence
status: accepted
supersedes: 20260925-coordinator-starts-itself
superseded-by:
waiting-on:
tags: [coordination, sessions]
---

# The background session is called presence

## Context

`20260925-coordinator-starts-itself` named the background session of an
operations checkout "the coordinator". The repository uses the word for a
second role: the session that drives several open pull requests
(`.claude/rules/pr-coordinator.md`). The two share nothing except the
word. The background session assigns nothing, approves nothing and
reaches no server; it keeps the presence map, relays announced steps,
holds step orders across sessions and watches maintenance windows. Its
core word in the code is already presence (`presence/`, `presence.sh`,
the presence map).

## Decision

The background session is **presence**: skill `hostwarden-presence`, session
`hostwarden presence`, opt-out `Presence: off`. The pull request role keeps
"coordinator".

## Consequences

`bin/hostwarden-impact presence` is the subcommand; the cache marker is
`presence-session+<session>+<beat>`, apart from the `presence/` map. Start and
opt-out behave as in `20260925-coordinator-starts-itself`. No alias: a
`Coordinator: off` line is no longer read, and an old session is stopped once
with `claude stop`.
