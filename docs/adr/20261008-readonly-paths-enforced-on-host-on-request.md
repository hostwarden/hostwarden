---
id: 20261008-readonly-paths-enforced-on-host-on-request
status: proposed
supersedes:
superseded-by:
waiting-on: review of the pull request that adds the skill
tags: [access-control, guard, accounts, storage]
---

# Protected paths are enforced on the host, on request

## Context

Protected paths (#495) are two glob lists the session follows; its
body says the taboo guard sees a remote path only as text inside
the SSH command and enforces nothing. A `readonly` glob therefore
holds exactly as well as the session's judgement on each command,
a package's post-install script included. The question was how to
turn such a glob into something the host itself keeps, and whether
that should happen on its own once a glob is written.

## Decision drivers

- The guard reads the local command string; the host resolves the
  path.
- Every mechanism that holds against root also holds against the
  application that owns the path.
- A change on a production host is asked for, never a side effect
  of a memory edit.
- One answer per family, Linux, FreeBSD and macOS.

## Considered options

### Host-side mechanisms, applied by a skill the user asks for — chosen

Three mechanisms the host already has, picked per glob with the
user: an immutable flag on the files (`chattr +i`, `chflags schg`)
where nothing writes between changes, a read-only ZFS dataset or
Btrfs subvolume where the glob is one, and a login of Hostwarden's
own without the write bit and with sudo for named commands only
where the application keeps writing. Against it: root on the host
can lift each; the account costs Hostwarden its root on that host
for everything sudo does not name; the flag breaks the upgrade of
a packaged file until it is cleared.

### The taboo guard enforces the globs

Match each glob against the paths in the command string before it
runs. Lost: the guard cannot resolve a relative path, a symlink, a
wildcard, a bind mount, a package's file list or a service's
writes, which is exactly where the rule needs the host's answer;
and `20260924-guard-is-a-backstop-not-a-sandbox` records why the
guard does not grow a parser for each shape a path can take.

### Enforcement applied automatically when a glob is written

Set the flag or the property as soon as the list has the glob.
Lost: a list entry is a line in the user's memory files, which they
edit by hand, in a shared workspace from another machine too; a
flag that fails the next `apt-get` run on a production host is not
a thing a memory edit may do, and the mechanism that fits depends
on what writes the path, which only the user knows.

### A read-only bind mount over the tree

`mount --bind -o ro` on Linux. Lost: it has to be written into
`fstab` to survive a reboot, an `umount` by any root process takes
it off without a trace on the path itself, and FreeBSD and macOS
have no equal; the flag and the property are recorded on the
object and read back from it.

## Decision

Enforcement is the `hostwarden-enforce-readonly` skill, run only
when the user asks: one mechanism per glob, picked with the user
after its cost is named, applied under the ask-before rules, lifted
only after the glob left the list. The guard is not changed.

## Consequences

`rules/access-control.md` → Protected Paths names the enforcement
and lets a `readonly` glob be tightened, never loosened;
`.agents/skills/hostwarden-enforce-readonly/`
carries the mechanisms per family and their costs, and
`rules/machine-memory.md` the `Enforced readonly:` line. A proposal
to enforce the globs in the guard, or to apply a flag when a glob
is written, is answered with this record.

## Confirmation

The skill's own status read compares the memory line with what
the host shows. A proposal to apply a mechanism without a request,
or to parse paths in the guard, is the moment to reread this
record.
