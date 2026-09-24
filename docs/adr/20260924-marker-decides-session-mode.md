---
id: 20260924-marker-decides-session-mode
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [guard, development]
---

# The workspace marker decides the session mode

## Context

Decided in #33 on 2026-09-21. A development checkout and an
operator's checkout were identical — same origin, same `main`,
`memory/` gitignored inside the tree — so neither job could be
enforced, and a shared team workspace had no way to stay in step.

## Decision drivers

- Enforcement — denying Edit/Write in operations, `ssh` and `sudo`
  in development — needs a signal every hook can read without
  asking.
- A fork's origin is never `hostwarden/hostwarden`, so the remote
  URL cannot tell operations from development.
- `memory/` already has to be its own git repository for a shared
  team workspace to stay in step, marker or not.

## Considered options

### `memory/.hostwarden-workspace`, `memory/` as its own repository — chosen

`bin/hostwarden-init` sets `memory/` up as its own git repository
from `templates/workspace/`; the marker's presence, not its content,
means operations. Against it: creating the marker by hand, without
running init, puts a checkout into operations mode with no
workspace remote to sync against.

### The remote URL

Treat an origin matching the project's own repository as
operations, anything else as development. Lost: a fork's origin
never matches, so it would always read as development, and the
project's own clone used to develop Hostwarden would misread as
operations.

### An environment variable or a launch flag

Set `HOSTWARDEN_MODE` or pass `--operations` at startup. Lost: the
mode would depend on how a session happened to be started rather
than which checkout it is, and drift the moment somebody forgot to
set it.

## Decision

`memory/.hostwarden-workspace` existing with `memory/.git` a
directory means operations; anything else, a linked worktree
included, means development. `AGENTS.md` → Development or
Operations names the check; a SessionStart hook announces the
result and `guard-mode.sh` enforces it for the rest of the session.

## Consequences

A linked worktree never carries `memory/`, so it is always
development regardless of its parent checkout's mode, as `AGENTS.md`
already states. A fork needs nothing extra: cloning it and running
`hostwarden-init` gives it the same two modes as the canonical
repository.

## Confirmation

`guard-mode-test.sh` runs `hostwarden-init` against a checkout with
and without the marker, and adds a foreign remote to a development
checkout; a mode read from the remote or an environment variable
instead of the marker would fail it.
