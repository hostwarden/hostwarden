---
name: hostwarden-enforce-readonly
argument-hint: "[hostname] [glob]"
description: Turn a `readonly` glob of a host's protected paths into
  something the host itself keeps — an immutable flag on the files
  (`chattr +i`, `chflags schg`), a read-only ZFS dataset or Btrfs
  subvolume for a whole tree, or a dedicated Hostwarden login
  without the write bit on those paths and sudo for named commands
  only. Checks what is in place, applies one mechanism per glob
  after the user picked it, or lifts it again once the glob left
  the list. Only on request, never automatic. Use when the user
  asks to "enforce the readonly paths on web1", "make
  /etc/postgresql really read-only for Hostwarden", "set the
  immutable flag on the protected paths", "give Hostwarden its own
  account without write access to the data", "is the readonly list
  on db1 enforced?", "lift the immutable flag again", "erzwinge
  die readonly-Pfade auf web1", "mach /etc/postgresql für
  Hostwarden wirklich schreibgeschützt", "setz das Immutable-Flag
  auf die geschützten Pfade", "gib Hostwarden einen eigenen Account
  ohne Schreibrecht", "hebe den Schreibschutz wieder auf". Not for
  writing the lists themselves, which the user does in the host's
  `rules.md` (`rules/access-control.md` → Protected Paths).
---

# hostwarden-enforce-readonly

A backstop for the everyday mistake, not a sandbox: with a
mechanism in place, a write to the path fails with an error from
the kernel, whoever makes it — a mistyped command, a package's
post-install script, a restart that rewrites a file. Root on the
host can take each mechanism off again, and `AGENTS.md` →
Critical Safety Rules is what stops this session from doing so.

The pipeline in `rules/first-connection.md` runs first, as
everywhere. One host per invocation; several go through
`rules/multi-host.md`. Nothing here is applied because a glob was
written: each mechanism is picked with the user and each command
asked for as its own rule says (→ Applying).

1. **Overrides:** key `hostwarden-enforce-readonly`, per
   `rules/overrides.md`.
2. **Read** the host's `readonly` globs (→ The globs) and what the
   host already keeps for each (→ Reading what is in place). A
   request that asks only how things stand ends here, with one
   line per glob.
3. **Pick** one mechanism per glob with the user (→ Which
   mechanism fits), after naming its side effects (→ What each
   mechanism costs).
4. **Apply** it (→ Applying), one glob at a time.
5. **Record** it (→ Memory, journal, changelog).

Lifting one again is → Lifting it.

## The globs

The skill works on globs that are on a list. A path the user
names that is on no list goes onto the host's `readonly` list
first, with the user's yes, as a local edit of
`memory/machines/<hostname>/rules.md`: a later session would
clear a flag no list tells it to keep. A `confirm` glob gets no
enforcement; it is a question, not a prohibition.

Some globs get none, whatever the user asks:

- One that covers sshd's configuration, a host key, an
  `authorized_keys` file or sshd's revocation list
  (`AGENTS.md` → Critical Safety Rules): the user sets a flag
  there at a console.
- One under a tree a configuration management tool owns
  (`rules/config-management-changes.md`): the tool would fail on
  the flag at its next run, or clear it. Leave the enforcement to
  that tool.
- One on a Windows host: the whole host is read-only by its family
  file, and nothing is needed.

## Reading what is in place

One read-only call per host, every glob at once. For each path
the glob names or expands to, on Linux:

```bash
findmnt -T <path> -o TARGET,SOURCE,FSTYPE,OPTIONS
lsattr -d <path>
```

`SOURCE` names the dataset where `FSTYPE` is `zfs`. On FreeBSD
and macOS:

```bash
ls -lo <path>
mount | grep ' on <mount> '
sysctl kern.securelevel
```

`ls -lO` on macOS, and `-d` on a directory, so its own flag shows
rather than its entries'. Only where the host's `Storage:` line
names ZFS or btrfs (`rules/storage-inventory.md`), since a `zfs`
call on a host without pools loads the module; `zfs list` gives
the dataset behind a mount point where `findmnt` is not there:

```bash
zfs list -H -o name,mountpoint
zfs get -H -o name,value,source readonly <dataset>
btrfs subvolume show <path>
btrfs property get -ts <path> ro
```

A file that carries the flag before the skill ran is noted by
name: the lift later leaves it as it was.

For the account mechanism, only where memory names it — an
`Enforced readonly: account …` line, or `hostwarden` as the
host's entry in `memory/user.md`: `id hostwarden` and
`sudo -n -l -U hostwarden` through the filter of
`rules/privilege-escalation.md` → Sudo. The account enforces a
glob only for a workstation whose `memory/user.md` names it for
the host; where this one still logs in as another user, say so.

