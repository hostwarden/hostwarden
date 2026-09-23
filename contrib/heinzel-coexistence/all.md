# Custom Rules — Running Beside Hostwarden

Read once per session. Applies to every host in this
installation.

## Add: A second tool administers these hosts

[Hostwarden](https://github.com/jpawlowski/hostwarden)
grew out of Heinzel and is in use on the same
machines during a transition. It follows the same
safety rules, logs to the same journal under the tag
`hostwarden`, and keeps its own state:

- journal tag `hostwarden` beside `heinzel`
- `/var/backups/hostwarden/` for config backups
- `~/.cache/hostwarden/` for SSH control sockets
- `~/.hostwarden-backups/`, `hostwarden-scratch/`

Anything under those names belongs to the other tool.
Do not clean it up, move it, or report it as stray
litter. It is not an anomaly
(`rules/anomaly-detection.md`).

## Add: Server memory may be behind the host

The memory files here describe what *this*
installation last saw. Hostwarden works on the same
hosts and writes its own memory elsewhere, so a fact
in `memory/servers/<host>/memory.md` can be out of
date through no fault of anyone's.

Treat server memory as a lead, not as truth: before
reporting that something is missing, changed or
broken, confirm it against the live host
(`rules/verify-before-reporting.md`). During the
parallel phase this matters more than usual — a
service that memory does not mention, a package
version that jumped, a config file with a newer
timestamp is most likely the other tool's work, not
an intruder.

When the host and memory disagree, fix memory from
the host and say so in one line. Do not infer a cause
you have not shown.

## Add: Two agents on one host at the same time

The real risk of the parallel phase is not stale
memory; it is both tools editing or reloading the
same service within the same minute. The journal is
the only shared signal — `activity-check.md` in this
directory says how to read it and when to warn.

Two tools also mean twice the SSH connections. Rate
limits and fail2ban count them per source address
(`rules/ssh-connections.md`), so a lockout during the
parallel phase is more likely than usual — one more
reason not to retry a hanging call more than once.

## Add: What the other tool may have moved

Hostwarden offers, once per host, to adopt what
Heinzel left there, which moves
`/var/backups/heinzel/` into
`/var/backups/hostwarden/`. Nothing is deleted by
that — `backups.md` in this directory has the rule.

Where the user chose it, Hostwarden also renames the
scripts, units, cron files and config directories
Heinzel sessions created — `heinzel-backup.sh`
becomes `hostwarden-backup.sh`, `/etc/heinzel/`
becomes `/etc/hostwarden/` — and rewrites every
reference to them. A path in this checkout's memory
that is gone from a host may simply carry the new
name now: look for it before reporting it missing.
