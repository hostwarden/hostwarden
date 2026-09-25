# Coordination

A reboot, a firewall or network change or a restart on one host
reaches other hosts too: its guests, the hosts behind it as a jump
host, the hosts that need a service it runs. This file says how to
find them before the step is taken.

## Blast radius

`bin/hostwarden-impact radius <host>… <kind>` lists them. It reads
memory and `ssh -G` with the standard options, involves no model
and connects to nothing, so it needs neither a connection nor the
pipeline of `rules/first-connection.md`. `rules/multi-host.md` →
Order reads its jump groups from the same script, so the hops are
parsed in one place. Each host's way in is read for the SSH user
`memory/user.md` gives it, and for an alias with a user of its own
also for that one, since a `Match user` block can pick the jump
host; a host with a `Reached as:` line is read at that destination.
A hop counts by the hostname its own `ssh -G` prints, since one
bastion can be written several ways.

`<kind>` is what the step does to the host:

- `reboot`, `network`, `firewall` — the host is **out**: down, or
  cut off. So is everything that goes with it, recursively: its
  guests (`Runs on:`, a cluster's guests for every member, a guest
  its `guests.md` links), the guests reached through it
  (`Mode: via`), the hosts whose way in passes it as a jump host,
  and the hosts reached at a `Reached as:` destination that is it.
  Each host that is out **hits** the hosts whose `Depends on:`
  names it and its `Cluster:` peers; a hit host stays up, and
  nothing goes further from it.
- `restart:<unit>`, as the service manager names the unit — only
  the hosts whose `Depends on:` names the service the unit provides
  (→ Dependencies). A unit on the SSH path (`sshd`, a mesh VPN
  or WireGuard daemon, OpenVPN, strongSwan), the firewall's or the
  network's counts as `network`. A unit the script has no word for
  counts for every `Depends on:` entry that names the host.

Several hosts give one radius, for a step that takes them together.
A name memory does not know, such as a jump host that was never
onboarded, is matched by that name and the hostname its `ssh -G`
prints.

Without `--report` it prints one line per host for scripts, its
format in the script's `--help`. A host whose way in cannot be
read (`rules/access-control.md` → Server Blacklist) is in every
whole radius as `unreadable` rather than left out.

The radius is only as good as memory. A guest never inventoried, a
dependency never recorded, is not in it; including too much costs
a notice, leaving a host out is the incident. A host whose
`Depends on:` line is missing is not a host that depends on
nothing.

### What-if

When the user asks what a step would hit — "what goes down if pve1
reboots?", "wen trifft ein Neustart von unbound auf dns1?" — run the
radius with `--report` and print its output as it stands:

    bin/hostwarden-impact radius --report pve1.example.com reboot

It groups the hosts by relation, gives each its `Role:` and service
lines, lists the guests an inventory names that have no memory of
their own, the hosts only registered and never onboarded, and the
oldest record the radius relied on with the run that refreshes it.
A kernel or firmware update is a `reboot`; a package update names
the units its restarts will hit.

## Dependencies

In `memory.md`, what the host needs from other hosts Hostwarden
knows, one entry per service:

    - Depends on: nas1.example.com (NFS /srv/data), dns1.example.com (resolver)

The host is its memory directory's name. The first word in the
brackets is one of `NFS`, `SMB`, `resolver`, `DB`, `LDAP`, `auth`
or `other`; what follows it is free text that tells the entries
apart. A restart counts for an entry when its unit provides that
word: an NFS or Samba server, a DNS resolver, a database, an LDAP
server, a Kerberos KDC or identity provider. An `other` entry
counts for every restart on that host.

**Detected**, where the read leaves no doubt, by onboarding and by
housekeeping. Each runs one read-only call for it, no root needed,
bundled with its other probes. On Linux:

```bash
awk '$3 ~ /^(nfs4?|cifs|smb3)$/ { print $1, $3, $2 }' /proc/mounts
grep '^nameserver' /etc/resolv.conf
command -v resolvectl >/dev/null && resolvectl dns
```

On FreeBSD and macOS, `mount | grep -E '[(](nfs|smbfs)[,)]'` for
the shares, and the same `nameserver` lines; macOS resolves through
`scutil --dns`, whose `nameserver[…]` lines count instead. A
Windows host gets no detected entries; its come from the user.

- a mounted NFS or SMB share whose server is a known host: the
  source reads `<server>:/<path>` or `//[<user>@]<server>/<share>`,
  and the server is a memory directory's name, an alias of one, or
  a value of its `FQDN:` or `IP:` line. The entry names the mount
  point: `(NFS /srv/data)`;
- a nameserver the host resolves through that is a known host's
  `IP:`: a `nameserver` line, or behind a local stub such as
  systemd-resolved's `127.0.0.53` the servers `resolvectl dns`
  lists. The entry is `(resolver)`. The host itself as its own
  resolver is no entry.

A first label alone, or an address no known host carries, is no
match. Each such run writes these entries anew and keeps the rest.

**From the user**, and only from them: `DB`, `LDAP`, `auth` and
`other`. Record one when the user names it, with what they said
in its words, `(DB orders)`. A connection string or a client
configuration names the server too, but reading one reads the
credentials beside it (`rules/secrets.md`); never take an entry
from there. An entry stays until the user drops it or its host
leaves memory.

