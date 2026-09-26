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
Pull request 471 made the coordination hooks read every line of a
command and what a `printf` pipes into the far shell.

## Decision drivers

- Wall time when the same work runs on many hosts.
- Tokens spent before any work happens.
- A follow-up command that builds on the last answer.
- The hooks and the taboo guard must still see every host and step.

## Considered options

### Rounds in the session, grouped agents for large skills — chosen

Reads, changes and the fleet audit run here, one Bash call per
round, every host written out, a change's step as a heredoc under
its host. A skill runs here on up to four hosts, in even agent
groups of up to four beyond. `bin/hostwarden-group` prints each
answer once. Against it: every host's output lands in the session,
whose model and effort the user picked.

### One agent per host

Parallel, context kept small. Lost: an agent's start and rules read
per host cost more time and tokens than most tasks, and a follow-up
starts them all again.

### A loop or `xargs -P` in one call

Fast. Lost: the hooks read no destination held in a variable, read
`{}` as a host, and the guard never reads a script file.

## Decision

The session runs work on several hosts in rounds; agents take a
skill on more than four hosts, or on two on a larger model, and a
read under `Multi-host: agents`.

## Consequences

The fleet audit reads `references/probes.md` itself and
`hostwarden-host-probe` is gone; `hostwarden-host-task` takes a
group of hosts for a skill or a read, and no change. A change that can cut SSH
still runs host by host. The session cannot see its effort, so
`Multi-host: agents` is the user's lever. `rules/multi-host.md` →
Rounds of one call carries the form.

## Confirmation

A session that fills its context on a fleet audit, or a round the
hooks read with a host or a step missing.
