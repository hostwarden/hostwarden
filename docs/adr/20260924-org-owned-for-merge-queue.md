---
id: 20260924-org-owned-for-merge-queue
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [governance, ci]
---

# An organization owns the repository, not a person

## Context

Decided in #221, its reason written into `repo-release.md` in #248.
The repository lived under Julian's personal account as
`jpawlowski/hostwarden`. Pull requests from parallel agent sessions
run against a moving `main`; a queue that serializes their merges
needs one, but GitHub offers it only to a public repository an
organization owns, or a private one on GitHub Enterprise Cloud.

## Decision drivers

- Many pull requests run against a moving `main` at once; a queue
  checks each against the base it will actually land on.
- A day's wave once spent 365 CI runs, 69 of them redundant reruns
  on pushes to `main` a queue would replace (#222).

## Considered options

### An organization owns the repository, public — chosen

Move to `hostwarden/hostwarden`, public, with the merge queue and
stacked pull requests enabled. Against it: a GitHub App granted to
the personal account, such as the Codex connector, has to be
re-granted to the organization, and the repository is now public.

### Stay under the personal account, public

No merge queue: each pull request keeps checking against whatever
`main` was at its last push, not the base it will actually land on,
and a push straight to `main` reruns CI a queue would have made
redundant (#222).

### An organization owns the repository, private, on GitHub Enterprise Cloud

Keeps the repository private, still under an organization, with the
queue from an Enterprise Cloud subscription instead of from being
public. Rejected: this project does not carry an Enterprise Cloud
subscription.

## Decision

The repository moves to the `hostwarden` organization and becomes
public, `hostwarden/hostwarden`; `main` sits behind the merge queue
once ready (#222).

## Consequences

`.claude/rules/repo-release.md` → CI carries the ruleset and the
merge command; every `gh` call in `.claude/rules/pull-requests.md`
names `hostwarden/hostwarden`. A proposal to move the repository
back to a personal account, or to keep it private, is answered with
this record.

## Confirmation

The merge queue stops working, or `main` takes a direct push
outside it, the day the repository leaves the organization or goes
private without Enterprise Cloud.
