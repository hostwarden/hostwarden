---
id: 20260924-cadence-change-own-pr
status: accepted
waiting-on:
tags: [process, review]
---

# A cadence change gets its own pull request

## Context

Measured 2026-09-22. PR #127 turned the configuration-management
probe from a one-shot check into one that runs on every connection,
bundled with the feature that needed it. Every instruction written
for the one-shot case turned out wrong for the recurring one, none
of it visible in the diff. Six Codex rounds followed, four findings
caused by the cadence change alone. The follow-up #133, one probe
branch with no cadence change, passed with none.

## Decision

When a change turns a one-time check into a recurring one, it ships
as its own pull request, never bundled with the feature that needed
it.

## Consequences

A session preparing such a change greps the rule for every
instruction that records, asks or dismisses something, and works
out what each does on the second run, before opening the pull
request, and says so in its body. `.claude/rules/pull-requests.md`
→ Scope carries the split; a reviewer who sees a cadence change
bundled with a feature cites this record.
