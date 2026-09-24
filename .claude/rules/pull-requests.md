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

    git fetch -q https://github.com/hostwarden/hostwarden.git \
      +refs/heads/<branch>:refs/hostwarden/<branch>

Every `gh` command below names the repository the same way, with
`-R hostwarden/hostwarden`.

## Checks

CI is the only gate for the tests. A run of the guard matrix on the
workstation starts tens of thousands of processes, endpoint
protection inspects each, and parallel sessions compete for the
cores; CI runs all of `scripts/check.sh` in one to two minutes.

- Before each commit, a pull request session runs the cheap
  checks, which take seconds: `sh scripts/check.sh --pre-commit`,
  the secret scan of the staged changes and `instructions-test.sh`
  on exactly what is staged. A credential caught there never
  reaches the remote; a line over 80 columns, a pointer at a
  heading that is not there or a second word for an override fails
  there, not in CI.
- Beyond that, it runs neither `scripts/check.sh` nor a test script
  (`guard-taboos-test.sh`, `instructions-test.sh` on its own, …) on
  the workstation. It pushes, waits with
  `gh pr checks <number> -R hostwarden/hostwarden --watch`, and on
  a failure reads
  `gh run view <run-id> -R hostwarden/hostwarden --log-failed`.
- The one exception is a guard hook patch the maintainer applies
  with `git am` (`repo-release.md` → CI), which CI does not see
  until then. The matrix of the hook it changes runs exactly once,
  in the scratch clone the patch is built in, when it is done.
- A clone agents push from does not set up the git hooks from
  `CONTRIBUTING.md`: the pre-push hook would run the checks on
  every push.
- CI runs `check` on every push to a pull request: on a draft what
  `--pre-push` runs for its commits against the base, each matrix
  only when they touch what it reads; out of draft and in
  the merge queue all of `scripts/check.sh`. A push to `main` is
  not checked again: what the queue merges is the commit it
  checked. A commit that bypasses the queue is checked by hand,
  `gh workflow run ci.yml -R hostwarden/hostwarden --ref main`.

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
  such a request before it lifts the draft. A request after the
  lift puts the pull request back into draft until the second
  review is through (→ Lifting the draft).

`<base>` below is the pull request's base branch as
`gh pr view <n> -R hostwarden/hostwarden --json baseRefName`
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
3. Push. The pull request stays a draft; the second review
   follows where it is required.

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
    head on: the body gets `## Second review skipped` and a line
    `<sha>: <reason>, resets <time>; <who> decided`, the head's
    SHA in full and `-` for a time where no limit resets. Each
    later head the session records gets such a line too, the same
    decision applied, not a new one taken;
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
  `<title> (<path:line>): class <n>, <answer>`, the clauses
  separated by `; `.
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
  so their rounds run in parallel; each lifts its draft as
  → Lifting the draft says.

### The review record

CI's `review record` check reads the pull request body whenever it
or the head changes, and is required like `check`. A draft passes,
and so does a pull request a bot opened, such as Renovate's: whoever
merges reviews those. Otherwise the body needs one of:

- a run line under `## Review` in the format above, `<left>`
  included, or a skip line under `## Second review skipped`
  (→ Capacity), that names the head's full SHA;
- a rebase or squash line naming the head, its closing words
  included (→ Merge-ready, → Lifting the draft), whose old head has
  one of these in turn.

Each local run's line with findings must carry one clause per
finding, told apart by title and place, whose answer is "fixed in
<sha>", "not a bug: <reason>" or "deferred to a follow-up PR"; the
check does not know which round allows which. A GitHub run's
answers are its threads, which it does not read. A heading in a
fenced block is an example, not the record. It proves that the
record exists, not that the review was good. CI runs the workflow
and the checker as the default branch has them, so a pull request
is held to the gate `main` has; a change to either counts once it
is merged. It holds the second review
to Required (→ Review); set to "on request", the check comes out of
the ruleset. A pull request a person opened without an agent gets
its record from the session whoever merges hands it to, which runs
the second review on it as on its own, or from a skip line they
decide on.

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
  run; a comment `@codex review` asks for one, on a draft too, so
  the order is the same on both paths. It has completed
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
Before the session lifts the draft, it adds
each missed finding to the one open issue titled "Sharpen
hostwarden-reviewer": a checklist line with the pull request's
number, the finding's title, its class from the answer, and the
question that class lacked. It opens that issue when none is
open. At three
unchecked lines, it proposes to the person a pull request that
sharpens the reviewer and closes the issue, as a task chip where
the tool has them. A new class is the exception; a question added
to an existing one is the rule.

