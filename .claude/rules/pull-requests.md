---
paths:
  - "CONTRIBUTING.md"
description: How a pull request to Hostwarden goes from open to
  merged — checks in CI only, the own and the second review,
  merge readiness, rebasing stacks. For work on this repository, never for a
  managed host.
---

# Pull requests

When auto mode blocks a step below — answering a thread,
`rebase --continue`, a push — report it; never work around it.

## Checks

CI is the only gate for the tests. A run of the guard matrix on the
workstation starts tens of thousands of processes, endpoint
protection inspects each, and parallel sessions compete for the
cores; CI runs all of `scripts/check.sh` in one to two minutes.

- Before each commit, a pull request session runs the one cheap
  check, the secret scan of the staged changes:
  `sh scripts/check.sh --pre-commit`. A credential caught there
  never reaches the remote; CI finds it only after the push.
- Beyond that, it runs neither `scripts/check.sh` nor a test script
  (`guard-taboos-test.sh`, `instructions-test.sh`, …) on the
  workstation. It pushes, waits with
  `gh pr checks <number> --watch`, and on a failure reads
  `gh run view <run-id> --log-failed`.
- The one exception is a guard hook patch the maintainer applies
  with `git am` (`repo-release.md` → CI), which CI does not see
  until then. The matrix of the hook it changes runs exactly once,
  in the scratch clone the patch is built in, when it is done.
- A clone agents push from does not set up the git hooks from
  `CONTRIBUTING.md`: the pre-push hook would run the checks on
  every push.

## Review

Two reviews, in this order. The own review is where the quality is
made; the second review checks it with a model of another family,
whose blind spots differ.

Which second reviewer, and for which pull requests, is set here
and nowhere else:

- **Second reviewer:** Codex (→ Codex, below).
- **Required:** on every pull request.

Changing either line is a change to this file. Another reviewer
gets a subsection like Codex's, with how it is run locally, how it
is asked on GitHub, and what a completed, clean and stopped run
look like.

### The own review

The review for defects runs in a context of its own, never in the
session that wrote the change: that session reads the change as it
meant it, and a reviewer that did not write it reads it as a model
on a production server will. In Claude Code that is the
`hostwarden-reviewer` subagent; elsewhere, a fresh session whose
instructions are that file's body. Where that session would run on
the second reviewer's own quota — Codex reviewing for Codex — the
second review is the review and the own passes are skipped.

1. `/simplify`, for reuse and clarity.
2. `hostwarden-reviewer` on the branch against its base, for
   defects. Fix what it reports with steps 1 to 3 of a fix commit
   (below), everything as in rounds 1 and 2.
3. Push, lift the draft status, and request the second review
   where it is required.

### The second review

A second reviewer's runs draw on a quota and are the scarce
resource. A question the own review can answer never costs one.

- **Local, where the reviewer's CLI is installed and signed in.**
  Push first, so the SHA it reviews exists on the pull request, and
  run it on a detached worktree of that SHA, so nothing the session
  changes meanwhile reaches the review. Post the result as one pull
  request comment whose first line is exactly

      Second review (<reviewer>, local) on `<full head sha>`: <k> findings

  with `1 finding` or `no findings` where that fits, and the
  reviewer's text below it unchanged. That comment is the record
  whoever merges reads. Answer the findings in one further comment,
  a line each: "<title> — fixed in <sha>", "not a bug: …" or
  "deferred to a follow-up PR".
- **On GitHub otherwise,** only when asked: a reviewer that runs
  there on its own would repeat a local run. Answer every thread
  the same way and resolve it.
- Write a reviewer's handle only in the comment that asks it for a
  review. In a pull request body, a commit message or an answer, a
  mention starts it as well; write the name without the `@`.
- **A run that did not complete** reviewed nothing: it is no round,
  and nothing is posted for it. Retry once when the reason is
  transient, a network error or a timeout. Any other reason — the
  usage limit, a lost sign-in, a missing environment, an option
  the CLI rejects — goes to whoever merges with the reviewer's own
  message, and they decide whether to wait, fix it, or merge
  without the second review. The other path draws on the same
  quota and is no way around a limit.
- Stacked pull requests are each reviewed against their own base,
  so their rounds run in parallel.

### Codex

- **Local:** `codex login status` exits 0. `<run>` is
  `<pr>-<n>`, the pull request's number and the round's, plus a
  suffix for a repeated attempt. Run in the background — it takes
  minutes:

      git worktree add --detach <scratch>/codex-<run> <head sha> &&
        codex exec -C <scratch>/codex-<run> review \
        --base origin/<base> -c model_reasoning_effort=high \
        --ephemeral -o <scratch>/codex-<run>.md \
        > <scratch>/codex-<run>.log 2>&1

  Remove the worktree once it exits, whatever the outcome. The run
  completed only when it exited 0 and left `<run>.md` not empty;
  otherwise `<run>.log` says why.
