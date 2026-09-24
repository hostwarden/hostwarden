---
id: 20260924-hard-cap-on-second-review-rounds
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [review]
---

# A hard cap on second-review rounds

## Context

Decided 2026-09-23. Fixing every finding in every round had let
reviews run away: #108 and #112 each took ten rounds, and #129,
#137 and #148 still took five or six, because a round-3-or-later fix
kept introducing the next round's finding. Nothing stopped a review
loop from continuing indefinitely.

## Decision drivers

- A fix aimed at a late-round finding is itself a fresh change,
  which can carry its own new defect.
- Unlimited rounds have already run past ten without converging.
- A human has to be able to decide when a real, unresolved risk is
  worth shipping anyway.

## Considered options

### Fix everything for two rounds, then taper to nothing — chosen

Rounds 1 and 2 fix every finding, one commit per round. Round 3
fixes only a P0 or P1, in one commit; the rest are answered "not a
bug" or deferred to a follow-up. Round 4, reviewing that fix, is
final: nothing more is fixed — everything is answered and deferred,
and a P0 or P1 there goes to whoever merges with one line on its
impact, for a human to decide. Against it: a real defect can still
ship if round 4 finds one and a human chooses to merge anyway.

### Keep fixing every finding until the review is clean

No cap: continue rounds until a pass reports nothing. Lost: this is
what produced the ten-round reviews the cap exists to stop, since a
late fix reliably produced the next round's finding.

## Decision

A pull request's second review is capped at four rounds: two that
fix everything, one that fixes only P0/P1, and a final one that
fixes nothing and hands any remaining P0/P1 to whoever merges.

## Consequences

`.claude/rules/pull-requests.md` → Rounds and → A fix commit carry
the cap and the fix-commit discipline.

## Confirmation

A pull request running a fifth round, or a P1 reaching whoever
merges with no impact line, is the moment to reread this record.
