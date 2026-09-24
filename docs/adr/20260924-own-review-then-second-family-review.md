---
id: 20260924-own-review-then-second-family-review
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [review, tooling]
---

# Own review makes quality; a second family checks it

## Context

Decided 2026-09-23 in PR #187. 63% of Codex's findings on prior
pull requests landed on fix commits nobody had reviewed first — the
only review of a change had run inside the same session that wrote
it. The coordinator proposed keeping the second-review gate on
GitHub instead of running it locally.

## Decision drivers

- A change reviewed only by the session that wrote it repeats that
  session's own blind spots.
- Fix commits need the same scrutiny as the original change, not
  less.
- Running locally keeps review output out of GitHub when the
  reviewing tool is signed in on the workstation.

## Considered options

### Own review fresh, second review another family, local — chosen

A dedicated reviewer (`hostwarden-reviewer`, dispatched with no
memory of the session that wrote the change) runs on every pull
request and every fix commit; that is where quality is made. A
second, replaceable reviewer of a different model family — Codex
today — checks it independently, run locally where its CLI is
signed in, recorded as one line per run in the pull request body,
never as posted comments. GitHub's automatic reviews are switched
off so nothing runs twice. Against it: a local run needs the
reviewing tool signed in on the machine that runs it, and its
capacity is a separate limit a person has to watch.

### Keep the second-review gate on GitHub

Let the existing GitHub-based review stay the only gate, with no
separate own review step. Lost: it does nothing about fix commits
going unreviewed, which was the actual problem, and running only on
GitHub gives up the choice to compare a local run's output before
it is ever posted.

## Decision

Every pull request gets an own review in a fresh context first, and
a fix commit gets one too where the review calls for it; a second
reviewer of another family then checks the branch, run locally
where possible, recorded as one line per local run in the pull
request body; GitHub's automatic second review is off.

## Consequences

`.claude/rules/pull-requests.md` → Review carries the own-review
step, the second reviewer's mechanics and the record format. Missed
findings feed one running "Sharpen hostwarden-reviewer" issue
instead of a chip per finding.

## Confirmation

Codex findings clustering on fix commits again, or a proposal to
drop the own-review step, is the moment to reread this record.
