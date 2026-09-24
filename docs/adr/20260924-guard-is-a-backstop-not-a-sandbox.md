---
id: 20260924-guard-is-a-backstop-not-a-sandbox
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [guard]
---

# The taboo guard is a backstop, not a sandbox

## Context

Decided in #93. Codex, review after review, found constructions
built only to evade the guard — brace expansion assembling a flag,
wrapper chains, `eval`, a script file — and each pattern the guard
learned invited the next variant.

## Decision drivers

- A parser or pattern list never closes: `path-shim-over-parsing`
  records the same growth for the development guard, and this guard
  saw it first.
- The guard still has to catch a command an agent plausibly writes
  by accident, and a regression against what it already blocked.
- `AGENTS.md` already forbids reaching a blocked effect another way,
  so evasion has a rule against it beyond the guard itself.

## Considered options

### A backstop for the everyday mistake — chosen

A finding against `guard-taboos.sh` or `guard-mode.sh` counts only
as a plausible accidental command, a false positive, or a
fixture-matrix regression; a construction built only to evade it is
closed as outside the guard's scope. Against it: an agent
deliberately told to get around the guard, or one whose own
judgement has already failed, can still reach past it.

### Extend the guard to catch every evasion

Add a pattern for each construction a round finds. Lost: the same
growth `path-shim-over-parsing` records for command parsing — every
round found the next form, and the list never closed.

### Run every command in a sandbox the guard cannot be evaded from

Lost: Hostwarden's job is reaching real production servers over SSH
from the user's own machine; sandboxing the session would sandbox
the access the tool exists to have.

## Decision

A review finding against `guard-taboos.sh` or `guard-mode.sh` counts
only under the three cases above. A construction built only to
evade the guard gets `repo-release.md`'s exact answer: "not a bug:
outside the guard's scope."

## Consequences

`.claude/rules/repo-release.md` → Guard findings carries the rule
and the three cases that count; `AGENTS.md` → Critical Safety Rules
carries the parallel prohibition on reaching the same effect another
way. A second-review finding of the evasion kind is answered with
this record instead of a guard change.

## Confirmation

The fixture matrices (`guard-taboos-test.sh`, `guard-mode-test.sh`)
catch a regression on what they already cover. Nothing tells us a
genuinely new evasion was found; that gap is what this record
accepts, not one it promises to close.
