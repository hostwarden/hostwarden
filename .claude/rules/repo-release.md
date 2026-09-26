---
paths:
  - "VERSION"
  - "CHANGELOG.md"
  - "changelog.d/**"
  - ".github/**"
  - ".claude/hooks/**"
  - "lib/**"
  - "scripts/**"
  - "tests/**"
  - ".githooks/**"
  - "mise.dev.toml"
description: Versioning, tagging, porting from Heinzel, where code
  and tests go, and what counts as a guard finding — for work on the
  Hostwarden repository itself, not for sysadmin sessions.
---

# Releasing Hostwarden

## VERSION

Hostwarden's releases start at **1.0.0**; Heinzel's numbering is
not continued.

**Bump `VERSION` only to cut a release.** A bump landing on `main`
makes `.github/workflows/tag-release.yml` create and push a tag, so
a bump is the release, not a step towards it.

Tags are never created by hand. Commit the bump, with the
changelog folded (→ CHANGELOG.md), push, and let the workflow tag
it.

The workflow signs every tag with the release key, an SSH key held
only in the repository secret `RELEASE_SIGNING_KEY`, and verifies
it against `.github/release-signers` before pushing; without the
secret, or with another key in it, no tag is pushed. A new key is
added to that file and to `website/docs/running-it/setup/updates.md`
→ Release signatures, line and fingerprint, with
`valid-after=<date>`, in one pull request, and a release signed
with the old key follows before the secret is replaced; the old
key's line stays in both, bounded with
`valid-before=<date>`, so every tag it signed still verifies. A
bound holds against the tag's own date, which the signer picks, so
a leaked key is removed from both instead: the tags it signed stop
verifying, and a new release under the new key is the way forward.
The workflow tags as the GitHub account hostwarden-release, whose
only key is the release key, as a signing key, so GitHub shows the
tags as verified; a rotation replaces that key on the account when
the secret changes, and a leaked one comes off the account at once
(`docs/adr/20260926-release-tags-signed-with-dedicated-ssh-key.md`).
`bin/hostwarden-update` verifies each tag against the file of the
version a checkout is on, never the tag's own, and hands the file of
each release in between that verifies on to the next: a new key
reaches a checkout only through that release the old key signed.
After a leaked key, each checkout takes its next release by hand,
as the updates page says
(`docs/adr/20260926-release-key-from-the-checked-out-version.md`).

`VERSION` holds a semver string and nothing else. Release notes live
in `CHANGELOG.md`. The session-start hook compares the version
before and after an update and tells the user what changed; users
can follow a release line, pin to a tag or opt out
(`bin/hostwarden-update --help`). A release line is found by its
`vX.Y.Z` tags alone: there are no moving tags such as `v1`. An
operations checkout on `main` that never chose follows `main` until
a release of 1.0.0 or later exists; its next update then records
the major line of the newest release and moves to it. `--unpin`
records `main` for whoever tests it.

## CHANGELOG.md

Keep-a-Changelog style, newest first.

**No pull request adds to `CHANGELOG.md` but the release's own**
(→ At a release, below). Parallel pull requests that all append to
one section conflict every time. Each pull request with a
user-visible change adds one file instead,
`changelog.d/<date>-<slug>.md`, `<date>` the day it is written as
`YYYYMMDD` and `<slug>` a lowercase, hyphenated summary of the
change, at most 50 characters — the same shape
`docs/adr/YYYYMMDD-slug.md` uses (`docs/architecture-decisions.md`
→ The record). The pull request's author writes the slug, since it
is the only point with the entry's actual content in hand. On the
rare day two fragments would land on the same slug, the second one
picks a more specific slug; nothing mechanical enforces uniqueness.
The file holds its entry under the Keep-a-Changelog section it
belongs to:

    ### Fixed

    - **Unraid counts a disk in SLEEP mode as asleep.** Housekeeping
      reported it as unknown, because only STANDBY was recognised.

