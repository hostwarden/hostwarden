---
sidebar_position: 5
description: Keeps a master copy of every script and config file
  it writes to a server.
---

# Files Hostwarden deploys

A script, a systemd unit or timer, a cron file, a config drop-in
or a rendered template that Hostwarden writes onto a server has
its master copy in your workspace, at the same path it has on the
host:
`memory/machines/<hostname>/files/usr/local/bin/backup-usb-watch`.
One file deployed to several hosts lives in `memory/fleet/<name>/`,
or in `memory/clusters/<name>/files/` for a cluster's members.
`deployed.md` beside the host's memory records what was deployed,
with its hash, and a file in a format that has comments carries
one naming its master. sshd's configuration never gets a master.

## What housekeeping compares

Housekeeping compares the three and reports when a file was edited
on the host, removed there, changed its mode or owner, or changed
in the workspace without being deployed. Neither side is ever
overwritten on its own: you decide whether the host's edit goes
into the master or the master goes back onto the host. Files you
or a configuration management tool own stay where they are —
Hostwarden keeps no second copy of them. Scripts for your own
machine go in `memory/tools/`.
