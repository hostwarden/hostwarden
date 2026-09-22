---
paths:
  - "CONTRIBUTING.md"
description: How a pull request to Hostwarden goes from open to
  merged — Codex review, merge readiness, rebasing. For work on
  this repository, never for a managed host.
---

# Pull requests

When auto mode blocks a step below — answering a thread,
`rebase --continue`, a push — report it; never work around it.

## Review

- Codex (`chatgpt-codex-connector`) reviews only a pull request that
  is not a draft. Lift the draft status yourself as soon as
  `/simplify` and `/code-review --fix` are done; a comment
  `@codex review` starts another review.
- A round is a completed Codex review that produced findings. Work
  rounds 1 and 2 fully. From round 3, only a P0 or P1 blocks; a P2 or
  P3 is answered "not a bug: <reason>" or "deferred to a follow-up PR",
  and the deferred ones are listed in the PR body under
  `## Deferred Codex findings`.
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
- After a rebase without conflicts (check with `git range-diff`),
  green CI is enough if Codex had completed on the pre-rebase head
  with nothing open.
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
- A stacked branch whose base was squash-merged is rebased with
  the command below; `git log --oneline origin/main..HEAD` must then
  show only the branch's own commits.

      git rebase --onto origin/main \
        $(git merge-base <branch> <old-base-head>) <branch>

- A pull request that touches `.claude/hooks/` resolves a rebase
  conflict in a separate worktree or scratch clone, never in the
  worktree its own session runs from: conflict markers in the hooks
  break every Bash, Edit and Write call.

## After a merge

Before deleting the merged branch, run `gh pr list --base <branch>`:
GitHub closes a pull request whose base branch disappears. Retarget
each one with `gh pr edit <number> --base main` first.