The section is one of Added, Changed, Deprecated, Removed, Fixed and
Security; a pull request that makes two changes of different kinds
gives each its section in the same file. An entry's further lines
indent by two spaces, and it is prose, without a code block.
`scripts/changelog-release.sh --check`, a step of
`scripts/check.sh`, holds every fragment to this form.

**One entry per change, written for someone who uses Hostwarden**
— what it does for them now, not what the diff touched. A bold lead
clause, then the detail in a sentence or two. The lead clause alone
is what `bin/hostwarden-update` shows after an update, for each
release it brought, and to someone following `main` when the entry
is new, changed or no longer listed, so it has to stand on its own.

**A change is user-visible** when someone running an operations
checkout would notice it: what a session does, asks or reports, a
skill, a rule under `rules/`, a `bin/` script, the documentation a
user reads. A pull request that changes only how Hostwarden is
developed — `.claude/rules/`, `.claude/agents/hostwarden-reviewer.md`,
`.github/`, `scripts/`, the test matrices, `CONTRIBUTING.md`,
`docs/project-structure.md`, `docs/architecture-decisions.md`,
`docs/adr/` — needs no fragment, and neither does a
change of wording that changes nothing a user does or sees.

**What is unreleased describes the state that will ship, not the
way it was reached.** Nothing in `changelog.d/`, or under a
`## Unreleased` still in `CHANGELOG.md`, has reached a user, so a
thing introduced and then withdrawn before the release is not two
entries — it is none. A pull request that withdraws or changes
something not released yet edits or deletes the entry that
introduced it, in its fragment or under that `## Unreleased`,
rather than adding one that takes it back. Once a release is cut
its section is history and is never edited again.

**At a release,** the pull request that bumps `VERSION` runs
`sh scripts/changelog-release.sh`. It turns a `## Unreleased` left
in `CHANGELOG.md` into the new version's section, or starts one
above the newest release, adds every fragment's entries grouped by
section, and deletes the fragments. Whoever cuts the release then
smooths the section — one entry for what several pull requests did
to one thing, the most interesting first — and commits `VERSION`,
`CHANGELOG.md` and the deleted fragments as one commit. What merges
while the release waits arrives with its next rebase, and
`--check` fails on each fragment older than the bump until the
fold has run again: it adds those entries to the end of the
section it wrote, where they are merged in by hand, and the commit
is amended. A fragment committed after the bump, a pull request
queued behind the release, ships after it and stays.

`CHANGELOG.md` and its fragments are the only files in the
repository where a change may be described *as a change*. The
decision records in `docs/adr/` are history too, of why rather than
what (`docs/architecture-decisions.md`).
Instruction files describe the current state and nothing else: no
"previously", no "this used to live in", no migration notes. A
reader of `rules/backups.md` needs to know what to do, not what it
said last month. That rule governs every instruction file, not
just the ones near this one.

## Porting from Heinzel

