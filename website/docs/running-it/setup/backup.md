---
sidebar_position: 4
description: Backing up and restoring the workspace, and what changes
  with a shared workspace.
---

# Backup and restore

Everything the workspace holds is in `memory/`, so a backup is one
`tar` command. The tree is text and typically well under a megabyte.
No database, no hidden dotfiles, no scattered config. Claude Code's
own personal files (`.claude/settings.local.json`, `CLAUDE.local.md`)
are not Hostwarden state and not in the backup.

For what `memory/` holds, see
[The workspace](../../memory/workspace.md).

## Back up

```bash
bin/hostwarden-backup
```

Writes `hostwarden-backup-<hostname>-<timestamp>.tar.gz` to the
current directory. Use `--list` for a dry run, `-o <path>` to write
somewhere specific.

## Restore

```bash
bin/hostwarden-backup --restore <file.tar.gz>
```

Refuses to overwrite existing `memory/` content unless `--force` is
passed. The archive is validated before any files are written: all
entries must live under `memory/`, and symlink or hardlink entries
are rejected.

## A shared workspace

With a shared workspace, most of `memory/` lives on its remote
already. The personal files that `memory/.gitignore` keeps off it
still need this backup. The archive leaves out `memory/.git` and
`memory/ssh_config`; a restore sets the workspace up first and writes
`ssh_config` for the new checkout.