## Lifting the draft

A pull request is opened as a draft (`gh pr create --draft`) and
stays one while agents carry it; one they carry that is out of
draft goes back with
`gh pr ready <n> -R hostwarden/hostwarden --undo`, and whoever
merges is told. Lifting the draft hands it to whoever merges: a
person, who reviews it and decides whether it is merged; agents
never merge. So it is the last step, taken once everything an
agent can do is done:

- the own review is through, and the second review, where it is
  required, has completed on the current head as → Merge-ready
  counts it, a rebase included, or was skipped as under Capacity
  with a line for this head;
- every finding is answered, in its thread or its round's line, no
  thread is unresolved, the deferred list is written, and the
  missed findings are in the reviewer's issue (→ Sharpening the
  reviewer);
- a P0 or P1 left for whoever merges, from round 4 or the own
  review's deferred list, has already been put to them;
- CI is green on the current head, and
  `gh pr view <n> -R hostwarden/hostwarden --json mergeable` shows
  `MERGEABLE`. That is a draft's scoped run: the lift starts the
  full `check` and the `review record`, and the session waits for
  both. A failure puts the pull request back into draft, and
  whoever merges is told;
- the branch is one commit on its base, whose message is the
  squash text: the why, not only the what, since before 1.0.0 the
  changelog is rewritten from the code, the pull requests and the
  commit messages, and the trailers (`Ported-from:`,
  `Co-Authored-By:`) at its end. The squash is
  `git reset --soft $(git merge-base hostwarden/<base> HEAD)` and
  one commit; its tree is the reviewed head's, which
  `git diff <old sha> <new sha>` shows empty, and it is recorded
  under `## Review` as
  `squash, <new sha>: from <old sha>, tree unchanged`, both SHAs in
  full. The body keeps the record and the deferred list;
- a stacked pull request's base is merged, and it has been
  retargeted and rebased onto `hostwarden/main` (→ After a merge,
  → Updating a branch): until then it stays a draft, since its
  base can still change under it. A fresh `hostwarden-reviewer`
  then checks the rebased branch against `hostwarden/main` once,
  since its reviews never saw the base's final state. Its findings
  take the level of the child's last round, that of rounds 1 and 2
  where it had none (→ Rounds): fixed in a fix commit where that
  level fixes them, deferred otherwise.

The lift is `gh pr ready <n> -R hostwarden/hostwarden`.

Once the draft is lifted, the session tells whoever merges before
any push, a commit or a rebase, or a head the agents have not
finished with gets merged.

## Merge-ready

- Where the second review is required, it has completed on the
  current head, as its subsection says for GitHub or with a
  `## Review` line naming that SHA, or it was skipped as under
  Capacity with a line for that head.
- No unresolved thread, every local finding answered in its
  round's line, CI green, not a draft, and GitHub reports the pull
  request CLEAN.
- After any rebase, conflicts included, no new second review is
  requested or awaited if it had completed on the pre-rebase head
  with nothing open, or was skipped there. The session checks its own conflict
  resolution instead: `git range-diff` against the pre-rebase
  head and green CI. It records the rebase under `## Review` as
  `rebase, <new sha>: from <old sha>, range-diff checked`, both
  SHAs in full. Only a new fix commit of its own needs the second
  review again.
- The merge is
  `gh pr merge <n> -R hostwarden/hostwarden --squash --match-head-commit <sha>`,
  which puts the pull request into the merge queue through
  auto-merge (`repo-release.md` → CI). The queue merges it once the
  required checks pass on its group, and takes no message of its
  own: the one commit lands as it is (→ Lifting the draft).

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
`gh pr list -R hostwarden/hostwarden --base <branch> --limit 1000`,
since the default stops at
30: GitHub closes a pull request whose base branch disappears.
Retarget each one with
`gh pr edit <number> -R hostwarden/hostwarden --base main` first.