Compare with the `Enforced readonly:` lines in the host's memory
(→ Memory, journal, changelog). Report one line per glob: enforced
by what, or not enforced. A line that memory promises but the
host no longer shows — a cleared flag, a dataset back to
`readonly=off` — is a finding: someone changed it without the
record following.

## Which mechanism fits

The question for each glob is whether something on the host has
to keep writing there.

- **Something writes there between Hostwarden's visits** — an
  application's data directory, a database's cluster, a log
  directory, a spool: only the **account** fits. The flag and the
  property stop the application as surely as they stop
  Hostwarden.
- **Nothing writes there except a change someone decides on** — a
  service's configuration, a certificate, a script, an archive,
  a backup target between runs: the **flag**, per file; or the
  **property**, where the glob's root is exactly a ZFS dataset or
  a Btrfs subvolume and everything under it is meant to be
  read-only.
- The **account** can hold on top of either: it is the only
  mechanism that limits what Hostwarden can do without changing
  the path at all.

Where none fits, say so:

- a tree on macOS has no read-only property: the flag on each
  file, or the account;
- a path inside an unprivileged system container or a Docker
  container takes no flag, since the kernel refuses the call
  there; where the guest's storage is a dataset or subvolume of
  its own, the property is set on the hypervisor;
- a path on NFS, CIFS, tmpfs or vfat keeps no flag.

Name the mechanism and its cost (→ What each mechanism costs),
then ask with `AskUserQuestion`, one question per glob, the
options being the mechanisms that fit and "leave it a rule".

## What each mechanism costs

Say this before the question, in full; it is the one place a long
answer is right (`AGENTS.md` → Talking to Humans).

**The flag.** Nothing can write, delete, rename or link the file,
root included, until the flag is cleared. A package upgrade that
ships the file fails on it with an error, which unattended
upgrades then report every night until the flag is gone: read
which files a package owns, in the call that lists the glob's
files (`dpkg -S`, `rpm -qf`, `pkg which`), and name each. On a
directory the flag stops any entry from being created or
removed, and leaves the files inside writable unless each has
the flag too, which `-R` sets. Log rotation, a certificate
renewal, an application that saves its own configuration all
fail. On FreeBSD with `kern.securelevel` at 1 or higher the
system flag `schg` cannot be cleared until a reboot into a lower
level, which is what the flag is for and the thing to say;
`uchg` is the owner's flag, cleared by the owner at any level,
and is what to offer there instead. On macOS the flag is cleared
by root at any time, and a path SIP covers needs nothing.

**The property.** The whole dataset or subvolume is read-only for
everyone. A ZFS child dataset inherits it unless it has its own
value; a nested Btrfs subvolume does not, and gets the property
itself where the glob covers it. Snapshots and replication still
work; a service whose state lives there stops.

**The account.** Hostwarden logs in as a login of its own, which
has no write bit on the protected paths and sudo for the commands
the user names, none of which may write there. Everything else
that needs root is deferred and reported
(`rules/privilege-escalation.md` → Unprivileged Mode), and the
user gives back as much of it as they want, one named command at
a time. On such a host the root SSH fallback is never probed;
the user's own key still opens root to the user, and only they
can take it out of root's authorized keys. The paths themselves do not change,
so the application
keeps writing. Installing the account's key is the user's step,
since no session writes `authorized_keys`.

## Applying

Each command runs after its question, by the rule that owns it:
the flag and the account's read ACL are the one attribute change
a `readonly` glob allows (`rules/access-control.md` → Protected
Paths); the property is a storage change (`rules/storage.md`);
the account a privilege change (`rules/accounts.md`). On a host
with another live session, register first
(`rules/parallel-sessions.md`).

One call per glob, which applies, reads back and verifies in one
chain. Only a glob that ends in `/**` names a whole tree and
takes `-R` from its root; every other glob — `/etc/fstab`,
`/etc/nginx/conf.d/*.conf`, `/srv/app/**/*.conf`, `/**/*.sqlite`
— takes each file it expands to, never a directory, so a file the
glob does not name can still be created or changed beside it. The verification
is `test -w`, which asks
the kernel whether a write would be allowed and writes nothing; it must fail
on the glob's root and on one file under it, as root too, since
the kernel answers for the flag and the property. A verification
that writes a byte to see whether it can is a write on a
protected path, and is not done.

**The flag, Linux.** One file first, since a file system that
does not keep the flag answers `chattr` with "Operation not
supported" and the chain stops there:

