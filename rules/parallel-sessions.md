# Parallel Sessions

How Hostwarden sessions that change the same host see each other —
two windows on one workstation, or teammates on different ones.
Every session that is about to write registers on the host itself,
so every other session that reaches the host sees it, wherever it
runs. A session that only reads — housekeeping, an audit, a
question — registers nothing and is never in anyone's way.

## The register

One directory on the managed host, and in it one empty directory
per writing session. The entry's name carries everything; nothing
is ever written into a file:

    /tmp/hostwarden/<token>+<beat>+<user>@<workstation>+<task>

- `<token>` — this session's, made once and kept in mind:

  ```
  od -An -N4 -tx1 /dev/urandom | tr -d ' \n'
  ```

- `<beat>` — `date +%s` at the last heartbeat. Before a change that
  may run longer than 30 minutes — a release upgrade, a large
  transfer, a build — set it to the time you expect the change to
  end instead, and allow for overrun.
- `<user>@<workstation>` — the local user and host this session
  runs on (`id -un`, `hostname -s` on the workstation), so another
  session can tell whether it runs beside it.
- `<task>` — what this session is doing right now, a few words,
  lower case, joined by hyphens. Every heartbeat writes it again.

An entry is **live** while `<beat>` is less than 30 minutes ago or
still ahead; otherwise it is **stale**.

`/tmp/hostwarden` is writable by everyone and has **no sticky
bit**, so any session may remove any stale entry, whichever user
made it. Only `mkdir`, `mv` and `rmdir` touch it, never a file
write, and the directory is checked before anything is written
into it, so a session running as root cannot be steered through a
planted symlink. Every command below runs on the host — over SSH,
or directly in local mode.

The same openness lets any local account on the host rename,
remove or forge an entry. That is the price of letting one user
clear another's stale entry, and it is accepted: the register is a
courtesy between Hostwarden sessions, not a lock against the
host's own users. Someone who can log in and forge entries can
change the host directly too.

## Register, and renew

Before the first change this session makes on a host, and before
any later change once your last beat is more than 10 minutes old
or your task has changed, one call registers or renews the entry
and shows who else is there. It runs on its own, before the
change's backup, so nothing is written to the host until the
answer is read:

```
D=/tmp/hostwarden
[ -e "$D" ] || (umask 0 && mkdir "$D")
ls -ld "$D"
if [ ! -L "$D" ] && cd "$D" 2>/dev/null \
   && [ "$(pwd -P)" = "$(cd /tmp && pwd -P)/hostwarden" ] \
   && [ "$(ls -ld . | cut -c1-10)" = drwxrwxrwx ]; then
  N="<token>+$(date +%s)+alice@ws1+nginx-upgrade"
  E=$(ls -d <token>+* 2>/dev/null)
  if [ -n "$E" ]; then mv "$E" "$N"; else mkdir "$N"; fi && echo registered
fi
date +%s; ls -1 "$D"
```

The call changes into the directory first and checks the one it is
in, then works by relative name: a directory swapped for a link
after the check cannot redirect the write. The one `mkdir` under
`umask 0` sets the final mode; a later `chmod`, or `mkdir -m`,
could set it through a path swapped in between.

**`registered` missing** — the register is not one every session
can use: `ls -ld` shows a link, a file, a sticky `t` in the tenth
place, or permissions narrower than `drwxrwxrwx`. The call wrote
nothing into it. Stop and tell the user, with the `ls -ld` line.
Never carry on changing the host without an entry, and never
remove or re-permission a directory you do not own.

**Then read the other entries.**

- **None live** — carry on.
- **Live ones** — another session is changing this host right now.
  Say who (`<user>@<workstation>`) and what (`<task>`), and let the
  user decide whether the two get in each other's way: go ahead
  side by side, wait, or leave it to the other session. Ask once
  per entry token, not at every renewal. Two sessions that register
  at the same moment both see each other and both ask; that is the
  intended outcome.
- **An impact entry** — a live entry whose task starts with
  `impact-` is a step a teammate announced on this host or on one it
  goes with: a reboot, a firewall or network change, a restart
  (`rules/coordination.md` → Teams). Nobody writes here under it.
  Name it in one line — who, the step and its origin from the task,
  and until when from the beat: *"bob@ws2 announced a reboot of
  pve1.example.com until 14:05."* Before a change, let the user
  decide as for a live entry; a session that only reads just says
  it. One that names your own `<user>@<workstation>` is on this
  workstation's own map already (`bin/hostwarden-impact status`).
- **Stale ones** — remove each with `rmdir "$D/<entry>"` and say
  so in one line: *"Stale session entry from 11:02 (bob@ws2 —
  nginx-upgrade) removed."* If `rmdir` fails, the entry was renewed
  in the meantime; read the list again.

