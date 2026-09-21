# Moving over from Heinzel

Hostwarden is a new clone, not an update of your
Heinzel checkout. Your state moves with the backup
script, which both projects share:

```bash
cd /path/to/heinzel && bin/heinzel-backup
cd /path/to/hostwarden && \
  bin/hostwarden-backup --restore /path/to/heinzel-backup-<host>-<ts>.tar.gz
bin/hostwarden-migrate
```

The migration renames skill overrides in
`memory/custom-rules/` from `heinzel-<skill>.md` to
`hostwarden-<skill>.md`. What else changed:

- Environment variables are now `HOSTWARDEN_*`.
  `HEINZEL_NO_UPDATE` still works; the guard only
  honours `HOSTWARDEN_GUARD_DISABLE`.
- New journal entries on your servers use the tag
  `hostwarden`. The activity check reads `heinzel`
  entries as well, so earlier work stays visible.
- Point Hostwarden at your old checkout — "my
  Heinzel is in ~/heinzel, take it over", or
  `/hostwarden-adopt ~/heinzel` in Claude Code. The copy
  itself is a script — `bin/hostwarden-adopt <path>`
  moves access lists, custom rules and every server's
  memory across and renames what is found by name.
  The skill then reads your memory files and
  changelogs into a per-host list of leads: the
  scripts, configs, units and cron jobs your sessions
  improvised. Neither contacts a server.
- Keeping Heinzel around during the switch?
  `contrib/heinzel-coexistence/` holds three custom
  rules for your Heinzel checkout so it reads both
  journal tags, treats its server memory as a lead
  rather than a fact, and leaves Hostwarden's files
  alone. Hostwarden warns in the other direction when
  a Heinzel journal entry is minutes old, and leaves
  a host alone that Heinzel still uses.
- On the first connection to a host, Hostwarden
  reports what Heinzel left there — config backups,
  scratch directories — and offers to move it under
  the new name. It asks first, and it says which old
  backups the retention cleanup would then delete.
  New config backups go to
  `/var/backups/hostwarden/`.
- SSH sockets live in `~/.cache/hostwarden`.
- Scheduled runs (cron, systemd timers) need the new
  path and script names.
- Heinzel's version tags are not carried over.
  `--pin` only knows Hostwarden releases.
