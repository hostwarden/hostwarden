---
id: 20260926-edit-unreleased-records
status: accepted
waiting-on:
tags: [records, tooling]
---

# Records no release carries are edited, not superseded

## Context

Records became immutable on 2026-09-24, before Hostwarden's first
release. Immutability serves a reader who ran the old decision and
needs to know what held then. Before a release nobody has, so a
supersede only chains records through states nothing shipped, and
the index grows with them. Workoho's decision-records skill makes no
such exception.

## Decision

A record in no finished `vX.Y.Z` release reachable from `HEAD` is
edited in place under its first date; its abandoned version
becomes a rejected option. Once released, it is superseded.

## Consequences

`scripts/decisions.py --check` fails on a released record that
differs beyond `status`, `superseded-by` and `waiting-on`, or is
gone: a third
marked change to the skill's copy. A clone without release tags
checks nothing. `docs/architecture-decisions.md` → Superseding
carries the rule.