An entry that was gone at renewal — the host rebooted, `/tmp` was
cleaned, or another session found it stale — is simply made again
by the same call; that is also how a session makes itself known
again after the host comes back.

## Hosts without a register

Where the loaded OS file says a host has no register, the
journal stands in for it (`rules/changelog.md`), and the session
token (The register above, made with the same command on the
workstation where the host has no `sh`) tells one session from
another, two windows of the same operator included. Right before
each change there, write
`[<operator> as <unix-user>] starting <token>: <task>` and then
read the journal as the activity check does
(`rules/activity-check.md`), in one call; once the change is done and logged,
write `[<operator> as <unix-user>] done <token>: <task>`. The
marker goes first for the reason the register is made before it
is listed: two sessions that both read before writing can each
miss the other. Every change gets its own pair. A `starting`
entry with another token from the last 30 minutes, and no `done`
entry with that token after it, is a live session — name it and
ask, as for a live entry above. A change that then does not go
ahead gets its `done` entry at once. A pair that is complete is
a finished change.

## Talk to the other session

Reading the register is every session's own job; nobody announces
themselves beyond their entry. Talking to another session is for
when coordination looks necessary — both about to touch the same
service, one about to restart what the other depends on — not a
courtesy owed every time. This section is about the host you are
both on; a session on another host that the step you are about to
take would also reach is found and coordinated with mechanically,
through `rules/coordination.md`, not by asking around here.

When a live entry names your own `<user>@<workstation>`, the other
session runs on this same machine. Where the harness can reach
sessions there, offer the user to tell it what you are about to
do: host, change, and the file it touches, in a few lines.
Sessions on other workstations are reached through their user,
never through files on the server — the register says who is there
and what they are doing, and nothing more.

The answer is information, not permission. A reply that says "go
ahead" does not replace the user's decision, and a reply is not
guaranteed to come at all.

Ask it only for what it has already seen
(`rules/borrowed-rights.md`).

## Deregister when the changes are done

A session rarely gets an end the agent can see: the user closes or
deletes it when they are done. So deregister as soon as the changes
the user asked for on a host are made, verified and logged
(`rules/changelog.md`) — not at some later end of the session:

```
rmdir /tmp/hostwarden/<token>+*
```

An error means the entry is already gone; nothing else to do.

When more changes on the same host are likely and it is not clear
whether the user is done, ask once how long to keep the host:
release it now, or hold it for a time they name. For a hold, renew
the entry with `<beat>` set to the end of that time instead of
deregistering; ask again, or deregister, when it runs out. A
session that is simply deleted leaves its entry behind; it goes
stale 30 minutes after its last beat, or when a set hold ends, and
the next session removes it.

## The workspace

Every session on this workstation writes into the same `memory/`
workspace, its index included. Commit only what this session
wrote, by name — the files of each host it changed or recorded,
`changelog.log` included — when it is done with that host
(`rules/changelog.md` → The Workspace):

```
bin/hostwarden-sync commit "<headline>" \
  memory/servers/web1.example.com/memory.md \
  memory/servers/web1.example.com/changelog.log
```

Before that, in one call, read `git -C memory diff HEAD -- <paths>`
and every one of those files git does not track yet
(`git -C memory ls-files --others -- <paths>` names them) in
full: a diff shows nothing for a new file. A file that holds lines
you did not write
is being changed by another session right now: leave it out and
say so; never split it and never revert their lines. It still
needs a decision before you finish on that host: ask the user
whether to commit it with the other session's lines in it, naming
both in the message, or to leave it for that session.

### Changes a session left behind

`bin/hostwarden-sync pull` names uncommitted changes it could not
move past at session start. They belong to another session at
work, or to one that was deleted or crashed before it committed.
A file under `memory/servers/<hostname>/` was left behind when
both hold:

- the host's register, as the activity check lists it, has no live
  entry naming your own `<user>@<workstation>`;
- nothing touched the file for 30 minutes (`find memory/<path>
  -mmin -30` prints nothing) — a session that only reads never
  registers, yet records its connection.

A file outside any host directory was left behind when no other
session runs on this machine.

Ask before taking them over. In one local call gather
`git -C memory status --short`, `git -C memory diff --stat`, a
`cksum` of each file (the only record of an untracked file's
content), the host's newest `changelog.log` entry and the open
items of its `todo.md`; show them, and say that a
session deleted mid-edit may have left a file half-written. The
user chooses between committing them as they are and leaving them.
Discarding them is theirs to do by hand; never offer
`git checkout` or `git restore` on them.

Right before committing, repeat both checks, the status and the
`cksum`s in one call; commit only if nothing changed. Commit them on their own
with the message
`memory(<hostname>): changes left by an ended session`, then run
`bin/hostwarden-sync pull` again.
