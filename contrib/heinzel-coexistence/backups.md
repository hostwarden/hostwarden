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

## Add: A missing backup directory is not proof of loss

Hostwarden offers, once per host, to adopt what
Heinzel left behind. If the user accepted,
`/var/backups/heinzel/` was moved into
`/var/backups/hostwarden/` and the old directory
removed.

So a missing `/var/backups/heinzel/` may have a
harmless explanation. Hostwarden logs the move:

```
journalctl -t hostwarden --no-pager | grep 'Adopted heinzel state'
```

Without a journal, grep syslog's file for the same text.

A line naming `/var/backups/heinzel` means adopted,
unless your own journal entries (`journalctl -t
heinzel`) go on after it: then you may have made the
directory again since, and the old line says nothing
about it. Report an adoption with the file count of
the new path. Otherwise the adoption is not shown:
Hostwarden fills `/var/backups/hostwarden/` with its
own backups too. Report the directory as missing, with
what the new path holds, and let the user decide. A false
"your backups are gone" costs the user an hour of fear,
and a false "adopted" costs the backups
(`rules/verify-before-reporting.md`).

Recreate the directory as usual on the next backup —
`mkdir -p` already does that.