- **On GitHub:** the connector `chatgpt-codex-connector`. Automatic
  reviews are off for this repository; a comment `@codex review`
  asks for one. It has completed when the "Codex Review Summary"
  comment shows "✅ Completed" next to the head SHA, not
  "🔄 Running". A clean pass leaves no review, only a "Didn't find
  any major issues" comment. When it cannot run, the connector
  replies with the reason instead of a summary.

### Rounds

A round is a completed second review that produced findings, local
or on GitHub; both count toward the same cap. Every status message
names its number.

- Rounds 1 and 2: fix everything, one commit per round.
- Round 3: fix only a P0 or P1, in one commit. A P2 or P3 is
  answered "not a bug: <reason>" or "deferred to a follow-up PR".
- Round 4, the review of the round-3 fix, is final: nothing is
  fixed, everything is deferred. A P0 or P1 there goes to whoever
  merges, with one line on its impact, and they decide.

Deferred findings are listed in the pull request body under
`## Deferred review findings`.

### A fix commit

A finding names one case; the defect is usually a class. Fixing
only the case named is what brings the same finding back in the
next round. Each time `hostwarden-reviewer` is given findings
below, it also gets every earlier finding on the pull request, its
own included.

1. Give the findings to `hostwarden-reviewer` as a sweep. It names
   each one's class and every sibling in the repository.
2. Fix the finding and its siblings in one commit. A claim about
   what the flow does — "verified", "read-only", "every guest" —
   that a review breaks for the second time, or that the reviewer
   finds cannot be kept, is dropped rather than narrowed again.
3. Before pushing, give the commit's range to
   `hostwarden-reviewer`, with the findings it answers. Fix what
   it reports at the current round's level by amending the same
   commit, at most three passes; what remains goes into the next
   round as it is.
4. Push. After a round, request the next one. Never request one
   after only answering findings, or after a rebase.

A second-review finding is one the own review missed. When the
sweep puts it in no class of `hostwarden-reviewer`, or in a class
whose questions would not have led there, list it in the pull
request body under `## Missed by the own review`, with the class
it needs. Those lists are what sharpens the reviewer, in a pull
request of its own, and what shows whether the second review is
still needed on every pull request.

A finding against a guard hook follows `repo-release.md` → Guard
findings.

## Merge-ready

- Where the second review is required, it has completed on the
  current head: on GitHub as its reviewer's subsection says, or
  locally with a record comment naming that SHA.
- No unresolved thread, every local finding answered, CI green, not
  a draft, and GitHub reports the pull request CLEAN.
- After any rebase, conflicts included, no new second review is
  requested or awaited if it had completed on the pre-rebase head
  with nothing open. The session checks its own conflict
  resolution instead: `git range-diff` against the pre-rebase
  head and green CI. Only a new fix commit of its own needs the
  second review again.
- Once a pull request is reported ready, push no new commit without
  telling whoever merges, or an unreviewed head gets merged.
- The merge is `gh pr merge --squash --match-head-commit <sha>`.
  The squash message carries the why, not only the what: before
  1.0.0 the changelog is rewritten from the code, the pull requests
  and the commit messages.

## Updating a branch

- Rebase on `origin/main`; never merge `main` in, whatever Auto-fix
  suggests, and never as a fallback. Squash your own commits first
  when many conflicts are likely. Push with `--force-with-lease`.
- A stacked branch whose base was squash-merged is rebased onto
  `origin/main` from its fork point: the last commit of the base
  that really lies under the branch. Note it when the stack is
  created, or read it from `git reflog show <branch>`.
  `git merge-base <branch> <old-base-head>` is not it: once the
  base is squashed away it finds an old `main` commit, and the
  rebase replays the base's commits with conflicts.

      git rebase --onto origin/main <fork-point> <branch>

  `git log --oneline origin/main..HEAD` must then show only the
  branch's own commits.

- A pull request that touches `.claude/hooks/` resolves a rebase
  conflict in a separate worktree or scratch clone, never in the
  worktree its own session runs from: conflict markers in the hooks
  break every Bash, Edit and Write call.

## After a merge

Before deleting the merged branch, run
`gh pr list --base <branch> --limit 1000`, since the default stops at
30: GitHub closes a pull request whose base branch disappears.
Retarget each one with `gh pr edit <number> --base main` first.
