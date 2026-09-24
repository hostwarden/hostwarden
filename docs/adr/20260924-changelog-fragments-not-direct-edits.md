---
id: 20260924-changelog-fragments-not-direct-edits
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [release, tooling]
---

# Changelog entries as per-PR fragments

## Context

Decided 2026-09-24, once the project moved to a public repository
with several pull requests open at once. Every pull request had
been appending its own entry to the same `## Unreleased` section of
`CHANGELOG.md`, and parallel ones kept conflicting on the same list.
The merge queue also does not use the message typed at merge time,
so a squash-time note describing the change was never actually
read.

## Decision drivers

- Parallel pull requests editing one shared section conflict on
  every merge.
- The merge queue ignores whatever changelog text is typed at merge
  time.
- Someone following `main` before a release should still see what
  changed, not just what shipped.

## Considered options

### One fragment file per branch, folded at release — chosen

A pull request with a user-visible change adds
`changelog.d/<branch>.md` instead of editing `CHANGELOG.md`; the
release step folds every fragment into the new version's section
and deletes them. Against it: a second file per pull request,
diffed on its own, before it ever reaches the real changelog.

### Keep editing `CHANGELOG.md` directly

Every pull request appends its entry to `## Unreleased`. Lost: this
is exactly what caused the recurring merge conflicts the decision
was made to fix.

## Decision

`CHANGELOG.md` is touched only by the release that folds fragments
into it, or to edit or remove an entry still unreleased. A pull
request with a user-visible change adds one file,
`changelog.d/<branch>.md`, instead; the release step merges every
fragment into the new version's section and removes them.

## Consequences

`.claude/rules/repo-release.md` → CHANGELOG.md carries the fragment
format, what counts as user-visible, and the fold step;
`.claude/rules/pull-requests.md` → The changelog fragment points
pull requests at it. `docs/adr/` and other files that change only
how Hostwarden is developed need no fragment.

## Confirmation

A merge conflict on `CHANGELOG.md`, or a pull request editing it
directly, is the moment to reread this record.