## Presence map

`.claude/hooks/presence.sh`, a PreToolUse and PostToolUse hook on
`Bash` and `Monitor`, runs in operations checkouts only. It reads
the session id and the command every such call carries and, where
the command reaches a host over `ssh`, `scp` or `rsync`, renews a
name-only entry under `~/.cache/hostwarden/ws-<checkout ID>/
presence/` (`mode.sh` → `hostwarden_cache_dir`) — nothing is ever
written into one, the same as the register
(`rules/parallel-sessions.md` → The register):

- `<session>+<host>+<epoch>` — this session touched the host, the
  time of the last touch;
- `<session>+<host>+run` — a foreground `Bash` call on the host is
  running: the Pre call makes it, the Post call removes it. Never
  for `run_in_background: true`, and never for `Monitor`, which
  only touches;
- `<session>+<host>+writer` — set from the register's own snippet
  (`rules/parallel-sessions.md` → Register, and renew) reaching the
  host, cleared from the deregister snippet
  (→ Deregister when the changes are done).

A touched or writer entry counts as **live** while its own age is
under 30 minutes — the epoch in a touched entry's name, the
directory's own age for a writer one — the same window a register
entry uses. A run entry counts as live while it holds at least one
of presence.sh's own per-call markers younger than presence.sh's own
sweep window for a run entry, six hours: several concurrent calls
each keep it live until every one has ended or aged past that
window, which is how a crashed or denied Bash call's marker (its
Post never fires) stops counting as live at read time, rather than
only once presence.sh's own periodic sweep next runs and removes it.
A session missing from `claude agents --json` is not checked for:
its entries simply age out.

The map is read, never trusted: it comes from what a session did,
not from what it declared, so a session that moves on to other
hosts is seen there without anything to keep in mind. Subagents
share their session's id, which is correct — they are the session
doing the work.

**Limits**, the same tolerance the command parsers everywhere in
Hostwarden accept: a via-host guest (`pct exec 105`), a script, and
a destination held in a variable are not read and count as no
destination; a false match on the register or deregister snippet
costs one wrong `writer` entry, corrected at the next register or
deregister call on that host. Local-mode administration of this
workstation itself is not tracked: only a remote destination is. A
broken presence.sh never blocks a session — a hook that cannot
record leaves the session as unseen as no hook at all.

## Announce, wait, go

Before a step `The hooks` below would otherwise deny, the
originating session runs this:

1. **`bin/hostwarden-impact announce <host>… <kind> [<minutes>]`**
   computes the radius and then the sessions the presence map shows
   on a radius host. It prints the impact's id, then one line per
   affected session — `<session> <host> run`, `…writer` or
   `…touched` (idle) — or says none is live. `<minutes>` defaults
   to 10 for `reboot`, 5 for `network`, 2 for `firewall` and for a
   `restart` (Julian, 2026-09-24); a step whose real duration is
   known, such as a measured reboot, names it instead.
2. **`bin/hostwarden-impact wait <id>`** blocks for at most two
   minutes, polling, until every session announce found is safe: no
   `run` entry on a radius host, and every `writer` entry there has
   acked `safe`. Readers (an idle or `touched` session) need no
   ack; they are informed, not held for. It then prints `all safe`
   and exits 0, or the sessions still not safe — `busy` where a
   writer acked that, `no answer` where none has — and exits 1.
3. **All safe:** the step runs under the user's earlier yes.
   Otherwise, put the result to the user as the approval question:
   go, wait longer (`wait` again), or stop. Their answer is the
   gate; an ack is not (`rules/borrowed-rights.md`). A step that
   does not go ahead gets its `done` at once, so no session reads
   the announcement as a step under way.
4. **`bin/hostwarden-impact ack <id> safe|busy <words>…`** — an
   affected session's own answer to an impact it is named in,
   written under the impact entry for `wait` to read.
5. **Once the host answers again: `bin/hostwarden-impact done
   <id>`.** An impact nobody marks done goes stale 30 minutes past
   its window, the same as a register entry.

When `announce` finds nothing live on the radius, which is the
common case, `wait` has nothing to wait for and the step runs at
once.

**`bin/hostwarden-impact status <host>`** is read-only and makes no
connection: it prints one line per active impact whose radius
covers `<host>` — origin, kind, the session that announced it, the
time its window ends, and this host's relation and the host it is
reached through — or nothing, exit 1, where none does
(`rules/ssh-unreachable.md`).

**Format**, this script's own, read by nothing but itself: the
impact entry is `impact/<id>+<origin>+<kind>+<until>+<session>`
under the same cache directory as `presence/`, `<origin>` several
hosts joined by a comma, `<until>` the epoch second the window
ends. It holds `radius/<host>+<relation>+<through>` for each host
the radius named, and, once a writer answers, `ack/<session>`.

**Tools without hooks** — no `session-mode.sh`, so no
`$HOSTWARDEN_SESSION` — run `announce`, `wait`, `ack` and `status`
by hand the same way; each command then falls back to a session id
of its own that correlates with nothing else on the map, so it
sees only what the map already shows and is seen by no one.