```bash
chattr +i <file> && lsattr <file> \
  && chattr -R +i <dir> && lsattr -d <dir> \
  && ! test -w <dir> && ! test -w <file> && echo enforced
chattr +i <file> <file> … && lsattr <file> <file> … \
  && ! test -w <file> && echo enforced
```

**The flag, FreeBSD and macOS.** `schg` by default; `uchg` where
the user chose it:

```bash
chflags -R schg <dir> && ls -lod <dir> \
  && ! test -w <dir> && ! test -w <file> && echo enforced
chflags schg <file> <file> … && ls -lo <file> <file> … \
  && ! test -w <file> && echo enforced
```

`ls -lO` on macOS.

**The property.** The dataset's name from `findmnt` or
`zfs list`, the subvolume's path. The `source` column shows `local` on the
dataset itself and `inherited from …` on its children:

```bash
zfs set readonly=on <dataset> \
  && zfs get -r -o name,value,source readonly <dataset> \
  && ! test -w <mount> && echo enforced
btrfs property set -ts <path> ro true \
  && btrfs property get -ts <path> ro \
  && ! test -w <path> && echo enforced
```

A nested Btrfs subvolume the glob covers gets its own `set`. On
an appliance that manages its pools itself the property is set in
its web UI, never here (`rules/storage-inventory.md` → On an
Appliance).

**The account.** `references/account.md`.

## Memory, journal, changelog

One line per glob in `memory/machines/<hostname>/memory.md`,
owned by this skill (`rules/machine-memory.md` → Who writes which
line):

```markdown
- Enforced readonly: /etc/postgresql/** (immutable +i, 14 files,
  2026-10-08)
- Enforced readonly: /usr/local/etc/nginx/** (immutable uchg, 9 files,
  pre-set /usr/local/etc/nginx/mime.types, 2026-10-08)
- Enforced readonly: /srv/archive/** (zfs readonly=on tank/archive,
  2026-10-08)
- Enforced readonly: account hostwarden (/var/www/app/data/**,
  /etc/postgresql/**; sudo /etc/sudoers.d/hostwarden; 2026-10-08)
```

The flag line names the flag, `+i`, `schg` or `uchg`, and each
file that had it before, by path; where those are more than a
few, the paths go into `memory/machines/<hostname>/notes/`
as `enforced-readonly.md`, one per line under the glob, and the
line says `pre-set: notes/enforced-readonly.md`. The account is one line per
host, not per glob: it names the globs the account's read access covers,
and a second glob joins the line. It records no login: which
login a workstation uses is its own `memory/user.md`, personal in
a shared workspace (`rules/machine-memory.md` → Personal versus
shared), and each operator switches their own entry after their
own key is in the account.

One journal line per host, then the local changelog
(`rules/changelog.md`):

```bash
logger -t hostwarden "[<operator> as <unix-user>] /etc/postgresql is \
now immutable (chattr +i) and no longer writable for anyone until the \
flag is cleared — because the readonly list should hold on the host, \
not only in Hostwarden"
```

## Lifting it

A flag, a property or a read ACL comes off only once the glob is
on no `readonly` list any more (`rules/access-control.md` →
Protected Paths). Tell the user to take the glob out of the list
first, then run the skill again. Each step asks as its rule says:

```bash
chattr -R -i <path> && lsattr -d <path>
chflags -R noschg <path> && ls -lod <path>
chflags -R nouchg <path> && ls -lod <path>
zfs inherit readonly <dataset> \
  && zfs get -H -o value readonly <dataset>
btrfs property set -ts <path> ro false \
  && btrfs property get -ts <path> ro
```

The flag the memory line names comes off. `-R` only for a glob
that ends in `/**` whose line names no pre-set file, in the line
or in the note; otherwise the per-file form over the files the
glob expands to, less the pre-set ones, which keep it.
`zfs inherit` restores the parent's value; `zfs set readonly=off`
where the parent is read-only too. `noschg` fails at
`kern.securelevel` 1 or higher until the user reboots into a
lower level (→ What each mechanism costs).

The account is lifted for one glob by taking the glob off its
line; the account and this workstation's login stay while the
line names any glob. With the last glob gone, the per-machine
question of `rules/ssh-user.md` → When to ask, Case C, picks the
login to go back to, and a fresh-login test with it
(`rules/ssh-connections.md` → Fresh-login options) comes before
the entry changes. Removing the account itself, its home, its
ACLs and its sudo file is a second question
(`.agents/skills/hostwarden-deploy-user/references/removal.md`
is the pattern); an account the user keeps stays recorded in the
`Accounts:` line as a local account.

Then remove the `Enforced readonly:` line, log it, and update the
local changelog.
