# Backup and restore

Hostwarden keeps all your personal state under a
single directory — `memory/` — so backups are one
`tar` command. The tree is text and typically well
under a megabyte. No database, no hidden dotfiles,
no scattered config. Claude Code's own personal files
(`.claude/settings.local.json`, `CLAUDE.local.md`) are
not hostwarden state and not in the backup.

## What lives in `memory/`

- `user.md` — SSH usernames and language
  preference
- `blacklist.md`, `readonly.md` — access policies
- `service-policy.md` — per-service opt-out /
  opt-in for auto-reload and auto-restart
- `servers/<hostname>/` — per-server memory,
  changelog, todo, and per-server rule overrides
- `custom-rules/` — your global rule overrides
- `opencode.json` — your OpenCode config
- `network.md`, `housekeeping.md` — cross-server
  facts and custom checks

## Back up

```bash
bin/hostwarden-backup
```

Writes
`hostwarden-backup-<hostname>-<timestamp>.tar.gz` to
the current directory. Use `--list` for a dry run,
`-o <path>` to write somewhere specific.

## Restore

```bash
bin/hostwarden-backup --restore <file.tar.gz>
```

Refuses to overwrite existing `memory/` content
unless `--force` is passed. The archive is validated
before any files are written: all entries must live
under `memory/`, and symlink or hardlink entries are
rejected.

## Team mode note

In team mode, most of `memory/` lives on the team's
remote already. But `memory/user.md`,
`memory/blacklist.md`, `memory/readonly.md`, and
`memory/opencode.json` are always personal and still
need this backup. The archive leaves out
`memory/.git`; a restore sets the workspace up
first.