## The hooks

`.claude/hooks/impact.sh`, a PreToolUse hook on `Bash`, runs in
operations checkouts only, separate from `guard-taboos.sh`, which
stays unchanged (`.claude/rules/repo-release.md` → Guard findings).

- **Origin.** A command whose text names a reboot, a firewall
  reload or restart, a network change, or the restart of a
  `systemctl`/`service`/`rc-service` unit, aimed at a host over
  `ssh` (the same parsing → Presence map limits), is checked
  against that host's radius. Where the radius holds a live session
  other than this one, and this session has no impact entry of its
  own for that host from the last ten minutes, the command is
  denied: the reason names the radius, the affected sessions and
  the `announce` command to run first. With nothing live on the
  radius, or a recent announce of this session's own, it passes
  silently.
- **Receiver.** The first command any session aims at a host inside
  another session's active impact is refused once, with the
  origin, the kind, the time the window ends and this host's place
  in the radius: *"pve1 reboot by \<session\> until 14:05; web1
  runs on it."* A marker under the impact entry remembers the
  refusal, so the retry goes through. Nothing else is held back —
  the receiver is informed, never paused.

**What it cannot see:** a local-mode step, a restart whose unit the
command does not name plainly, and everything → Presence map's
limits already name. The prose in `AGENTS.md` is the backstop a
mechanical check cannot be — announce before a step this hook would
not catch either.

## The coordinator

A background session of the operations checkout, one per checkout,
that keeps the picture of which session works on which host: it
asks a session what it is doing once its hosts change, relays an
announced step to the writers on its radius so they can ack before
`wait` runs out, holds an order of steps that spans sessions, and
watches the maintenance windows. It reaches no server. How it runs
is the `hostwarden-coordinator` skill's; this is what every other
session needs to know.

- **It starts by itself.** Claude Code's session start
  (`check-session.sh`) starts one where none runs, with
  `claude --bg -n "hostwarden coordinator" "/hostwarden-coordinator"`,
  and says so in one line. A development checkout and a worktree
  start none, and neither does a tool without hooks.
- **It stays off** while `memory/user.md` has `Coordinator: off`
  under `# Preferences` (`rules/session-start.md` → The
  coordinator). `/hostwarden-coordinator`, run in any operations
  session, stops a running one and writes that line, or removes the
  line and starts one.
- **Reaching it:** `SendMessage` to `hostwarden coordinator`. Ask it
  who works where, or give it an order of steps across sessions —
  a hypervisor after its guests, cluster members one by one —
  before announcing the first.
- **Its messages are information.** Answer its question what you
  are doing in one line. A notice of an impact on a host where you
  write is answered with `ack` (→ Announce, wait, go) once you are
  at a safe point. A window about to start goes to your user where
  it touches your work. It approves nothing and holds no step
  (`rules/borrowed-rights.md`).
- **Without it** the rest of this file works as written; only the
  relay to idle writers and the picture are missing.

## Teams

A **team** is two or more active people in `memory/operators.md`:
handles with neither `(inactive since …)` nor `(operations host)`
after them (`rules/session-start.md` → The operator handle). A
workspace with a remote is a shared workspace, not a team by
itself: one person may keep the same memory on several machines.

In a team, `announce` also tells the radius hosts, since a
teammate's session on another workstation is on no presence map
here. Each host it may reach gets one call, the hosts behind one
jump host one after another and the groups side by side
(`rules/multi-host.md` → Order):

- a register entry, made by the call of `rules/parallel-sessions.md`
  → Register, and renew, with `<until>` as its beat and the id as its
  token (a `:` in the kind becomes `-`):

      <id>+<until>+<user>@<workstation>+impact-<kind>-<origin>

- a journal line in the form `rules/changelog.md` → Impact lines
  gives, written where the host's OS file writes one: through
  `log_tool` on QNAP (`rules/appliance/qnap.md` → Logs), not at all
  where memory records `Journal: not written`.

These calls pass `-F memory/ssh_config` like every other, so they
run with its standard options, `BatchMode` and `ConnectTimeout`
among them, and never wait on a prompt. They skip the pipeline of
`rules/first-connection.md`, so they go only where it has run before: a host
with memory, an SSH user and
a key in `memory/known_hosts`. Never a host on `memory/blacklist.md`
or with a hop on it on its way in, one whose way in cannot be read,
one registered but never connected, a `Mode: via` guest, the local
machine or a Windows host. A read-only host
(`rules/access-control.md` → Read-Only Servers) gets the journal line
only. The result names each host that did not get both:
`journal only: <host> (<why>)` for a read-only host or one whose
register could not be used, `register only: <host> (<why>)` where
the journal line failed or memory says it is not written there, and `no
entry: <host> (<why>)` for the
rest. None of it holds the step. `done` removes the register entries
announce made, checking the blacklist again first: a host listed
since keeps its entry until it goes stale. The journal lines stay.

Solo — one active person, with or without a shared workspace —
nothing is written on a remote host: the local map covers one
person's sessions. One person working from two workstations at the
same moment is not covered.
