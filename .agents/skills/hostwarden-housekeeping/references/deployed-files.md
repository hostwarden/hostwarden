# Deployed Files

Whether the files sessions wrote onto this host are still what was
deployed, and whether their masters have moved on since. Runs on a
host with `memory/servers/<hostname>/deployed.md`, and on a cluster
member for the cluster's own `deployed.md` too.

## Probe

Run the probe and sort the files as `rules/deployed-files.md` →
Drift says, with every path in `deployed.md`, in one of the batches
with the other checks. In unprivileged mode a root-only path comes
back `unread`: report it as not checked
(`references/unprivileged.md`).

## Report

One line under Issues per file that is not as deployed:

```
WARN      Deployed /usr/local/bin/backup-usb-watch edited on the host
WARN      Deployed /etc/cron.d/reboot-check removed on the host
WARN      Deployed /etc/app/app.conf mode 644, recorded 600
INFO      Master of /usr/local/bin/reboot-check changed, not deployed
INFO      Deployed /etc/app/app.conf not checked (unread)
INFO      Deployed /usr/local/bin/heinzel-backup.sh unverified since adoption
```

An `unverified` entry is reported as the last line shows, whatever
the probe returns: settling it is the Heinzel check's
(`rules/heinzel-adoption.md` → Heinzel's copies).

"Both changed" is a `WARN` like an edit on the host. Under System,
one line for all of them:

```
Deployed   7 files, 6 as deployed, 1 edited on the host
```

Housekeeping changes neither side; a finding is resolved when the
user asks for it, under that same section.
