---
id: 20260924-blast-radius-by-script
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [coordination, multi-host]
---

# A script computes the blast radius, not the model

## Context

Decided in the design of #226, reviewed by the maintainer on
2026-09-24. A reboot, a firewall or network change or a restart on
one host broke sessions working on other hosts: its guests, hosts
behind it as a jump host, hosts that need a service it runs. The
hooks planned next have to hold such a step within a 5-second
timeout, and a plan for a maintenance window has to name the same
hosts weeks later.

## Decision drivers

- Leaving a host out is the incident; including one too many costs
  a notice.
- A hook cannot ask a model and has seconds, not minutes.
- Two runs over the same memory must give the same answer.

## Considered options

### `bin/hostwarden-impact radius` from memory and `ssh -G` — chosen

Guests, jump hosts, `Reached as:`, clusters and `Depends on:` are
read mechanically, with the hop parser the blacklist check uses,
and cached in an index. Against it: it knows only what memory
records, so a dependency nobody recorded is missing.

### The model works the radius out from memory

Lost: it missed guests, answered differently from run to run, and
spent context in every session that needed the answer.

## Decision

The radius is computed by `bin/hostwarden-impact`, never by the
model. Sessions, hooks and plans read its output.

## Consequences

`rules/coordination.md` → Blast radius carries the rule, and
`rules/multi-host.md` → Order takes its jump groups from the same
script. What memory lacks the radius lacks too, so `Depends on:`
is detected at onboarding and housekeeping and taken from the user.

## Confirmation

`scripts/impact-test.sh` fixes the radius over a fixture memory; a
radius worked out in prose would have to replace the rule and drop
the script together.
