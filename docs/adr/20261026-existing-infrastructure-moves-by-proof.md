---
id: 20261026-existing-infrastructure-moves-by-proof
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [infrastructure-code, opentofu, ansible, migration]
---

# Existing infrastructure moves under code only against a clean plan

## Context

2026-10-26. Hostwarden runs OpenTofu stacks and Ansible trees
(`20261025-agent-plans-user-applies-infrastructure-code`). Most
infrastructure it meets is older than the code: resources made in a
console, hosts set up by hand or with files Hostwarden deployed. The
request was to help move both under code, and to hand what Hostwarden
manages itself over to code, and back.

## Decision drivers

- Moving must change nothing on the host or at the provider.
- The code must be something a person keeps, not a dump.
- Which side is right, code or reality, is the user's call.
- An import writes every attribute of an object into the state.

## Considered options

### Import blocks and a check that must show only the takeover — chosen

OpenTofu `import` blocks plus a generated draft the session cleans;
an Ansible role that states today's values, proven by a check run
that ends with `changed=0`. A difference is a question, the default
is to correct the code, and the first apply is one that changes
nothing else.

### `tofu import` and a role applied to see

Faster by a step. Lost: the state is written before anyone read a
plan, and a role applied to a host is the first test of whether it
describes the host.

### Generate everything and keep the draft

The draft is best-guess code, experimental in OpenTofu, and carries
no judgement about names, secrets or structure. Lost: code a person
wants to maintain.

## Decision

Existing resources and hosts move under code one slice at a time,
through import blocks and a check that must show only the takeover.

## Consequences

`rules/infra-migration.md` carries the procedure; the wrappers carry
`generate`, the import count of `review` and `matches`. `tofu import`
and a state write stay the user's. A request to import a whole
estate in one pass, or to apply to make a draft true, is the moment
to reread this record.

## Confirmation

`tests/bin/hostwarden-tofu.sh` and `tests/bin/hostwarden-ansible.sh`
hold `generate`, the import count and `matches`;
`tests/hooks/guard-taboos/config-mgmt.sh` holds the guard to letting
them pass.
