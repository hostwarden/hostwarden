# File Permissions — Linux, FreeBSD and macOS

## World-Writable System Files

```bash
find /etc /usr /bin /sbin -xdev -type f \
  -perm -0002 2>/dev/null
```

No root needed (finds files based on permissions of
world-readable directories).

- Any file found → **WARN** per file
- None found → OK

## SUID/SGID Binary Audit

```bash
find / -xdev -type f \
  \( -perm -4000 -o -perm -2000 \) 2>/dev/null
```

No root needed. Report the total count.

**Known-good SUID/SGID binaries** (do not flag): `sudo`, `su`,
`passwd`, `chsh`, `chfn`, `newgrp`, `gpasswd`, `mount`,
`umount`, `ping`, `ping6`, `fusermount`, `fusermount3`,
`pkexec`, `unix_chkpwd`, `crontab`, `ssh-agent`, `at`, `expiry`,
`wall`, `write`, `dotlockfile`, `mount.nfs`, `mount.cifs`,
`staprun`, and on Alpine `doas` and `bbsuid` (from
`busybox-suid`).

Any binary not in this list → **INFO** with full path. The user
can assess whether it belongs.

## /tmp and /dev/shm Mount Options — Linux only

```bash
mount | grep -E '(/tmp |/dev/shm )'
```

Or use `findmnt`:

```bash
findmnt -n -o OPTIONS /tmp 2>/dev/null
findmnt -n -o OPTIONS /dev/shm 2>/dev/null
```

- `/dev/shm` lacks `noexec` → **WARN**
- `/tmp` lacks `noexec` → **INFO**
- `/tmp` is not a separate mount → **INFO** (note that it shares
  the root filesystem)

## Cron Directory Permissions

```bash
stat -c '%a %U %G %n' \
  /etc/crontab \
  /etc/cron.d \
  /etc/cron.daily \
  /etc/cron.hourly \
  /etc/cron.weekly \
  /etc/cron.monthly 2>/dev/null
```

On Alpine, the paths are busybox `crond`'s crontabs and the
periodic directories it runs (`rules/os/alpine.md` → Directory
Conventions), with the same criteria:

```bash
stat -c '%a %U %G %n' /etc/crontabs /etc/crontabs/* \
  /etc/periodic /etc/periodic/* 2>/dev/null
```

- Any of these world-writable (xx7 or xx6 with group=other) →
  **CRITICAL**
- World-readable but not writable → **INFO**
- Owner root, no world access → OK

## Unowned Files

```bash
find /etc /usr /var -xdev \
  \( -nouser -o -nogroup \) 2>/dev/null
```

Limit to these key directories to avoid excessive scan time on
large filesystems.

**Alpine:** busybox `find` has no `-nouser` or `-nogroup`; with
`2>/dev/null` the command above prints nothing and reads as
clean. Compare owners with the local account files instead:

```bash
find /etc /usr /var -xdev -exec stat -c '%u %g %n' {} + \
  2>/dev/null \
  | awk 'FILENAME=="/etc/passwd"{split($0,f,":");u[f[3]];next}
         FILENAME=="/etc/group"{split($0,f,":");g[f[3]];next}
         !($1 in u) || !($2 in g)' /etc/passwd /etc/group -
```

Accounts from a directory service (LDAP, SSSD) are not in
`/etc/passwd`; where server memory records one, check a hit with
`getent passwd <uid>` before reporting it.

**OpenWrt:** skipped. Its busybox has neither the flags nor `stat`
(`rules/busybox.md`); list the check under "Skipped".

- Any unowned file found → **INFO** per file
- None found → OK

## FreeBSD

The checks above apply with the severities they state; only paths
and flags differ. BSD `find` takes `-xdev`, `-perm` and
`-nouser`/`-nogroup` as written, and `stat` needs `-f`.

- **World-writable:** add `/lib /libexec /boot /usr/local` to the
  `find` paths. On ZFS every dataset is its own filesystem, so
  `-xdev` does not reach `/usr/local` through `/usr`.
- **Cron:** `stat -f '%Sp %Su:%Sg %N' /etc/crontab /etc/cron.d
  /usr/local/etc/cron.d /var/cron/tabs 2>/dev/null`
  (`rules/os/freebsd.md` → Directory Conventions);
  `/var/cron/tabs` is `drwx------` by default.
- **Unowned files:** `/etc /usr /usr/local /var`, plus every
  mount point below them that `mount -t ufs,zfs` lists (on ZFS
  `/var/log`, `/var/mail`, `/var/tmp` are datasets of their own,
  and `-xdev` stops at each).
- **/tmp:** `mount | grep -E ' on /(tmp|var/tmp) '`. There is no
  `/dev/shm`, and the installer's ZFS layout mounts both with
  `nosuid` and exec on, so only a missing `nosuid` is **INFO**.

### SUID/SGID on FreeBSD

`-xdev` on `/` covers only the boot environment's dataset. The
daily `periodic` security run already lists every setuid file on
local filesystems that permit it; as root, read that list when it
is from today:

