# Custom Rules — Backups

Override for `rules/backups.md` while Hostwarden
works on the same hosts.

## Add: The other tool's backup directory

Hostwarden writes config backups to
`/var/backups/hostwarden/`, and
`~/.hostwarden-backups/` in unprivileged mode. When
looking for an earlier version of a config file, look
there too — the backup you want may have been made by
the other tool.

Keep writing your own backups to
`/var/backups/heinzel/`. Two tools writing into one
directory make the retention window ambiguous, and
neither gains anything.

## Add: An empty backup directory is not data loss

Hostwarden offers, once per host, to adopt what
Heinzel left behind. If the user accepted,
`/var/backups/heinzel/` was moved into
`/var/backups/hostwarden/` and the old directory
removed.

So a missing `/var/backups/heinzel/` has a harmless
explanation. Check the new path before reporting
anything as lost, and report it as adopted, with the
file count you found. A false "your backups are gone"
costs the user an hour of fear
(`rules/verify-before-reporting.md`).

Recreate the directory as usual on the next backup —
`mkdir -p` already does that.
