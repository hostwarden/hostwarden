---
paths:
  - "CONTRIBUTING.md"
description: How a pull request to Hostwarden goes from open to
  merged — checks in CI only, both reviews, merge readiness,
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

Two reviews, in this order. The own review is where the quality is
made; the second review checks it with a model of another family,
whose blind spots differ.

- **Second reviewer:** Codex. Everything specific to it is in
  → Codex below, `scripts/codex-quota.sh`, `CONTRIBUTING.md` and
  `docs/project-structure.md`; another reviewer replaces that set.
- **Required:** on every pull request. The other value is "on
  request": only where whoever merges asks for it, in the session
  or on the pull request, whose comments the session reads for
  such a request before it reports the pull request merge-ready.

### The own review

It runs on every pull request, in a context of its own, never in
the session that wrote the change. In Claude Code that is the
`hostwarden-reviewer` subagent; elsewhere, a fresh session whose
instructions are that file's body. A tool that picks the model per
session, such as OpenCode, may run it on another family than the
author's, and the own review then brings a second family's view as
well.

1. `/simplify`, for reuse and clarity.
2. `hostwarden-reviewer` on the branch against its base. Its
   findings already name their class and siblings: fix them all,
   then give it the branch again, at most three passes.
3. Push, lift the draft status, and request the second review
   where it is required.

Each pass's result is one pull request comment, first line
`Own review, pass <p> before round <n>: <k> findings`, the
reviewer's text below it. Later passes, in this session or another,
are given these comments; in Claude Code, a later pass of the same
review continues the same subagent (`SendMessage`), which saves it
reading the repository again. What the third pass still reports is
listed under `## Deferred review findings` as the own review's; a
P0 or P1 among it goes to whoever merges, with one line on its
impact.

### The second review

- **Capacity.** Before a local run, read what is left of the limit
  as the reviewer's subsection says, and name it in the status
  message. When a limit is reached, or a run stops on one, a person
  decides, not a session (`rules/borrowed-rights.md`):
  - wait for the reset;
  - take the other path, where its limit is a separate one;
  - skip the second review for this pull request from the current
    head on: the body gets `## Second review skipped`, a line with
    that head, the reason, the reset time and who decided;
  - stop.

  A skip holds for that pull request only.
- **Local, where the reviewer's CLI is installed and signed in.**
  Push first, so the SHA it reviews exists on the pull request, and
  run it on a detached worktree of that SHA, so nothing the session
  changes meanwhile reaches the review. Post the result as one pull
  request comment whose first line is exactly

      Second review (<reviewer>, local) on `<full head sha>`: <k> findings

  with `1 finding` or `no findings` where that fits, and the
  reviewer's text below it. That comment is the record whoever
  merges reads.
- **On GitHub otherwise,** asked as the reviewer's subsection says.
- **Answers.** Every finding of a round goes through the sweep
  (→ A fix commit, step 1), a deferred one included, and its answer
  names the class the sweep gave it: "fixed in <sha>", "fixed in
  <sha>, rest of the class deferred" where the fix commit's last
  pass left part of it, "not a bug: <reason>" or, from round 3,
  "deferred to a follow-up PR". On GitHub the answer goes in the
  finding's thread, which is then resolved; locally in one comment,
  a line each, `<title> — class <n> — <answer>`.
- **Handles.** Write a reviewer's `@` handle only in the comment
  that asks it for a review. Anywhere else — a body, a commit or
  squash message, an answer, reviewer text posted as a comment — a
  mention starts it too; write the name there without the `@`.
- **A run that did not complete** reviewed nothing: it is no round,
  and nothing is posted for it. Retry once when the reason is
  transient, a network error or a timeout. A usage limit goes to a
  person as under Capacity; any other reason — a lost sign-in, a
  missing environment, an option the CLI rejects — goes to whoever
  merges with the reviewer's own message.
- Stacked pull requests are each reviewed against their own base,
  so their rounds run in parallel.

### Codex

- **Capacity:** `sh scripts/codex-quota.sh` reads the limits of
  the account the CLI is signed in to, at no cost: what is used of
  each window, when it resets, and any reset credit. It exits 1 at
  the limit and 2 when it cannot tell; at 2, run anyway. GitHub
  reviews have a code-review limit of their own that it does not
  show; there the connector's reply is the only signal. Redeeming a
  reset credit is the person's decision.
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
  reviews are off for this repository, so it never repeats a local
  run; a comment `@codex review` asks for one. It has completed
  when the "Codex Review Summary" comment shows "✅ Completed" next
  to the head SHA, not "🔄 Running". A clean pass leaves no review,
  only a "Didn't find any major issues" comment. When it cannot
  run, the connector replies with the reason instead of a summary.

### Rounds

A round is a completed second review that produced findings, local
or on GitHub; both count toward the same cap. Every status message
names its number.

- Rounds 1 and 2: fix everything, one commit per round.
- Round 3: fix only a P0 or P1, in one commit.
- Round 4, the review of the round-3 fix, is final: nothing is
  fixed, everything is deferred. A P0 or P1 there goes to whoever
  merges, with one line on its impact, and they decide.

Deferred findings are listed in the pull request body under
`## Deferred review findings`.

### A fix commit

A second-review finding names one case; the defect is usually a
class. Fixing only the case named is what brings the same finding
back in the next round.

1. Give the findings to `hostwarden-reviewer` as a sweep. It names
   each one's class and every sibling in the repository.
2. Fix the finding and its siblings in one commit. A broken claim
   follows `instruction-authoring.md` → Claims.
3. Before pushing, give the commit's range to the same reviewer,
   with the findings it answers. Fix what it reports at the current
   round's level by amending the same commit, at most three passes;
   what remains is deferred as in the own review.
4. Push, then request the next round. Never request one after only
   answering findings.

Each time the reviewer is given findings, it also gets the earlier
ones on the pull request, the own review's included, a line each:
title, class, `path:line`, answer.

A finding against a guard hook follows `repo-release.md` → Guard
findings.

### Sharpening the reviewer

A second-review finding is one the own review missed unless it is
answered "not a bug" or the own review had already reported it.
When the session reports the pull request merge-ready, it adds
each missed finding to the one open issue titled "Sharpen
hostwarden-reviewer": a checklist line with the pull request's
number, the finding's title, its class from the answer, and the
question that class lacked. It opens that issue when none is
open. At three
unchecked lines, it proposes to the person a pull request that
sharpens the reviewer and closes the issue, as a task chip where
the tool has them. A new class is the exception; a question added
to an existing one is the rule.

## Merge-ready

- Where the second review is required, it has completed on the
  current head, as its subsection says for GitHub or with a local
  record naming that SHA, or it was skipped as under Capacity.
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
