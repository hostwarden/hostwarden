---
paths:
  - "VERSION"
  - "CHANGELOG.md"
  - ".github/**"
  - ".claude/hooks/**"
  - "scripts/**"
  - ".githooks/**"
  - "mise.dev.toml"
description: Versioning, tagging, porting from Heinzel, and what
  counts as a guard finding — for work on the Hostwarden repository
  itself, not for sysadmin sessions.
---

# Releasing Hostwarden

## VERSION

The first Hostwarden release is **1.0.0**. Heinzel's numbering is
not continued, and `VERSION` keeps the inherited 2.22.0 until that
release is cut.

**Do not bump `VERSION` on the way there.** A bump landing on `main`
makes `.github/workflows/tag-release.yml` create and push a tag, so
a bump is the release, not a step towards it.

Tags are never created by hand. Commit the bump, push, and let the
workflow tag it.

`VERSION` holds a semver string and nothing else. Release notes live
in `CHANGELOG.md`. The session-start hook compares the version
before and after an update and tells the user what changed; users
can follow a release line, pin to a tag or opt out
(`bin/hostwarden-update --help`). A release line is found by its
`vX.Y.Z` tags alone: there are no moving tags such as `v1`.

## CHANGELOG.md

Keep-a-Changelog style, newest first, under `## Unreleased` until a
release is cut.

**One entry per change, written for someone who uses Hostwarden**
— what it does for them now, not what the diff touched. A bold lead
clause, then the detail in a sentence or two.

**`## Unreleased` describes the state that will ship, not the way
it was reached.** Nothing under it has reached a user, so a thing
introduced and then withdrawn before the release is not two
entries — it is none. Delete the entry that introduced it rather
than adding one that takes it back. Once a release is cut its
section is history and is never edited again; only `## Unreleased`
can still be rewritten this way, and that is the whole reason it
can.

This is the only file in the repository where a change may be
described *as a change*. Instruction files describe the current
state and nothing else: no "previously", no "this used to live
in", no migration notes. A reader of `rules/backups.md` needs to
know what to do, not what it said last month. That rule governs
every instruction file, not just the ones near this one.

## Porting from Heinzel

Hostwarden grew out of
[Heinzel](https://github.com/wintermeyer/heinzel) and branched off
at tag `heinzel-2.22.0`. The `upstream` remote points there,
read-only and without tags.

Improvements come over selectively — cherry-picked or rewritten,
never merged. Rename what the patch carries to Hostwarden, then add
a trailer:

    Ported-from: wintermeyer/heinzel@<sha>

`git log --grep Ported-from` is then the list of what is already in,
which is the only reason the trailer exists. Nothing is ever pushed
to `upstream`.

The `hostwarden-adopt` skill and `rules/heinzel-legacy.md` are a
different matter entirely: they are a product feature about taking
over Heinzel's state on a user's machines, not a compatibility
layer, and they stay.

## CI

`.github/workflows/ci.yml` runs `scripts/check.sh` and nothing
else; its `step` lines are the list of checks. Run it before
pushing, and add a new check there, never to the workflow alone:

    sh scripts/check.sh

Tool versions are pinned in `mise.dev.toml` and kept current by
Renovate. Setup, including the git hooks, is in
`CONTRIBUTING.md`.

`main` is protected by `.github/rulesets/main.json`. GitHub does
not read the file. Import it once (Settings → Rules → Rulesets →
Import); after a change, update that ruleset rather than importing
again, which would add a second one enforced beside the old:

    gh api -X PUT repos/<owner>/<repo>/rulesets/<id> \
      --input .github/rulesets/main.json

Its required check is the `check` job in `ci.yml`, and
`instructions-test.sh` fails when the two names part.

**A change to `.claude/hooks/guard-taboos.sh` without a new line in
the fixture matrix is incomplete.** The matrix is how a taboo stays
blocked after somebody refactors the pattern that blocks it — and
it is why `.claude/hooks/**` is in this file's `paths`. A rule that
only loads when someone opens the changelog does not reach the
person editing the guard.

Auto mode denies an agent edits to `.claude/hooks/guard-*.sh`. The
agent builds the change in a scratch clone and hands the maintainer
a patch to apply with `git am`; it never writes the file another way.

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
