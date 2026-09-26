---
id: 20260926-changelog-holds-only-its-release
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [release, tooling]
---

# CHANGELOG.md holds only the release it ships with

## Context

Decided 2026-09-26, right after 1.0.0, whose section alone runs to
some 800 lines. `CHANGELOG.md` kept every release, newest first, and
would only grow. Every release is a signed tag, and its GitHub
release can link to the `CHANGELOG.md` at that tag. The one reader
that needed several releases in one file, an update that skips
some, is what #464 builds for: reading each release's notes at its
own tag.

## Decision drivers

- A reader opening `CHANGELOG.md` wants what this release changed.
- Nothing old is carried along, and a released section is never
  touched again.
- An update across several releases must still show each one's
  notes.

## Considered options

### Only the release it ships with — chosen

A fixed head says where earlier releases are; below it, one
section. The fold replaces the previous release's section. Against
it: "since when is X like this?" is a walk over the tags or
`git log -p -- CHANGELOG.md` instead of one `grep`, and readers used
to Keep a Changelog expect one cumulative file.

### Every release, newest first

What Keep a Changelog describes. Lost: the file grows without end,
and its one advantage, every release in the checkout, is what #464
provides from the tags.

### Only the current major line

Lost: a major line can grow just as long.

### An archive file for older sections

Lost: a second file to keep, for what the tags already hold.

## Decision

`CHANGELOG.md` holds a fixed head and the section of the release it
ships with. `scripts/changelog-release.sh` puts the new section in
place of the previous one; an earlier release's notes are read at
its tag.

## Consequences

`.claude/rules/repo-release.md` → CHANGELOG.md carries the
constraint. "Since when" questions are answered from the tags or
the history, which this record accepts. The fragments in
`changelog.d/` and their fold are unchanged
(`20260924-changelog-fragments-not-direct-edits`).

## Confirmation

After the next release, `CHANGELOG.md` on `main` holds that
release's section alone, and `git show v1.0.0:CHANGELOG.md` still
shows 1.0.0's.
