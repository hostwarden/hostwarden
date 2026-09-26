---
sidebar_position: 1
description: Sharing memory/ across a team, or across your own
  machines, through a private git remote.
---

# A shared workspace

A team — or one admin on several machines — shares the workspace,
`memory/`, through a git remote of its own: a **shared workspace**.
**Keep that remote private:** the workspace holds hostnames,
addresses, the blacklist and the layout of your network. Create it
private; the recommended name is `hostwarden-workspace`, and nothing
checks it. Hostwarden itself stays an unmodified clone that keeps
updating.

1. On the first machine, publish the workspace once:
   ```
   bin/hostwarden-init --remote <private-repo-url> --create
   ```
   It refuses a repository anyone can read, and one that already
   holds commits. A GitHub repository that does not exist yet is
   created private with `gh`, where `gh` is signed in; anywhere
   else it prints how to create one. Then it commits the workspace
   and pushes it.
2. On every other machine, clone Hostwarden and join:
   ```
   bin/hostwarden-init --clone <private-repo-url>
   ```
   On a workspace `bin/hostwarden-init` has only just created,
   with nothing written to it yet, that works too: the clone takes
   its place, and your `user.md` stays.

You rarely type either. `bin/hostwarden-init` run in a terminal on
a new workspace asks which of the two you want, or whether the
workspace stays on this machine. Where you did not decide there,
the first session asks, once: a new private repository, an
existing workspace, this machine only, or not now. "This machine
only" is kept as `Workspace remote: none` in your `user.md`, and
`bin/hostwarden-init --local` records the same.

## Staying in step

From then on it keeps itself in step. Every session starts with
`bin/hostwarden-sync pull` (Claude Code runs it for you) and ends
with a commit of the files it changed — only those, so parallel
sessions on one machine keep out of each other's work. It asks once
per session before pushing. A changelog both machines added to
merges on its own; two different edits of the same `memory.md` stop
the pull and are left for you.

## Personal files

Personal files never reach the remote: `memory/.gitignore` names
`user.md`, `blacklist.md`, `readonly.md`, `opencode.json` and
`ssh_config`. Add your own machine's hostname directory there (e.g.
`/machines/my-laptop/`). Alone on several machines, you may want your
SSH usernames on all of them: delete the `/user.md` line — unless one
of them is an operations host, which needs a `user.md` of its own.

## Your operator handle

Hostwarden asks each of you once for a short handle, such as
`alice`, and keeps it as `Operator:` in your `user.md`. It names you
in every journal entry (`[alice as root] …`) and every decision you
record, so the team can tell whose work is whose, even when you all
log in as `root`. The handles in use are listed in the shared
`operators.md`, and one someone else has already taken is turned
down. Use the same handle on each of your own machines. It lands in
the machines' journals, which keep it as long as their logs are
retained and wherever they are shipped, so choose what you are
comfortable with there: initials or a code serve as well as a name,
and changing it later does not rewrite old entries. Your full name,
`Operator name:`, stays for the email signature.

## When someone leaves

When someone stops working with you, tell Hostwarden: their line in
`operators.md` gets `(inactive since <date>)`. The handle stays
reserved for good, since journals and decisions still name it, and
the suffix goes again if they come back. An operations host's line
reads `(operations host)`.

## Secret scanning

Every workspace commit is scanned for secrets by
[betterleaks](https://github.com/betterleaks/betterleaks), and every
push scans the whole history again. A push without it is refused,
and so is a commit once the workspace has a remote; without one, a
commit only says it was not scanned.
