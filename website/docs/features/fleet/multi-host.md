---
sidebar_position: 1
description: Runs one question, check, or change across several
  servers at once.
---

# One task on many hosts

Ask one question, run one check or roll out one change on several
servers.

```
 ❯ Which kernel runs on web1, web2 and web3?
 ❯ Run housekeeping on web1 and db1
 ❯ Prüf auf allen Servern, ob nginx läuft
```

## What you ask

One question, one check, or one change, named for several servers
or for all of them.

## How hosts run it

Each host proves itself before it answers, and Hostwarden combines
the results rather than dumping them one after another:

- **Every host runs the full pipeline first.** Each remote host
  runs the full first-connection pipeline — blacklist, read-only
  list, host key, activity check — and returns a short answer; a
  local target skips those remote-only steps.
- **Most of it runs from the session itself.** A question runs on
  all hosts at once, one call per round, and the next round can
  build on what the last one returned. Housekeeping or a security
  audit on up to four hosts, and a change of a few steps on a few
  hosts, run there too: starting subagents would take longer.
- **Subagents take the large work.** In Claude Code, housekeeping
  or a security audit on more than four hosts runs in subagents of
  four hosts each, and a larger change in one subagent per host;
  elsewhere the session runs it too. `Multi-host: agents` under
  `# Preferences` in `memory/user.md` sends every task to
  subagents, for someone who keeps one long conversation.
- **Identical answers print once.** Hostwarden prints identical
  answers once, with the hosts that gave them, so twenty hosts
  that agree take one line and the outlier stands out.
- **An unknown host goes first, alone.** A remote host never
  connected before gets its first connection in the main session
  first, since it needs your answers.
- **Some hosts stay in sequence.** Hosts behind one jump host run
  one after another, a guest reached through its hypervisor runs
  in sequence with it, and so do the members of a cluster in a
  change.

## Changes and the canary

A change asks once, then proves itself on one host before it
spreads:

- **One question names every host.** A change asks once, naming
  every host and a proposed canary host; blacklisted, read-only
  and Windows hosts are left out.
- **The canary goes first, alone.** Only when its result matches
  what was expected do the others follow, in Claude Code all at
  once apart from hosts that have to wait their turn.
- **A surprise halts what has not started.** At the canary, the
  whole rollout stops; later, only the hosts still waiting stop.
- **Each host gets its own record.** Every host the change reached
  gets its own journal line and memory.
- **The rollout survives a restart.** It is written down as a plan
  in `memory/plans/` until every host is done, so a later session
  can finish it.
- **Some changes stay sequential.** A change to the firewall, the
  network or a login shell runs one host after another in the main
  session instead, each with the SSH safety net and its own
  questions.

## What is left out

Of the named skills, housekeeping and the security audit run this
way; the others take one host at a time. `/hostwarden-multi-host`
starts it by name.