Hostwarden grew out of
[Heinzel](https://github.com/wintermeyer/heinzel) and branched off
at tag `heinzel-2.22.0`. In the project's own clone the `upstream`
remote points there, read-only and without tags.

Improvements come over selectively — cherry-picked or rewritten,
never merged. Rename what the patch carries to Hostwarden, then add
a trailer:

    Ported-from: wintermeyer/heinzel@<sha>

`git log --grep Ported-from` is then the list of what is already in,
which is the only reason the trailer exists. Nothing is ever pushed
to `upstream`.

The `hostwarden-heinzel-takeover` skill and
`rules/heinzel-legacy.md` are a different matter entirely: they
are a product feature about taking over Heinzel's state on a
user's machines, not a compatibility layer, and they stay.

## CI

`.github/workflows/ci.yml` runs `scripts/check.sh` and nothing
else; its `step` lines are the list of checks. Add a new check
there, never to the workflow alone. An agent session runs only
`--pre-commit` on the workstation: `pull-requests.md` → Checks.
`.github/workflows/review-record.yml` reads the pull request body
instead of the tree (`pull-requests.md` → The review record).

Tool versions are pinned in `mise.dev.toml` and kept current by
Renovate. Setup, including the git hooks, is in
`CONTRIBUTING.md`.

`main` is protected by `.github/rulesets/main.json`. GitHub does
not read the file. Import it once (Settings → Rules → Rulesets →
Import); after a change, update that ruleset rather than importing
again, which would add a second one enforced beside the old:

    gh api -X PUT repos/<owner>/<repo>/rulesets/<id> \
      --input .github/rulesets/main.json

It puts `main` behind the merge queue and requires the `check` and
`review record` jobs; `tests/instructions.sh` fails when a required
name matches no job. `gh pr merge` puts a pull request into the
queue through auto-merge, which the repository allows, set once:

    gh api -X PATCH repos/<owner>/<repo> -F allow_auto_merge=true

Releases are immutable: once published, neither a release's assets
nor its tag can change. That is a repository setting, not a ruleset
rule, so no file carries it; set it once:

    gh api -X PUT repos/<owner>/<repo>/immutable-releases

The queue takes no commit message of its own: a pull request of one
commit lands as that commit, its title and message, which is why a
pull request is squashed before its draft is lifted
(`pull-requests.md` → Lifting the draft).

The repository belongs to the organization `hostwarden`
(`docs/adr/20260924-org-owned-for-merge-queue.md`).

**A change to the taboo guard's rules in
`.claude/hooks/guard-taboos.d/` without a new line in its fixture
matrix, `tests/hooks/guard-taboos/`, is incomplete.** The matrix is
how a taboo stays blocked after somebody refactors the pattern that
blocks it — and it is why `.claude/hooks/**` is in this file's
`paths`. A rule that only loads when someone opens the changelog
does not reach the person editing the guard.

In auto mode, Claude Code does not let an agent edit
`.claude/hooks/guard-*.sh`. The agent builds the change in a scratch
clone and hands the maintainer a patch to apply with `git am`, and a
change to `guard-taboos.d/` or `guard-mode.d/` goes the same way.

## Where code goes

- `bin/` — commands an operator runs, or the instructions run for
  them. No extension: the name is the interface.
- `lib/` — code `bin/` and the hooks share, sourced and never run,
  and in `lib/<script>/` the stages a large `bin/` script sources.
- `.claude/hooks/` — the entry points `settings.json` registers, and
  what they call directly (`shim/`, `git-ssh.sh`, `guard-taboos.d/`,
  `guard-mode.d/`).
- `scripts/` — what developing Hostwarden needs and running it does
  not: CI, releases, reviews, `lab.sh`.
- `tests/` — every matrix, at the path of what it checks:
  `tests/bin/hostwarden-impact.sh` checks `bin/hostwarden-impact`.
  Never a `-test.sh` beside the code. `tests/helpers.sh` holds what
  they share.

A shell or awk file past 500 lines is split along its sections, into
a directory its entry point sources in a fixed order, as
`guard-taboos.d/`, `lib/hostwarden-map/` and
`tests/hooks/guard-taboos/` are. What one part defines, the parts
after it read. A long awk program moves into an `.awk` file of its
own, as `guard-mode.d/scan.awk` is. `scripts/check.sh` fails a file
past the limit; `lib/coord-tokenize.sh`, one awk program held in a
shell variable, is the one exception.

## Guard findings

`guard-taboos.sh` and `guard-mode.sh` are a backstop against the
everyday mistake, not a sandbox against an agent trying to get out.
A review finding against either counts when it is one of three
things: a command an agent plausibly writes on its own, a false
positive that blocks real work, or a regression — a case the
fixture matrix blocked before and passes now.

A construction that exists only to get around the guard does not
count: brace or sequence expansion that builds a flag, a chain of
wrappers, an option value attached to its flag, `eval`, a variable,
a script file. Such a finding is answered "not a bug: outside the
guard's scope" and the thread resolved, not fixed. Every fix of
that kind invites the next variant, and against deliberate evasion
the prose in `AGENTS.md` is the protection, not the pattern.
