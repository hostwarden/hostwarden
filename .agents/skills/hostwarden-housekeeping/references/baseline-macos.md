# Baseline Checks — macOS

Run these on macOS machines.

## Backup Presence

Run the generic "any backup at all?" check — see
`references/backup-presence.md`. On macOS the primary path is
Time Machine via `tmutil`.

## Disk Usage

```bash
df -h /System/Volumes/Data 2>/dev/null || df -h /
```

The Data volume holds everything that grows; `/` is the sealed
system volume beside it in the same APFS container. Before
macOS 10.15 there is no Data volume, and `/` is the disk.

- **WARN** if > 85% used
- **CRITICAL** if > 95% used

## Memory

```bash
vm_stat
sysctl -n hw.memsize
```

Parse `vm_stat` output to calculate used/free pages. Multiply by
page size (usually 16384 on Apple Silicon, 4096 on Intel — get
from `vm_stat` header).

- **WARN** if available memory < 10% of total

## System Load and Uptime

```bash
uptime
sysctl -n hw.ncpu
```

- **WARN** if 15-minute load average > core count

## Pending Software Updates and Restart

```bash
softwareupdate -l 2>&1
```

It asks Apple's servers and can take a minute, so run it last.
A cached list (`--no-scan`) can be days old and miss what came
out since.

- **WARN** if updates are available
- **WARN** for each entry marked `Action: restart`

## Critical Auto-Updates

Check that critical security updates install automatically — see
`rules/os/macos.md` for the specific check.

- **WARN** if critical auto-updates are disabled

## Homebrew Packages

Set `$BREW` as `rules/os/macos.md` → Package Manager locates it,
then:

```bash
[ -n "$BREW" ] && { "$BREW" outdated; "$BREW" services list; }
```

- **WARN** if any outdated packages are found — report the count
  and list them
- **WARN** for each service whose status is `error`
- **WARN** for each process still running from a Homebrew
  version that has since been removed
  (`rules/os/macos.md` → Service Manager). After an upgrade the
  formula is no longer outdated, but the process keeps its old
  path:

```bash
ps -axo pid=,comm= | grep /Cellar/ | while read -r pid path; do
  [ -e "$path" ] || echo "stale: $pid $path"
done
```

## Application Firewall

```bash
/usr/libexec/ApplicationFirewall/socketfilterfw \
  --getglobalstate
```

- **WARN** if the firewall is off on a server; on a
  workstation, `rules/role/workstation.md` rates it

## SMART Disk Status

```bash
diskutil info disk0 | grep "SMART Status"
```

- **CRITICAL** if SMART status is not "Verified"

## Time Sync

```bash
sntp -t 1 time.apple.com 2>&1
```

- **WARN** if time offset > 5 seconds

## Failed launchd Jobs

Column 2 of `launchctl list` is a job's last exit status. Skip
jobs with a PID in column 1, which launchd has restarted and are
running, and `com.apple.` jobs, which exit non-zero routinely:

```bash
F='NR == 1 || $1 ~ /^[0-9]/ || $2 == 0 || $3 ~ /^com\.apple\./ {next} {print}'
echo "--system"
if L=$(sudo -n launchctl list 2>/dev/null); then
  printf '%s\n' "$L" | awk "$F"
else
  echo "unknown(needs-root)"
fi
echo "--user"
launchctl list | awk "$F"
```

- **WARN** for each job with a non-zero status, by label

## Kernel Panics

```bash
D=/Library/Logs/DiagnosticReports
if P=$(sudo -n find "$D" -name '*panic*' -mtime -7 2>/dev/null) ||
   P=$(find "$D" -name '*panic*' -mtime -7 2>/dev/null); then
  printf '%s\n' "$P"
else
  echo "unknown(unreadable)"
fi
```

- **WARN** for each panic report from the last seven days, with
  its date
- `unknown(unreadable)`: neither root nor this user could read
  the reports. List the check under "Skipped".

## Time Machine Local Snapshots

```bash
tmutil listlocalsnapshots / 2>&1
```

Local snapshots are space macOS frees on demand, not a backup
(`references/backup-presence.md`).

- **INFO** with the count
