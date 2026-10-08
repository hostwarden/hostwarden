---
sidebar_position: 9
description: Makes the host itself keep a readonly path, with an
  immutable flag, a read-only dataset or a login of its own.
---

# Enforcing read-only paths

```
 ❯ Enforce the readonly paths on web1
 ❯ Make /etc/postgresql really read-only for Hostwarden on db1
 ❯ Is the readonly list on db1 enforced?
```

A `readonly` glob in a host's protected paths
([Access control](../../safety/access.md#protected-paths)) is a
rule Hostwarden follows. Nothing on the host knows about it.
`hostwarden-enforce-readonly` makes the host keep it, so that a
write there fails with an error from the kernel, whoever makes it:
a mistyped command, a package's post-install script, a restart
that rewrites a file. It runs only when you ask for it. Writing a
glob into the list changes nothing on the host.

## Three mechanisms

Hostwarden reads what is in place, tells you what each mechanism
breaks, and asks you to pick one per glob.

- **An immutable flag on the files** — `chattr +i` on Linux,
  `chflags schg` on FreeBSD and macOS. Nothing can write, delete
  or rename the file, root included, until the flag is cleared.
  For configuration, certificates, scripts and archives that
  nothing writes between changes. A package upgrade that ships
  the file fails on it until the flag is gone; Hostwarden names
  each packaged file before you decide.
- **A read-only ZFS dataset or Btrfs subvolume** — where the glob
  is exactly one, such as `/srv/archive/**` on `tank/archive`. The
  whole tree is read-only for everyone. Linux and FreeBSD; macOS
  has no equal.
- **A login of Hostwarden's own** — an account `hostwarden` that
  has no write bit on the protected paths, reads them through a
  group or an ACL, and gets sudo for the commands you name, none
  of which may write there. The only mechanism for data something
  keeps writing: a database cluster, an application's data
  directory. Hostwarden then works on that host without root for
  everything sudo does not name, and reports what it could not do.
  Creating the account is asked for; installing your public key
  in its `authorized_keys` is your step, since Hostwarden never
  writes one.

Where none fits, Hostwarden says so: a tree on macOS, a path inside
an unprivileged container, a path on NFS or tmpfs.

## What it never does

- Apply a mechanism because a glob was written. Enforcement is a
  request, and each command is asked for as a storage or account
  change.
- Touch sshd's configuration, a host key, `authorized_keys` or the
  revocation list, even when a glob covers them: you set a flag
  there at a console.
- Clear a flag or a property while the glob is still on the list:
  that is a write on a protected path. Take the glob out of the
  list first, then ask Hostwarden to lift the enforcement.
- Try a write to see whether it is blocked. Verification asks the
  kernel with `test -w` and writes nothing.

## What it records

One `Enforced readonly:` line per glob in the host's memory, with
the mechanism, the flag it set and the date; the account gets one
line per host naming the globs it covers. Which login your
workstation uses stays in your own `memory/user.md`, so in a
shared workspace each operator adds their key to the account and
switches for themselves. On such a host Hostwarden never falls
back to a root login; your own key still opens root to you until
you take it out. The sudo file gets a master copy in your
workspace like any file Hostwarden deploys. Asking how things stand compares
those lines with what the host shows and reports a flag someone cleared
in between.

Skill: `.agents/skills/hostwarden-enforce-readonly/SKILL.md`.
