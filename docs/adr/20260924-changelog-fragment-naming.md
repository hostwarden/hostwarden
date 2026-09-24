---
id: 20260924-changelog-fragment-naming
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [changelog, release]
---

# Changelog fragments are named by date and slug

## Context

Decided on 2026-09-24. A fragment was named after its branch, which
the desktop app names automatically, such as
`claude-eager-haslett-123721.md`. The name said nothing about the
fragment's content, so a reviewer had to open every file to see
what changed. Several fragments landing the same day was already
the norm — four merged today alone.

## Decision drivers

- A fragment's name should say what it holds, without opening it.
- Several fragments merge the same day; a bare date cannot tell
  them apart.
- A fragment is committed before its pull request opens, so no PR
  number exists yet to name it with.
- `docs/adr/YYYYMMDD-slug.md` already sets a date-and-slug shape.

## Considered options

### `<date>-<slug>.md` — chosen

The day as `YYYYMMDD`, then a lowercase, hyphenated summary the
author writes from the fragment's own content — the same shape
`docs/adr/` uses. Against it: two fragments could in principle pick
the same slug on the same day; nothing catches that mechanically.

### `<date>-<slug>-<PR-number>.md`

Mechanically unique. Lost: the fragment is written in the first
commit, before the pull request exists, so the number is not yet
known; naming it would need a rename once the pull request opens,
or an empty draft opened first just to reserve a number.

### `<date-and-time>-<slug>.md`

ISO time added to the date. Lost: two agents in a merge queue can
still commit within the same minute, so it does not actually
guarantee uniqueness, and it makes every name longer for a
guarantee it fails to deliver.

### `<slug>.md`, no date

Shortest option. Lost: it drops the "when was this drafted" signal
that motivated the change, and a fragment can sit unmerged for days
while its pull request is in review.

## Decision

A fragment is `changelog.d/<date>-<slug>.md`. The pull request's
author writes the slug when creating the fragment. A same-day
collision is resolved by picking a more specific slug, not by a
mechanical suffix.

## Consequences

`repo-release.md` → CHANGELOG.md and `pull-requests.md` → The
changelog fragment carry the naming rule.
`scripts/changelog-release.sh` globs `changelog.d/*.md` and reads
no structure from the name, so it needed no logic change, only its
comment and its stray-file message. A slug collision remains
possible in principle; content-driven slugs make it unlikely in
practice.

## Confirmation

Two fragments landing in `changelog.d/` with the identical name at
once — a real merge conflict on the filename itself — would show
this stopped holding.
