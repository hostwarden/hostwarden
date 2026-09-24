---
id: 20260924-update-channel-follows-major-line
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [release]
---

# Default update channel follows the current major line

## Context

Decided 2026-09-24, alongside the changelog-fragments decision, for
what an operations checkout follows once 1.0.0 exists. Before a
release line exists, every operations checkout necessarily follows
`main`; the question was what the default becomes once real
versions start shipping, and how someone who wants to keep testing
`main` stays able to.

## Decision drivers

- Most operators want stable releases, not to test `main`.
- A moving tag (`v1`) is one more ref to keep correct at every
  release.
- Someone testing `main` needs an explicit, sticky way to say so.

## Considered options

### Follow the newest release's major line, `main` for testers — chosen

An operations checkout that never chose a channel follows `main`
until a 1.0.0 or later release exists; its next update then records
the major line of that release and moves to it, found by its
`vX.Y.Z` tags alone — no moving tags such as `v1`. `--unpin` records
`main` for whoever wants it. Against it: a checkout that adopted
`main` before 1.0.0 has to explicitly unpin once it would otherwise
switch, or it moves to a release line on its own at the first
update after one exists.

### Track `main` by default, forever

Keep every operations checkout on `main` unless it opts into a
release line. Lost: it makes untested code the default for
everyone, which is the opposite of what most operators actually
want once stable releases exist.

## Decision

From the first 1.0.0-or-later release on, an operations checkout
that never chose a channel moves to that release's major line, found
by its version tags alone; there are no moving tags. A checkout can
still pin to an exact tag, or unpin to follow `main`.

## Consequences

`.claude/rules/repo-release.md` → VERSION carries the channel rule;
`bin/hostwarden-update --help` documents pinning and unpinning.
This decision is related to
[20260924-no-compat-before-1-0](20260924-no-compat-before-1-0.md),
which covers what changes once 1.0.0 ships.

## Confirmation

A request for a moving major-version tag, or a report that stable
operators are unexpectedly running `main`, is the moment to reread
this record.
