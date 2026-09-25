---
paths:
  - ".claude/rules/pull-requests.md"
description: How a session coordinating several open pull requests
  on hostwarden/hostwarden at once behaves — polling, readiness
  before naming a merge command, cleanup, and subagents versus
  chips. For work on this repository, never for a managed host.
---

# Coordinating pull requests

A session that has several pull requests open on
`hostwarden/hostwarden` at once, rather than carrying one of its own
through from open to merged, follows this file for its own conduct.
`pull-requests.md` is the pipeline a single pull request goes
through, whoever runs it; this file is what the session watching
several of them at once does between those steps. Nothing here is
mechanically checked the way the review record is — a coordinating
session runs outside any one pull request's own checks — so it
stays prose, read and followed, never a script.

## Verifying readiness

A pull request's own cached fields are not proof that it is ready to
merge. `mergeStateStatus` and `mergeable` can be stale, and naming a
merge command, or cleaning up a worktree and branch, on either alone
can act on a pull request that has silently changed underneath.
Before naming a merge command:

- CI is green on the actual current head, read fresh
  (`gh pr checks <n> -R hostwarden/hostwarden`), never a rollup that
  could still be reporting an earlier one — the review record
  (`pull-requests.md` → The review record) is one of its required
  checks, so a green run already covers it.
- A real merge has been tried: fetch `hostwarden/main`
  (`pull-requests.md` → The project's branches), and in a scratch
  worktree, `git merge --no-edit <sha>` against it. Only that, not a
  cached field, says whether the merge actually goes through clean.

A background loop that polls for readiness needs its own query
checked against the tool's actual output schema before its silence
is trusted. `gh pr view <n> --json` accepts only the fields it
defines; asking for one it does not know — `mergeQueueEntry` is not
among them — makes `gh` print an error and the field is never set,
so a `case` keyed on it never matches, on any iteration, for the
whole run: from outside, a loop like that looks exactly like one
that has not found a merge yet. Poll real fields instead —
`gh pr view <n> -R hostwarden/hostwarden --json state,mergedAt` for
`state: MERGED` — and give the loop an explicit timeout branch that
reports failure, rather than one that exits quietly.

## The merge queue

On this repository the queue batch-builds several simultaneously
queued pull requests together, and a member whose combined diff
conflicts with another's — most often several pull requests that
each regenerate the same generated file, such as
`docs/adr/README.md` — can silently go `UNMERGEABLE` or drop out of
the queue (`mergeQueueEntry: null`) without the queue retrying it and
without the pull request's own fields ever showing that it happened.
Nothing says in advance which members of a batch will collide, so
queue one pull request at a time regardless: wait for a real
`state: MERGED` (→ Verifying readiness) before queuing the next,
never several together.

## Cleanup after a merge

Removing the worktree, deleting the local and remote branch,
retargeting a dependent pull request, and archiving the session all
wait for the same confirmation, `state: MERGED` read after the fact
— never a queue-acceptance message or a cached field
(→ Verifying readiness). A pull request the queue has accepted can
still fail later in the batch (→ The merge queue); cleaning up on
that alone can delete a worktree and branch for a pull request that
is, in fact, still open.

## The coordinator never merges

Only the user starts a coordinating session, and only the user
merges — a subagent, another session, or a spawned chip never does,
and not because one offers to
(`pull-requests.md` → Lifting the draft: agents never merge). The
coordinator's job is to prepare the exact command from
`pull-requests.md` → Merge-ready, with the full head SHA, and hand
it over once → Verifying readiness holds.

## Subagents versus chips

An `Agent`-tool subagent is for the coordinator's own verification
and research — reading several pull requests, checking a merge,
comparing states — never for implementation work. It does not
resume itself: without a follow-up message it stays idle after
finishing a pass, silently, easy to miss at a phase boundary, and it
is invisible in the user's session list besides. Development work
goes to a `spawn_task` chip instead, wherever the tool is available:
a chip starts its own real, visible, more autonomous session, which
is what implementation work needs.

An instruction to a subagent that could plausibly be read as
authorizing more automated review than the pipeline's round cap
allows (`pull-requests.md` → Rounds) has to say so explicitly: what
it authorizes and what it does not. "One continued pass on just that
fix" is ambiguous between continuing the existing round and starting
a new one; naming the round and the pipeline step removes the
ambiguity a subagent cannot otherwise resolve from context it was
never given.

## Recommending a tackle order

An order for several open, non-blocking design issues is a judgement
call made fresh each time it is asked for, or before a wave of chips
goes out — never written onto an issue and never reused from an
earlier recommendation. An issue's content changes as it is
reviewed, and a stored "do X before Y" goes stale the same way the
data it was based on does.

## Deferred review findings

A finding deferred at round 3, or left in round 4's list
(`pull-requests.md` → Rounds), is a decision for whoever merges
(→ Decisions go to the user), with the fast follow-up dispatched
promptly once they decide rather than left open indefinitely. No
round of the same pull request is left to fix one in — rounds 1 and
2 defer nothing, and 3 and 4 are its last two — so fixing one after
the round that found it means moving the fix onto its own branch
entirely: a pull request's review
record is a guarantee about what was actually reviewed, and a commit
slipped in afterward breaks that guarantee whether or not the
checker can see it. It usually cannot — the review record check's
`covered()` trusts the record's prose for a rebase or a squash line
and does not diff commits itself, so a fix it cannot place fails the
check without saying why.

## Decisions go to the user

A decision that is the user's to make — which order, which pull
request, whether to accept a deferred finding — is put to them
directly, with concrete options (`AskUserQuestion` where the tool
has it), never folded into a routine status message as a hint they
have to notice and act on themselves.
