---
id: 20261110-privilege-lines-live-in-the-logins-memory
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [memory, privileges, accounts]
---

# Privilege lines live in the login's memory file

## Context

2026-11-10. A host's `memory.md` held everything Hostwarden knew
about it, the `Sudo:` line included. A host reached as `alice` on
one day and as `root` or a deploy account on another has no single
answer to "may this login use sudo", and the line in `memory.md`
said whichever login was probed last. The same holds for a home
directory, groups, runtimes installed per user and a crontab.

## Decision drivers

- A privilege line read for the wrong login is a wrong finding, or
  a sudo call that prompts and hangs.
- Host facts must stay in one place every session reads.
- Workspaces in use carry `Sudo:` lines in `memory.md` today.
- Other files beside `memory.md` are told apart by name.

## Considered options

### `user-<login>.md` beside `memory.md`, privilege lines move — chosen

One file per account, created with the first fact that belongs to
one account. `Sudo:`, `Doas:`, `Privilege mode:` and
`Root-equivalent group:` are written there. A line still in
`memory.md` counts for the login the host is reached as until it is
next written, which moves it.

### Per-login file, privilege lines stay in `memory.md`

No change to where existing rules look. Lost: the one kind of fact
that differs most between logins stays ambiguous.

### A `users/` directory per host

Tidier with many accounts. Lost: a second layout rule for one kind
of file, and nothing gained while most hosts have one or two.

### One section per login inside `memory.md`

No new file. Lost: every session reads every account's lines, and
a personal account's facts sit in the file a shared workspace
shares.

## Decision

Facts about one account, the privilege lines among them, are kept
in `user-<login>.md`; `memory.md` keeps what `root` would see the
same way.

## Consequences

`rules/machine-memory.md` → Per-login memory carries the layout and
the reading of a line that has not moved yet. `Root SSH:` and
`Shell:` stay host lines. Local mode has one login and keeps its
facts in `memory.md`. A request to move the lines back, or to
migrate every host at once, is the moment to read this record.

## Confirmation

No test reads the layout. `rules/machine-memory.md` → Per-login
memory and the owner table name the four lines; review holds the
rules that read them to that file.
