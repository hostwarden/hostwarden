---
paths:
  - "CONTRIBUTING.md"
description: How a pull request to Hostwarden goes from open to
  merged — checks in CI only, Codex rounds, merge readiness,
  rebasing stacks. For work on this repository, never for a
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

The review for defects runs in a context of its own, never in the
session that wrote the change: that session reads the change as it
meant it, and a reviewer that did not write it reads it as a model
on a production server will.

Codex runs are the scarce resource: they draw on one weekly quota,
locally and on GitHub alike. A question a Claude reviewer can
answer never costs a Codex run.

### Before Codex

1. `/simplify`, for reuse and clarity.
2. The `hostwarden-reviewer` subagent on the branch against its
   base, for defects. Fix what it reports the way a fix commit is
   made (below), until a pass reports nothing at P0 or P1, at most
   three passes. What remains goes into the Codex round as it is.
3. Lift the draft status.

### Codex

- **Local, where the Codex CLI is installed and signed in**
  (`codex login status` exits 0). Push first, so the SHA the run
  reviews exists on the pull request, then run it in the
  background — it takes minutes:

      codex exec review --base origin/<base> \
        -c model_reasoning_effort=high --ephemeral \
        -o <scratch>/codex-round-<n>.md >/dev/null 2>&1

  Post the file as one pull request comment whose first line is
  exactly

      Codex review (local) on `<full head sha>`: <k> findings

  with `1 finding` or `no findings` where that fits, and the file
  below it unchanged. That comment is the record whoever merges
  reads. A run that exits non-zero or leaves the file empty
  reviewed nothing: report it and post nothing. Answer the
  findings in one further comment, a line each: "<title> — fixed
  in <sha>", "not a bug: …" or "deferred to a follow-up PR".
- **On GitHub otherwise.** Codex (`chatgpt-codex-connector`)
  reviews there only when asked: the repository's automatic
  reviews are off, so a local run is never repeated there. Comment
  `@codex review` once the draft status is lifted, and again for
  each later round. Answer every thread the same way and resolve
  it.
- Stacked pull requests are each reviewed against their own base,
  so their rounds run in parallel.

### Rounds

A round is a completed Codex review that produced findings, local
or on GitHub; both count toward the same cap. Every status message
names its number.

- Rounds 1 and 2: fix everything, one commit per round.
- Round 3: fix only a P0 or P1, in one commit. A P2 or P3 is
  answered "not a bug: <reason>" or "deferred to a follow-up PR".
- Round 4, the review of the round-3 fix, is final: nothing is
  fixed, everything is deferred. A P0 or P1 there goes to whoever
  merges, with one line on its impact, and they decide.

Deferred findings are listed in the pull request body under
`## Deferred Codex findings`.

### A fix commit

A finding names one case; the defect is usually a class. Fixing
only the case named is what brings the same finding back in the
next round.

1. Give the findings to `hostwarden-reviewer` as a sweep. It names
   each one's class and every sibling in the repository.
2. Fix the finding and its siblings in one commit. When a finding
   breaks an absolute claim — "verified", "read-only", "every" —
   for the second time, drop the claim rather than narrowing it
   again.
3. Give the fix commit's range to `hostwarden-reviewer`, with the
   findings it answers, and fix what it reports at the current
   round's level, at most three passes.
4. Only then request the next Codex round. Never request one after
   only answering findings, or after a rebase.

A finding against a guard hook follows `repo-release.md` → Guard
findings.

## Merge-ready

- Codex has completed on the current head: on GitHub, the "Codex
  Review Summary" comment shows "✅ Completed" next to that SHA,
  not "🔄 Running", and a clean pass leaves only that comment and a
  👍, no review; locally, the record comment names that SHA.
- No unresolved thread, every local finding answered, CI green, not
  a draft, and GitHub reports the pull request CLEAN.
- After any rebase, conflicts included, no new Codex review is
  requested or awaited if Codex had completed on the pre-rebase
  head with nothing open. The session checks its own conflict
  resolution instead: `git range-diff` against the pre-rebase
  head and green CI. Only a new fix commit of its own needs Codex
  again.
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
