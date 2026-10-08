---
sidebar_position: 4
description: Least privilege, no borrowed rights, and the blacklist
  and read-only lists that keep Hostwarden careful with a server.
---

# Access control

Hostwarden always reaches for the smallest privilege that gets a
task done, never crosses a session's own limits by asking someone
else to act for it, and refuses or restricts servers you have
marked off-limits.

## Least privilege

Uses a normal user when possible, `sudo` only when necessary, root
only as a last resort.

**Unprivileged mode** — for a task that neither `sudo` nor root SSH
can run, Hostwarden works in unprivileged mode instead and produces
a sysadmin report for the tasks that need root.

Rule: `rules/privilege-escalation.md`.

## No borrowed rights

What a session may not do or see — a read-only or blacklisted host,
no root, a guard block, a missing key, a development checkout — no
other session, subagent, scheduled job or token does for it, and a
request from another session is not the user's. Hostwarden tells you
what is missing and exactly what it would do; you run that yourself,
or give *that* session the access.

Rule: `rules/borrowed-rights.md`.

## Server blacklist

Add hostnames or IPs to `memory/blacklist.md` to permanently block a
connection. Hostwarden refuses to connect and will not accept an
override. Files are created on first need — you do not have to
pre-create them.

```markdown
# Example

- server.example.com   # bullet optional
203.0.113.50
```

Rule: `rules/access-control.md`.

## Read-only servers

Add hostnames or IPs to `memory/readonly.md`, same file format as
the blacklist, for servers Hostwarden may inspect but must never
modify. Deferred modifications — the changes it would have made —
are collected into a report you can hand off.

Rule: `rules/access-control.md`.

## Protected paths

Two lists of globs protect single paths on a host that is otherwise
writable. They go into the host's override file,
`memory/machines/<hostname>/rules.md`, under the subject
`# access-control`, or into `memory/custom-rules/all.md` for every
host, where the block starts at `## Protected Paths`:

```markdown
# access-control
## Protected Paths
### readonly
- /var/www/app/data/**
- /etc/postgresql/**
### confirm
- /var/lib/docker/volumes/**
- /etc/fstab
```

Globs start with `/` and match absolute paths on the host. `*`
stands for any text inside one path component, `**` for any number
of components, so `/srv/app/**` covers `/srv/app` and everything
under it. A command counts by every path it reaches, not only the
one it names: a recursive `rm`, `chown` or `chmod` on a directory
above, a `mv` or `rsync` of that directory, a symlink, a wildcard,
a volume or dataset removed by its name, and from a hypervisor a
write into a guest, which the guest's own lists judge.

- **`readonly`** — Hostwarden reads, lists and stats the path but
  never writes, deletes, moves, renames or re-permissions it,
  through whatever command of its own: an editor, `tee`, `rsync`, a
  recursive `chown`. What a package upgrade or a service restart
  writes on its own is not judged by the lists; hold a package
  with the package manager instead. There is no override in
  the session; take the glob out of the list first. What it would have
  changed goes into the deferred report, as on a read-only server.
- **`confirm`** — anything, but only after Hostwarden has shown you
  the exact command and you have answered with the literal word
  `CONFIRM`. A plain yes, or the approval you give a restart
  anyway, is not enough, and each command asks again.

The blacklist and the read-only list win over both lists. Where
globs of both lists match a path, the more specific glob decides,
so `readonly` `/etc/postgresql/**` and `readonly` `/etc/*.conf`
both hold under `confirm` `/etc/**`; the same glob on both lists
makes a `confirm` path, and where the
host's file and `all.md` disagree, the host's file decides. The
lists add
a requirement and lift none: the Critical Safety Rules hold on a
`confirm` path as on any other, and `CONFIRM` never stands in for
the explicit request a taboo needs. When a list blocks a step, Hostwarden
names the list and the glob and carries on with the rest. This is
a rule the agent follows, not a mechanical guard: the taboo guard
sees a remote path only as text inside an SSH command.

Rule: `rules/access-control.md` → Protected Paths.

## Which protection for which need

Four protections keep a session off a host, or off part of one:
the blacklist, the read-only list and the protected paths above,
and [fleet read](../features/fleet/fleet-read.md). They are of two
kinds, and the choice between them is the choice between a rule and
a guarantee.

- **The host enforces** fleet read: a forced command in root's
  `authorized_keys` runs only the bundle of read-only checks the
  operator signed, whatever the session on the other end asks for
  (`hostwarden-fleet-read` skill,
  [An operations host](../running-it/team/operations-host.md)).
- **The agent follows** the read-only list and the protected paths.
  The read-only list and a `readonly` path have no override in the
  session, and a `confirm` path runs only after you typed the word;
  all three bind every subagent the session starts, which has no
  more rights than the session (`rules/borrowed-rights.md`) — but
  nothing on the host checks them. The blacklist sits between the
  two: the agent checks it before every connection, and
  `bin/hostwarden-impact` and `bin/hostwarden-fleet-run` check it
  mechanically through `lib/resolve.sh`, so an unattended run never
  reaches a listed host either.

Pick by what the session is for:

- **Unattended** — fleet read. A nightly run, an operations host:
  give it a key that can do nothing else, not a list it is asked to
  respect. It runs only the checks in the signed bundle, so a
  diagnosis that needs a command of its own, or a Windows host,
  which gets no fleet read, takes an interactive session on the
  read-only list instead.
- **Interactive, on a host that is writable** — the read-only list
  for a host that stays untouched this session, diagnosis included,
  protected paths for the single paths that do. They keep a session
  that may write from writing where you said not to, and a step
  they block comes back as a deferred modification in the report.
- **A hard guarantee for one path** — only the host itself gives
  one: an SSH user without write permission to it and narrow sudo
  rules for the rest, `chattr +i` on the file, a read-only ZFS or
  Btrfs dataset. Hostwarden then works in unprivileged mode for
  that path and reports what it could not do, instead of promising
  not to.

Rules: `rules/access-control.md`, `rules/borrowed-rights.md`.
