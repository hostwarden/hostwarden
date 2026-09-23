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

CI is the only gate. Ten sessions each running the guard matrix on
the workstation, with endpoint protection inspecting every process,
took 15 to 36 minutes a run; CI runs all of `scripts/check.sh` in
one to two.

- A pull request session runs neither `scripts/check.sh` nor a test
  script (`guard-taboos-test.sh`, `instructions-test.sh`, …) on the
  workstation. It pushes, waits with
  `gh pr checks <number> --watch`, and on a failure reads
  `gh run view <run-id> --log-failed`.
- The one exception is a guard hook patch the maintainer applies
  with `git am` (`repo-release.md` → CI), which CI does not see
  until then. The matrix of the hook it changes runs exactly once,
  in the scratch clone the patch is built in, when it is done.
- A clone agents push from does not set up the pre-push hook from
  `CONTRIBUTING.md`: it would run the checks on every push.

## Review

- Codex (`chatgpt-codex-connector`) reviews only a pull request that
  is not a draft. Lift the draft status yourself as soon as
  `/simplify` and `/code-review --fix` are done; a comment
  `@codex review` starts another review.
- Stacked pull requests may all be out of draft at once: Codex
  reviews each against its base, so their rounds run in parallel.
- A round is a completed Codex review that produced findings. Every
  status message names its number.
  - Rounds 1 and 2: fix everything, one commit per round.
  - Round 3: fix only a P0 or P1, in one commit. A P2 or P3 is
    answered "not a bug: <reason>" or "deferred to a follow-up PR".
  - Round 4, the review of the round-3 fix, is final: nothing is
    fixed, everything is deferred. A P0 or P1 there goes to
    whoever merges, with one line on its impact, and they decide.

  Deferred findings are listed in the PR body under
  `## Deferred Codex findings`.
- Before each fix commit, read the code around the fix, not only
  the line flagged: the late P1s mostly came from the previous
  round's fix.
- After the first review, comment `@codex review` only after a fix
  commit, never after only answering threads or after a rebase.
- A finding against a guard hook follows `repo-release.md` → Guard
  findings.
- Answer every Codex thread — "fixed in <sha>", "not a bug: …" or,
  from round 3, "deferred to a follow-up PR" — and resolve it.

## Merge-ready

- Codex has completed on the current head: the "Codex Review
  Summary" comment shows "✅ Completed" next to that SHA, not
  "🔄 Running". A clean pass leaves only that comment and a 👍, no
  review.
- No unresolved thread, CI green, not a draft, and GitHub reports
  the pull request CLEAN.
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
  rebase replays the base's commits with conflicts, as on #111.

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
