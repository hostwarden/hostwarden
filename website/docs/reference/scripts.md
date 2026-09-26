---
sidebar_position: 4
title: Scripts in bin/
description: The scripts Hostwarden ships, which ones you run yourself
  and which run for you.
---

# Scripts in bin/

Hostwarden is mostly instructions, but a few jobs are plain scripts in
`bin/`. Each prints its usage with `--help`.

## You run these

- **`hostwarden-init`** — turns the checkout into an operations
  install: `memory/` becomes the workspace. `--clone <url>` joins a
  shared workspace instead
  ([A shared workspace](../running-it/team/shared-workspace.md)).
- **`hostwarden-doctor`** — lists the tools Hostwarden runs on your
  workstation, what is missing, and the command to install it.
- **`hostwarden-update`** — updates Hostwarden, or checks, pins or
  picks a release line
  ([Updates and versioning](../running-it/setup/updates.md)).
- **`hostwarden-backup`** — backs up or restores `memory/` as one
  archive ([Backup and restore](../running-it/setup/backup.md)).
- **`hostwarden-mirror`** — fast-forwards your own mirror of
  Hostwarden to upstream and carries every tag; meant for a CI job
  ([Your own mirror](../running-it/setup/mirror.md)).
- **`hostwarden-heinzel-takeover`** — copies your state out of a
  Heinzel checkout ([Moving over from Heinzel](../running-it/heinzel.md)).
- **`hostwarden-map`** — draws the Mermaid maps under `memory/maps/`
  ([Infrastructure maps](../memory/maps.md)).

## These run for you

- **`hostwarden-migrate`** — brings local state up to date after an
  update, such as renamed overrides; the session start and
  `hostwarden-update` run it, and it is safe to run by hand.
- **`hostwarden-ssh-config`** — writes `memory/ssh_config`, the file
  every SSH call passes; the session start runs it.
- **`hostwarden-sync`** — pulls the workspace at session start and
  commits what a session wrote; its `commit` also redraws the maps.
- **`hostwarden-impact`** — works out what a disruptive step on a host
  reaches beyond it, from memory alone, and announces it to other
  sessions ([What a reboot would hit](../features/fleet/impact.md)).
- **`hostwarden-fleet-run`** — the nightly, unattended housekeeping of
  an operations host, on a timer you set up
  ([An operations host](../running-it/team/operations-host.md)).
- **`hostwarden-wrap`** — wraps Markdown at 80 columns, as every file
  in Hostwarden and in the workspace is written.

## For working on Hostwarden

Tools that only developing Hostwarden needs live in `scripts/`, not
here, and a checkout that runs Hostwarden never calls them:

- **`scripts/lab.sh`** — disposable Linux containers and VMs to try a
  command on instead of guessing its syntax
  ([Testing a change](../development/testing.md)).
