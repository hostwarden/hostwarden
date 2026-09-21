---
paths:
  - "VERSION"
  - "CHANGELOG.md"
  - ".github/**"
  - ".claude/hooks/**"
  - "scripts/**"
  - ".githooks/**"
  - "mise.dev.toml"
description: Versioning, tagging and porting from heinzel — for
  work on the hostwarden repository itself, not for sysadmin
  sessions.
---

# Releasing hostwarden

## VERSION

The first hostwarden release is **1.0.0**. heinzel's numbering is
not continued, and `VERSION` keeps the inherited 2.22.0 until that
release is cut.

**Do not bump `VERSION` on the way there.** A bump landing on `main`
makes `.github/workflows/tag-release.yml` create and push a tag, so
a bump is the release, not a step towards it.

Tags are never created by hand. Commit the bump, push, and let the
workflow tag it.

`VERSION` holds a semver string and nothing else. Release notes live
in `CHANGELOG.md`. The session-start hook compares the version
before and after `git pull` and tells the user what changed; users
can pin to a tag or opt out (`bin/hostwarden-update --help`).

## CHANGELOG.md

Keep-a-Changelog style, newest first, under `## Unreleased` until a
release is cut.

**One entry per change, written for someone who uses hostwarden**
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

## Porting from heinzel

hostwarden grew out of
[heinzel](https://github.com/wintermeyer/heinzel) and branched off
at tag `heinzel-2.22.0`. The `upstream` remote points there,
read-only and without tags.

Improvements come over selectively — cherry-picked or rewritten,
never merged. Rename what the patch carries to hostwarden, then add
a trailer:

    Ported-from: wintermeyer/heinzel@<sha>

`git log --grep Ported-from` is then the list of what is already in,
which is the only reason the trailer exists. Nothing is ever pushed
to `upstream`.

The `hostwarden-adopt` skill and `rules/heinzel-legacy.md` are a
different matter entirely: they are a product feature about taking
over heinzel's state on a user's machines, not a compatibility
layer, and they stay.

## CI

`.github/workflows/ci.yml` runs `scripts/check.sh` and nothing
else; its `step` lines are the list of checks. Run it before
pushing, and add a new check there, never to the workflow alone:

    sh scripts/check.sh

Tool versions are pinned in `mise.dev.toml` and kept current by
Renovate. Setup, including the opt-in git hooks, is in
`CONTRIBUTING.md`.

**A change to `.claude/hooks/guard-taboos.sh` without a new line in
the fixture matrix is incomplete.** The matrix is how a taboo stays
blocked after somebody refactors the pattern that blocks it — and
it is why `.claude/hooks/**` is in this file's `paths`. A rule that
only loads when someone opens the changelog does not reach the
person editing the guard.
