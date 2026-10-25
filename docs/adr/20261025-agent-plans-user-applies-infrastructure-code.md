---
id: 20261025-agent-plans-user-applies-infrastructure-code
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [infrastructure-code, opentofu, ansible, approvals, guard]
---

# Hostwarden plans infrastructure code and applies only what cannot destroy

## Context

2026-10-25. Hostwarden ran an Ansible playbook from the workspace
with one approval and never ran `tofu` at all; the agents described
the commands instead of showing them, and a user had to ask for the
full command every time. The request was to support OpenTofu beside
Ansible, including pipelines, for people with little experience and
for an operator who forgets the exact invocation after months, with
a mode close to autonomous but never autonomous. A plan can replace
a server, which destroys it; a playbook changes every host it
reaches; both tools are run by the user from a terminal as well as
by the session.

## Decision drivers

- The session must never destroy or replace a resource on its own.
- Every run of either tool is approved on its own, never by a
  standing yes.
- A command the user runs has to work as shown, in any terminal.
- The same guardrails hold whether the session or the user runs the
  tool.

## Considered options

### Apply only a plan without deletes or replaces, asked each run — chosen

Two wrappers, `bin/hostwarden-tofu` and `bin/hostwarden-ansible`,
run the tools for the session and for the user alike; the guard
asks before every apply and denies every state writer and every
flag that skips a review or prints secrets; the wrapper itself
refuses to apply a plan with a delete or a replace and prints the
user's command instead. Against it: a plan that only adds and
changes can still cost money or open a port, so the review step
stays, and the approval prompt is one more click on every run.

### The session never applies

Every apply is the user's, as before for OpenTofu. Lost: the mode
close to autonomous the user asked for, and the user clicks through
the same plan twice, once to read it and once to apply what they
just read.

### The session applies everything after one approval

One yes per session or per stack. Lost: the user's decision per
run; a session that has learnt a yes applies the next plan, which
may replace the server, on the strength of a question answered an
hour ago.

### Bare tool calls with a longer rule

No wrapper; the rule spells the environment and the paths out
each time. Lost: a command the user can run as shown, since the
environment, the inventory and the plan's place are not in it, and
a guard that can read where a playbook or a plan comes from.

## Decision

Hostwarden runs both tools through its wrappers; it checks, plans
and reviews on its own, applies an Ansible play or an OpenTofu plan
without a delete or a replace only after the guard has asked the
user for that run, and hands every other apply to the user as a
complete command.

## Consequences

`rules/infra-code.md`, `rules/opentofu.md` and
`rules/workspace-playbook.md` carry the procedure, the wrappers the
refusals, `.claude/hooks/guard-taboos.d/config-mgmt.sh` the ask and
the denies. A plan with a delete or a replace, a `tofu destroy`,
`import`, a state write and `-auto-approve` stay the user's, by any
path. A request to apply a destructive plan from the session, or to
approve once for a session, is the moment to reread this record.

## Confirmation

`tests/bin/hostwarden-tofu.sh` holds the wrapper to the refusal and
`tests/hooks/guard-taboos/config-mgmt.sh` the guard to the ask and
the denies.
