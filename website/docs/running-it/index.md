---
sidebar_position: 1
description: How a checkout becomes the one that administers your servers,
  stays current, and is shared across a team.
---

# Running Hostwarden

Once a checkout is past its first session, these pages cover operating
it day to day: where it comes from, how it stays current, how a team
or several machines share what it learns, how to run it unattended,
and how to make it your own.

## Setup and updates

- [The operations checkout](setup/checkouts.md) — what makes a
  checkout the one that administers your servers, and where
  production comes from.
- [Your own mirror](setup/mirror.md) — keeping a private mirror of
  Hostwarden current.
- [Updates and versioning](setup/updates.md) — which updates a
  checkout takes, and how to choose or pin a release.
- [Backup and restore](setup/backup.md) — backing up and restoring
  the workspace.

## Teams and several machines

- [A shared workspace](team/shared-workspace.md) — sharing `memory/`
  across a team, or across your own machines, through a private git
  remote.
- [Parallel sessions](team/parallel-sessions.md) — sessions that see
  each other on the same host, steps that reach other hosts, and the
  coordinator.
- [An operations host](team/operations-host.md) — an always-on
  machine that runs the fleet's housekeeping unattended.

## Unattended runs

- [Scripting and auto mode](unattended/automation.md) — running
  Hostwarden from the command line, and fewer approval prompts for
  batch work.
- [Scheduled housekeeping](unattended/scheduled.md) — a recurring,
  unattended health check.

## Making it yours

- [Overrides](tailoring/overrides.md) — changing what Hostwarden
  does, and adding skills of your own.
- [What Hostwarden recommends](tailoring/recommendations.md) —
  recipes with reasons, and how to turn one off.

[Moving over from Heinzel](heinzel.md) walks through taking over an
existing Heinzel installation instead of starting fresh.
