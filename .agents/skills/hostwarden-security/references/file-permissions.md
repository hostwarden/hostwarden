# File Permissions — Linux

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