```bash
ls -l /var/log/setuid.today && cat /var/log/setuid.today
```

Otherwise search each such filesystem. Skip data pools and jail
roots unless `memory.md` says they hold binaries; say which were
skipped.

```bash
mount -t ufs,zfs | grep -vE 'no(suid|exec)' \
  | sed -e 's/^.* on //' -e 's/ (.*//' \
  | while read -r mp; do
      find "$mp" -xdev -type f -perm +6000 2>/dev/null
    done
```

**Known-good on FreeBSD** (do not flag): in the base system `su`,
`login`, `passwd`, `chpass`, `newgrp`, `lock`, `quota`, `crontab`,
`at`, `atq`, `atrm`, `batch`, `ping`, `ping6`, `traceroute`,
`traceroute6`, `wall`, `write`, `btsockstat`, `lpr`, `lpq`,
`lprm`, `lpc`, `ppp`, `authpf`, `mksnap_ffs`, `ksu`, `sendmail`,
and under `/usr/libexec` `ssh-keysign`, `ulog-helper`, `dma` and
`dma-mbox-create`; the power-off binaries in `/sbin`, setuid for
group `operator`. From packages: `sudo`, `doas`, `pkexec`,
`polkit-agent-helper-1`, `dbus-daemon-launch-helper`. Compare by
eye: a filter that spells the `/sbin` names trips the taboo guard.

The daily run is off when `daily_status_security_enable` or
`security_status_chksetuid_enable` reads `NO` in
`/etc/periodic.conf` or, read after it, `/etc/periodic.conf.local`
→ **INFO**; unset means the default, `YES`. The Update
Notification probe of the housekeeping baseline reads both files
the same way.

## macOS

The system volume is sealed and SIP protects it
(`references/macos-security.md`), but `/etc` (really
`/private/etc`), part of `/Library` and the Homebrew prefix live
on the writable data volume. The searches above run there instead
of their Linux paths; the /tmp, `/dev/shm` and cron checks do not
apply:

```bash
HB=$(brew --prefix 2>/dev/null || /opt/homebrew/bin/brew --prefix 2>/dev/null)
[ "$HB" = /usr/local ] && HB=
for d in /private/etc /Library/Preferences /Library/PrivilegedHelperTools \
         /Library/StartupItems /Applications /usr/local ${HB:+"$HB"}; do
  [ -d "$d" ] || continue
  find "$d" -xdev -type f \
    \( -perm -0002 -o -nouser -o -nogroup -o -perm +6000 \) -ls \
    2>/dev/null
done
```

`brew --prefix` names the Homebrew prefix wherever it was
installed; the second try covers an SSH session whose `PATH` lacks
it. Run it as the SSH user, never under `sudo`
(`rules/os/macos.md` → Package Manager). `/usr/local` is searched
either way.

Rate each hit as its section above does.

**launchd jobs.** A job in `/Library/LaunchDaemons` runs as root;
a plist anyone but root can change is a way to root. No root
needed to read:

```bash
ls -lde /Library/LaunchDaemons /Library/LaunchAgents
ls -le /Library/LaunchDaemons /Library/LaunchAgents
```

`-e` prints the access control list under a file; an ACL can
grant write where the mode shows none.

- A plist or one of the two directories not owned by root,
  writable by group or others, or with an ACL entry that allows
  write to anyone but root → **WARN** per file, with its owner,
  mode and ACL.

The files a root job runs matter as much as its plist, wherever
they live, and so does every directory above them: whoever can
write one can swap the file. That is the `Program`, and every
absolute path among the `ProgramArguments`, which includes the
script an interpreter such as `/bin/sh` is handed. Resolve each
through symlinks first, so the directories checked are the real
ones:

```bash
PB=/usr/libexec/PlistBuddy
for p in /Library/LaunchDaemons/*.plist; do
  echo "--$p"
  { $PB -c 'Print :Program' "$p"
    $PB -c 'Print :ProgramArguments' "$p"; } 2>/dev/null \
    | sed -n 's|^ *\(/.*\)$|\1|p' | sort -u \
    | while IFS= read -r x; do
        if [ ! -e "$x" ]; then
          ls -dL "$x" 2>&1 | grep -q 'No such file' || echo "skipped: $x"
          continue
        fi
        d=$(cd -P "$(dirname "$x")" 2>/dev/null && pwd -P) \
          || { echo "skipped: $x"; continue; }
        ls -leL "$d/$(basename "$x")"
        while [ "$d" != / ]; do ls -lde "$d"; d=$(dirname "$d"); done
      done
done
```

- A file it runs or a directory above it that is not owned by root,
  writable by group or others, or with an ACL entry that allows
  write to anyone but root → **WARN**, with the plist that starts
  it.
- A `skipped:` line is a path this user cannot reach — below a
  directory it may not enter, or one privacy protection (TCC)
  guards. List it under "Skipped" with its plist: unchecked is
  not clean. A path that does not exist is an argument, not a
  file, and prints nothing.
