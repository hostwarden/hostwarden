---
id: 20260924-no-compat-before-1-0
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [release]
---

# No migrations or compatibility paths before 1.0.0

## Context

Decided on 2026-09-21. Hostwarden had not released anything: `VERSION`
still held Heinzel's 2.22.0, and the first release is 1.0.0. Reviews
kept asking for migration paths, legacy modes and breaking-change
markers whenever a change altered what a user keeps in `memory/` or
how it is laid out.

## Decision drivers

- No installation of Hostwarden exists yet that a change could
  break.
- Compatibility code is reviewed now and kept for good, for users
  who do not exist.

## Considered options

### Change it outright until 1.0.0 — chosen

A change alters user state or layout directly. Against it: someone
following `main` before the release may find their workspace
changed without a guide.

### Migrations from the start

Every change to user state ships with a migration and a
compatibility mode. Lost: there is nothing to migrate from, and each
path would outlive the reason for it.

## Decision

Until 1.0.0 is released, a change alters user state or layout
outright: no migration, no legacy mode, no `feat!` or
`BREAKING CHANGE:` marker, no guide for older installations. A
review finding asking for one is answered with this record.

## Consequences

Changes stay small and reviews shorter. Taking over a Heinzel
installation is not affected: that is a move from another product,
and `hostwarden-heinzel-takeover` and `bin/hostwarden-migrate` keep
it. The first release ends this decision; a record that supersedes
it says what holds after.

## Confirmation

A `v1.0.0` tag. From then on, this record is due to be superseded.
