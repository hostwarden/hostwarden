---
id: 20260924-claims-dropped-not-narrowed
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [instructions, review]
---

# A claim a review keeps breaking is dropped, not narrowed

## Context

Decided 2026-09-22, in a pull request whose rescue path for a
lights-out console claimed to be a "verified" way back in. Five
review rounds each found what the word still over-promised — a
port answering is not the same as the management controller, a
node login is not the same as guest-console access — and each fix
narrowed the claim instead of removing it. Written into
`.claude/rules/instruction-authoring.md` → Claims on 2026-09-23.

## Decision drivers

- Narrowing a guarantee after each finding moves the gap without
  closing it; there was always one more edge to word around.
- Without the real system to test the claim against, no rewording
  of "verified" converges on something true.
- A prohibition ("never do X") is a different kind of claim: a step
  that breaks it is the defect, not the wording.

## Considered options

### Drop the claim outright — chosen

State what the step does and leave the guarantee out, so nothing
upstream of the step has to hold for the sentence to stay true. For
the rescue path: every way back in is confirmed by the user, and a
check is shown as a hint, never as clearance. Against it: the flow
reads more cautiously, asking the user to confirm what a passed
check used to wave through on its own.

### Narrow the claim again

Reword the guarantee to whatever the latest finding actually
proved, and keep going. Rejected: the pull request alone took five
rounds this way, each fix closing one edge and exposing the next;
two rounds of findings against the same word is treated as the
signal to stop patching it and remove it instead.

## Decision

A claim a review has broken twice, or one no change to the steps
can keep true, is removed rather than reworded again; the
instruction says what the step does instead of what it guarantees.
A prohibition is not a claim and is not affected.

## Consequences

`.claude/rules/instruction-authoring.md` → Claims carries the rule
and the prohibition-versus-claim distinction. A review proposing a
narrower wording for a guarantee already broken once should be
pointed at this record instead of iterated on; the fix is to drop
the word, not to find its next qualifier.

## Confirmation

A second round of findings against the same guarantee word, with
no real system available to test it against, is the moment to
reread this record instead of narrowing the wording again.
