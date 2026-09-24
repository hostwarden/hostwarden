---
id: 20260924-windows-server-only
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [platforms, windows]
---

# Windows Server as the only target, WSL as the workstation

## Context

Decided on 2026-09-22, when Windows support was designed. Windows came
up in two roles at once: as a machine to manage over SSH, and as the
machine an operator runs Hostwarden from. Hostwarden's own side is
POSIX: `sh` hooks, the taboo guard, SSH connection sharing. Git for
Windows had been a way to run it natively.

## Decision drivers

- Windows is managed as a server estate; a Windows desktop is not
  one.
- The hooks and the taboo guard read `sh`, and connection sharing
  needs a POSIX `ssh`.
- The guard cannot read what a native Windows shell runs.

## Considered options

### Windows Server as a target, WSL as the workstation — chosen

Windows Server is a managed target, reached over SSH with
PowerShell 7 as the baseline. A Windows machine runs Hostwarden
only inside WSL. Against it: someone on a Windows desktop has to
set up WSL before they start, and a Windows client on the network
is not managed at all.

### Windows clients as targets too

Manage Windows desktops as well. Lost: it would take the
workstation role, which covers macOS, WSL and the local machine,
into a family whose clients Hostwarden has no reason to manage.

### Git for Windows as a workstation

Run Hostwarden natively in Git Bash. Dropped: outside WSL a session
can reach PowerShell, whose commands the guard cannot read, and the
hooks lose connection sharing.

## Decision

Windows Server is a managed target; a Windows client is refused as
one. On Windows, Hostwarden runs inside WSL, and there is no native
path.

## Consequences

`rules/os/windows.md` and `rules/os-detection.md` → Windows carry
the target and the refusal of a client. A Windows user sets up WSL
first, as `docs/install.md` says. Guard coverage for Windows
commands is written for sessions that reach Windows over SSH or
through WSL, not for a native Windows shell.

## Confirmation

Nothing would tell us. A request to manage Windows clients, or to
run Hostwarden outside WSL, is the moment to reread this record.
