# Contributing

For anything beyond a small fix, open an issue first, so the
approach is settled before the work is done. Security problems go
privately, as [SECURITY.md](SECURITY.md) describes.

## Before opening an issue

Read the issues first,
`gh issue list -R hostwarden/hostwarden --state all --limit 1000`,
since the default is open issues only and stops at 30. One that
already covers the new issue, in whole or in part, gets a comment
instead of a second issue proposing the same thing from another
angle: on the issue it was closed as a duplicate of, not on the
closed one, which stays closed; otherwise reopened first when it
was closed as not planned rather than shipped and reopening is
within reach, or commented on as it stands where it is someone
else's issue and it is not. One that is related without covering
it is recorded as below.

## Issue dependencies

When an issue only makes sense to implement after another one
lands — it shares a file the other issue's pull request will
change in an incompatible way, or it needs a memory line or a
mechanism the other issue introduces — set GitHub's native
`blocked by` link on it, not a mention buried in the body. The
flag needs `gh` 2.94 or later; update an older one first:

    gh issue edit <later-n> -R hostwarden/hostwarden \
      --add-blocked-by <blocking-n>

Whoever opens the later issue checks open issues for a real
dependency and sets it themselves, at the time of opening; the
maintainer does not retrofit one onto an issue that is already
open.

A dependency is issue-level ordering an agent should notice before
starting work on the later issue. It is not a substitute for:

- **a checklist inside one issue**, for work that is genuinely one
  piece split into steps rather than several independently
  closeable pieces of work — the reason this project already
  prefers a checklist over opening many small issues for one
  change;
- **a sub-issue**, rejected here for the same reason: it still
  reads as one piece of work broken apart, where a dependency
  links two pieces of work that stand on their own and close on
  their own;
- **a rebase-order decision between two pull requests**, when the
  issues themselves are independent but their pull requests happen
  to touch the same file — settled like any other conflict, by
  whichever branch rebases second
  ([pull-requests.md](.claude/rules/pull-requests.md) → Updating a
  branch), never turned into an issue dependency.

A relation that is real but not a dependency — the same file, or
a mechanism the new issue's design extends without needing the
other merged first — gets GitHub's native `relates to` link
instead. It shows on both issues; set it once, from the new one.
`gh issue` has no flag for this link, and GitHub has not
documented its REST call yet, the relationship being in public
preview. The call takes the other issue's REST database id, not
its number and not the GraphQL id `gh issue view --json id`
returns; the first command gets it:

    gh api repos/hostwarden/hostwarden/issues/<related-n> --jq .id
    gh api -X POST \
      repos/hostwarden/hostwarden/issues/<new-n>/relates_to \
      -F issue_id=<the first command's output>

The link says that two issues relate, not how. Where the new
issue's body does not already say what overlaps, one line in it
does:

    Related: #<n> — both add fields to the same memory file.

An author whose call to set either link is refused — a fork
contributor's account may lack the access — writes the relation
into the new issue's body instead: the `Related:` line above, or
for a dependency one line of the same form,
`Blocked by: #<n> — <what the new issue needs from it>`.

A `relates to` link or a `Related:` line records relatedness,
never order. Which of several open, independent issues gets
tackled first is a call made fresh each time by whoever plans a
wave of work, from the state of things at that moment — what is
mid-revision, what is most urgent — not a property of an issue's
content, and a written "do this before that" goes stale the moment
either issue changes. An issue's author records what it relates
to; whoever dispatches the work decides the order, every time,
from scratch. Never write a recommended order into an issue.

## Setup

Work in a development checkout: a clone of Hostwarden, or of your
fork, without `bin/hostwarden-init`
([docs/operations.md](docs/operations.md#operations-and-development)).
One git worktree per branch keeps parallel sessions apart;
[docs/project-structure.md](docs/project-structure.md) says where
things live.

Clone with symbolic links working, on Windows inside WSL 2
(docs/install.md → Windows). The checks need
ShellCheck, actionlint, betterleaks, `jq` and `python3`. `mise.dev.toml`
pins the versions CI uses; mise asks you to trust it once:

```bash
mise trust mise.dev.toml
MISE_ENV=dev mise install
```

Any recent version from your package manager works too. Once per
clone, let git run the checks — the cheap ones on every commit,
and before every push what the pushed commits need:

```bash
git config core.hooksPath .githooks
```

To try a command on a Linux family instead of guessing its
syntax, install docker or podman (OrbStack provides docker on
macOS); `bin/hostwarden-lab` runs disposable containers with it.
What only a full VM can answer goes to a test clone
([docs/operations.md](docs/operations.md#operations-and-development)).

An agent session opens, watches and hands over its pull request
with the [GitHub CLI](https://cli.github.com), `gh`, signed in
(`gh auth login`) to an account with access to
hostwarden/hostwarden, or to your fork and pull requests upstream
([pull-requests.md](.claude/rules/pull-requests.md)). Working by
hand, the web UI does the same. The checks never call it.

The CLI of the second reviewer — currently the
[Codex CLI](https://github.com/openai/codex), signed in — is
optional: with it, an agent session runs the second review of its
pull request locally instead of asking for one on GitHub
([pull-requests.md](.claude/rules/pull-requests.md#the-second-review)).

## Checks

```bash
sh scripts/check.sh
```

That is what CI runs. An agent session runs only
`sh scripts/check.sh --pre-commit`, and not the hooks above: it
pushes and reads CI
([pull-requests.md](.claude/rules/pull-requests.md#checks)).

## What goes where

The files in `.claude/rules/` hold the conventions for changing
this repository, and the `paths` at the top of each lists the
files it governs. Read the one that covers what you change:

- [instruction-authoring.md](.claude/rules/instruction-authoring.md)
  for the instruction text — where a new instruction belongs, the
  wrap, the example identifiers allowed;
- [repo-release.md](.claude/rules/repo-release.md) for releases,
  CI and the checks;
- [pull-requests.md](.claude/rules/pull-requests.md) for taking a
  pull request from open to merged, checks included.

Claude Code loads them on its own; every other tool has to be
pointed at them.

## Commits and pull requests

[Conventional Commits](https://www.conventionalcommits.org/)
for commit messages and pull request titles. Pull requests are
squash-merged by the merge queue: one of a single commit lands as
that commit, one of several under its title with their messages.
Out of draft, a pull request needs a review record in its body
([pull-requests.md](.claude/rules/pull-requests.md#the-review-record));
for a contribution, the maintainer's session writes it. Update a
branch by rebasing it on `main`, never by merging `main` into it.

An agent opens its pull request as a draft and keeps it one
through its reviews, the fixes and CI. Lifting the draft hands it
to whoever merges, who reviews it and decides whether it is merged
([pull-requests.md](.claude/rules/pull-requests.md#lifting-the-draft)).
A stacked pull request stays a draft until its base is merged
and it sits on `main`.
