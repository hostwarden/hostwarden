---
id: 20260929-reviewer-model-follows-the-files
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [review, tooling]
---

# Own review on Sonnet; Opus where files or findings call

## Context

Since PR #435 the own review ran on Opus at medium effort for
every change. Most changes touch nothing where a missed defect
lets a taboo through or cuts SSH, so most of that spend bought
nothing a cheaper model would have missed.

## Decision drivers

- Opus is spent only where it is called for, known before the
  review or shown during it.
- The choice follows from files and findings, never from the
  session's judgement of its own change.
- A dispatch can set the model, not the effort.

## Considered options

### Sonnet pair, plus an Opus reviewer for critical files — chosen

The two focused reviewers run on Sonnet at medium effort over the
whole range. The same reviewer, dispatched on Opus, reads the
files a list in `scripts/review-tier.sh` names critical, and any
file in which a review finds a P0 or P1. Critical files are read
twice. Against it: a third reviewer to merge.

### Opus for the whole pull request once one file is critical

One rule, no third reviewer. Lost: Opus reads the uncritical files
as well, which is the spend this decision removes.

### Split the range between the two models

Sonnet reads the uncritical files, Opus the critical ones. Lost: no
file is read twice, and a defect where the two parts meet belongs
to neither reviewer.

### Opus at low effort for the critical reviewer

Cheaper still, in an agent file of its own. Lost: the reviewer's
work is reading and following values across files, which low effort
cuts short exactly where a miss costs most.

## Decision

The own review runs on Sonnet at medium effort. A critical
reviewer on Opus at medium effort reads the listed critical files and
every file in which a review finds a P0 or P1.

## Consequences

`.claude/rules/pull-requests.md` → The critical reviewer carries
the escalation; `scripts/review-tier.sh` carries the list, and
prints a range's critical files with `--critical`. The sharpening issue marks
each miss in a file the critical reviewer read.

## Confirmation

Misses marked `critical` in the sharpening issue, or misses piling
up in files the list does not name.
