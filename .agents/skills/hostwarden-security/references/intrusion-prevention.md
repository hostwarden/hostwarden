# Intrusion Prevention — Linux, FreeBSD and macOS

## fail2ban Status

Ask the loaded OS file's Service Manager → Service status for
`fail2ban`.

- Not running / not installed → **INFO** (recommended but not
  critical, especially when SSH uses key-only authentication)
- Active → OK

If active, optionally show jail status:

```bash
fail2ban-client status 2>/dev/null
```

## FreeBSD

The base system ships `blocklistd` (`blacklistd` up to 14.x),
which blocks addresses sshd reports for failed logins; `sshguard`
and `fail2ban` come from packages, and any of them counts as
fail2ban above, at the same severities.

```bash
for svc in blocklistd blacklistd sshguard fail2ban; do
  service "$svc" onestatus 2>/dev/null
done
```

`onestatus` answers whether the daemon runs, enabled or not; a
service that is not installed prints nothing. sshd reports to
blocklistd only with `useblocklist yes` in the `sshd -T` output
of `references/ssh.md` (`useblacklist` on older releases), which
is off by default.

- blocklistd runs but sshd does not report to it → **INFO**
  "blocklistd gets no reports from sshd"

## macOS

macOS ships no fail2ban equivalent: report the check as not
applicable in one line, never as a missing tool.
