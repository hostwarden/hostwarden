---
sidebar_position: 1
description: Working on Hostwarden's own source in a development
  checkout, which reaches no server.
---

# Working on Hostwarden

A Hostwarden checkout does one of two jobs, and the workspace decides
which. Where `memory/` is the workspace, the checkout administers
servers — see [Running Hostwarden](../running-it/index.md). Without
one, and in every git worktree, whatever its main checkout is, the
session works on Hostwarden itself instead.

## The development checkout

A **development checkout** has no workspace. The session changes
Hostwarden itself and reaches no server, not even the local machine.
Every git worktree counts as development, whatever its main checkout
is.

In Claude Code a hook announces the mode at session start and another
enforces it. In development the first also puts a shim in front of
`ssh`, `scp`, `sudo`, `ansible`, `terraform` and the rest on the
`PATH` of every command the agent runs, so they refuse however they
are started; `git push` still reaches the real `ssh`. Under WSL the
shim also covers the Windows programs that reach a server or
administer the machine: `ssh.exe`, `wsl.exe`, `powershell.exe` and
the rest. Other tools follow the same rule from `AGENTS.md`.

## The taboo guard in development

The taboo guard knows the mode as well. In development it judges a
command in full only when the command can reach past your own
files — it names `ssh`, `sudo`, a container, VM or cloud tool — or
when the session runs as root or in the `disk` group. Otherwise a
commit message, a pull request title or a search that names `mkfs`
or `fdisk` is text and goes through. SSH keys, `sshd_config`,
`diskutil` and the Windows taboos stay guarded in every mode, and so
does power off on a machine running systemd, which lets you power
off without root.

## Asking an operations session

When development needs to know something about a live server, the
agent hands the question to a session in your operations checkout —
a message to one already running, or one command that starts it —
and reads the answer. That session runs the access lists and the
full first-connection pipeline as always, a one-line question
included. Details: `rules/server-check-handoff.md`.

## Contributing

The contribution workflow — how to open a pull request, what review
expects — is in
[CONTRIBUTING.md](https://github.com/hostwarden/hostwarden/blob/main/CONTRIBUTING.md)
on GitHub. For trying a change before you open one, see
[Testing a change](testing.md).
