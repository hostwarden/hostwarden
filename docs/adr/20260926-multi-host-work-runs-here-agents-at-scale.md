---
id: 20260926-multi-host-work-runs-here-agents-at-scale
status: proposed
supersedes:
superseded-by:
waiting-on: review of the pull request that adds it
tags: [multi-host, subagents, hooks]
---

# Several hosts run in the session; agents only at scale

## Context

`rules/multi-host.md` gave every host its own subagent in Claude
Code, a one-line kernel question included, and the fleet audit one
probe agent per host. Each agent starts and reads the rules, well
over 100 KB, before its first command, and knows nothing of the
round before when a follow-up is needed. Julian set the goals on
2026-09-26: speed first on many hosts, then token economy; a
session serves one request, so its context need not stay small.

## Decision drivers

- Wall time when the same work runs on many hosts.
- Tokens spent before any work happens.
- A follow-up command that builds on the last answer.
- The coordination hooks and the taboo guard must still see every
  host and command.

## Considered options

### Rounds in the session, grouped agents at scale — chosen

A read runs here, one Bash call per round, every host written out
and joined by `&` on one line. A skill runs here on up to four
hosts and in agents of four beyond; a change runs here up to about
six calls, one agent per host beyond. Against it: every host's
output lands in the session.

### One agent per host

Parallel, context kept small. Lost: an agent's start and rules read
per host cost more time and tokens than most tasks, and a follow-up
starts them all again.

### A loop or `xargs -P` in one call

Fast. Lost: the hooks read destinations from the command text; they
miss a variable, read `{}` as a host, and see nothing after an
unquoted newline. The guard never reads a script file.

## Decision

Reads, small skills and small changes run in the session, in
parallel rounds where they read; agents take only large skills and
changes.

## Consequences

The fleet audit reads `references/probes.md` itself and
`hostwarden-host-probe` is gone. `hostwarden-host-task` takes a
group of hosts for a skill. A change never runs in rounds, since
the impact check does not read a command piped into ssh.
`Multi-host: agents` restores agents for every task.
`rules/multi-host.md` → Dispatch carries the constraint.

## Confirmation

A session that fills its context on a fleet audit, or a round the
hooks read with a host missing.
