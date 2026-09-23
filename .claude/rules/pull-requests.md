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

## The project's branches

Remote names say nothing here: in a fork `origin` is the fork, and
in the project's own clone a second remote is Heinzel. Every
command below that needs one of the project's branches uses
`hostwarden/<branch>`, fetched just before:

    git fetch -q https://github.com/jpawlowski/hostwarden.git \
      +refs/heads/<branch>:refs/hostwarden/<branch>

Every `gh` command below names the repository the same way, with
`-R jpawlowski/hostwarden`.

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
  `gh pr checks <number> -R jpawlowski/hostwarden --watch`, and on
  a failure reads
  `gh run view <run-id> -R jpawlowski/hostwarden --log-failed`.
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

`<base>` below is the pull request's base branch as
`gh pr view <n> -R jpawlowski/hostwarden --json baseRefName`
names it; the review runs
against `hostwarden/<base>` (→ The project's branches). A stale or
foreign `main` would put other commits into the review.

### The own review

It runs on every pull request, in a context of its own, never in
the session that wrote the change. In Claude Code that is the
`hostwarden-reviewer` subagent; elsewhere, a fresh session whose
instructions are that file's body. A tool that picks the model per
session, such as OpenCode, may run it on another family than the
author's, and the own review then brings a second family's view as
well.

1. `/simplify`, for reuse and clarity.
2. `hostwarden-reviewer` on the branch against `hostwarden/<base>`. Its
   findings already name their class and siblings: fix them all,
   then give it the branch again, in passes as below.
3. Push, lift the draft status, and request the second review
   where it is required.

The results stay in the session; nothing of them is posted but
the deferred list below.
Passes, here and on a fix commit, run like this:

- Up to three passes check the fixes. Each continues the reviewer
  that reported them — in Claude Code the same subagent
  (`SendMessage`) — which knows the classes and siblings it named
  and does not read the repository again.
- Then one fresh reviewer checks the whole range, given nothing of
  the earlier passes: a reviewer checking against its own list
  misses what that list missed. What it reports is fixed at the
  current level — in the fix commit when it checks one, otherwise
  on the branch at the level of rounds 1 and 2 — and the second
  review, where one follows, checks that fix.
- What is still open after that is listed under
  `## Deferred review findings` as the own review's; a P0 or P1
  among it goes to whoever merges, with one line on its impact.

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
  changes meanwhile reaches the review. Its text stays in the
  session. The record is one line per completed run in the pull
  request body under `## Review`, which whoever merges reads:

      <reviewer> <model> <effort>, <where>, <sha>: <k> findings, <left>

  with `<where>` `local`, the full head SHA, `1 finding` or
  `no findings` where that fits, `<left>` what a capacity read
  right after the run shows, and the answers appended once they are
  given. A completed run on GitHub gets a line too, with
  `<where>` `GitHub` and `-` for the model, the effort and
  `<left>`. The lines with findings are the rounds, in order.
- **While a local run works,** its log shows each command it runs.
  A run whose log has not grown for 10 minutes is stuck: stop it by
  the process it was started as, never by a name pattern that
  would hit other sessions' runs, and treat it as a run that did
  not complete. A run that is still writing is working, however
  long it takes.
- **A question about a finding** — why that priority, whether a
  sibling is affected — goes to the reviewer afterwards where its
  subsection says how, before the answers are given. It draws on
  the same limit, so it is asked only when the answer changes what
  gets fixed. A question that gets no answer
  changes nothing: the finding is answered without it, and a usage
  limit goes to a person as under Capacity.
- **On GitHub otherwise,** asked as the reviewer's subsection says.
- **Answers.** Every finding of a round goes through the sweep
  (→ A fix commit, step 1), a deferred one included, and its answer
  names the class the sweep gave it: "fixed in <sha>", "fixed in
  <sha>, rest of the class deferred" where the fix commit's last
  pass left part of it, "not a bug: <reason>" or, from round 3,
  "deferred to a follow-up PR". On GitHub the answer goes in the
  finding's thread, which is then resolved; locally it is appended
  to the round's line, a clause per finding,
  `<title> (<path:line>): class <n>, <answer>`.
- **Handles.** Write a reviewer's `@` handle only in the comment
  that asks it for a review. Anywhere else — a body, a commit or
  squash message, an answer, reviewer text quoted anywhere on
  GitHub — a mention starts it too; write the name there without
  the `@`.
- **A run that did not complete** reviewed nothing: it is no round,
  and nothing is posted for it. Retry once when the reason is
  transient, a network error or a timeout. A usage limit goes to a
  person as under Capacity; any other reason — a lost sign-in, a
  missing environment, an option the CLI rejects — goes to whoever
  merges with the reviewer's own message.
- Stacked pull requests are each reviewed against their own base,
  so their rounds run in parallel.

### Codex

- **Model:** `<model>` is `gpt-6-sol`, `<effort>` is `medium`.
  This line is the only place to change them. The commands below
  use the placeholders and set them, and the provider `openai`, on
  every call, since a user's Codex configuration — `model`,
  `review_model`, `model_provider` — would otherwise win. The rest
  of that configuration stays, the sign-in's store included. A
  run's log header must show `provider: openai`, `model: <model>`
  and `reasoning effort: <effort>`; a run whose header shows other
  values is stopped and is no round. The `## Review` line takes
  model and effort from that header. A review only finds; the
  newest frontier model is not needed for it.
- **Capacity:** `sh scripts/codex-quota.sh --model <model>` reads
  the limits of the account the CLI is signed in to, at no cost:
  what is used of each window, when it resets, and any reset
  credit. It exits 1 at the limit and 2 when it cannot tell; at 2,
  run anyway. 3 is a usage error. It also says when the model retires and what
  replaces it, or when a newer model of the same line exists;
  switching is a change to the Model line, which the person
  decides. GitHub reviews have a code-review limit of their own
  that it does not show; there the connector's reply is the only
  signal. Redeeming a reset credit is the person's decision.
- **Local:** `codex login status` exits 0. `<run>` is
  `<pr>-<n>`, the pull request's number and the round's, plus a
  suffix for a repeated attempt. Run in the background — it takes
  minutes:

      git worktree add --detach <scratch>/codex-<run> <head sha> &&
        codex exec -C <scratch>/codex-<run> review \
        -c model_provider=openai \
        --base hostwarden/<base> -m <model> -c review_model=<model> \
        -c model_reasoning_effort=<effort> \
        -o <scratch>/codex-<run>.md \
        > <scratch>/codex-<run>.log 2>&1

  The run completed only when it exited 0 and left `<run>.md` not
  empty; otherwise `<run>.log` says why. The log's header names the
  `session id`. That session holds the review's output, not the
  reviewer's own thread, which ran apart from it: a question
  resumed there is answered by a model that reads the finding and
  the code again, not by the one that found it. The question is
  written to a file, since finding text carries quotes; it has an
  answer only when the command exits 0, leaves the answer file not
  empty, and its log header shows the same three values:

      codex exec -C <scratch>/codex-<run> resume <session id> - \
        -c model_provider=openai \
        -c model=<model> -c model_reasoning_effort=<effort> \
        -o <scratch>/codex-<run>-a<k>.md \
        < <scratch>/codex-<run>-q<k>.md \
        > <scratch>/codex-<run>-q<k>.log 2>&1

  Remove the worktree once the answers are given, or once the run
  did not complete.
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
3. Before pushing, give the commit's range to the reviewer that
   swept, with the findings it answers, in passes as the own review
   runs them. Fix what it reports at the current round's level by
   amending the same commit.
4. Push, then request the next round. Never request one after only
   answering findings.

Each time a continued reviewer or a sweep is given findings, it
also gets the earlier ones, the own review's included, a line each:
title, class, `path:line`, answer. The own review's live only in
the session; a session that takes over a pull request has the
`## Review` lines and the deferred list.

A finding against a guard hook follows `repo-release.md` → Guard
findings.

### Sharpening the reviewer

A second-review finding is one the own review missed unless it is
answered "not a bug" or the own review had already reported it, as
far as the session knows.
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
  current head, as its subsection says for GitHub or with a
  `## Review` line naming that SHA, or it was skipped as under
  Capacity.
- No unresolved thread, every local finding answered in its
  round's line, CI green, not a draft, and GitHub reports the pull
  request CLEAN.
- After any rebase, conflicts included, no new second review is
  requested or awaited if it had completed on the pre-rebase head
  with nothing open. The session checks its own conflict
  resolution instead: `git range-diff` against the pre-rebase
  head and green CI. Only a new fix commit of its own needs the
  second review again.
- Once a pull request is reported ready, push no new commit without
  telling whoever merges, or an unreviewed head gets merged.
- The merge is
  `gh pr merge <n> -R jpawlowski/hostwarden --squash --match-head-commit <sha>`.
  The squash message carries the why, not only the what: before
  1.0.0 the changelog is rewritten from the code, the pull requests
  and the commit messages.

## Updating a branch

- Rebase on `hostwarden/main`; never merge `main` in, whatever Auto-fix
  suggests, and never as a fallback. Squash your own commits first
  when many conflicts are likely. Push with `--force-with-lease`.
- A stacked branch whose base was squash-merged is rebased onto
  `hostwarden/main` from its fork point: the last commit of the base
  that really lies under the branch. Note it when the stack is
  created, or read it from `git reflog show <branch>`.
  `git merge-base <branch> <old-base-head>` is not it: once the
  base is squashed away it finds an old `main` commit, and the
  rebase replays the base's commits with conflicts.

      git rebase --onto hostwarden/main <fork-point> <branch>

  `git log --oneline hostwarden/main..HEAD` must then show only the
  branch's own commits.

- A pull request that touches `.claude/hooks/` resolves a rebase
  conflict in a separate worktree or scratch clone, never in the
  worktree its own session runs from: conflict markers in the hooks
  break every Bash, Edit and Write call.

## After a merge

Before deleting the merged branch, run
`gh pr list -R jpawlowski/hostwarden --base <branch> --limit 1000`,
since the default stops at
30: GitHub closes a pull request whose base branch disappears.
Retarget each one with
`gh pr edit <number> -R jpawlowski/hostwarden --base main` first.
