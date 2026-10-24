# The operations host

Part of the `hostwarden-fleet-read` skill. An operations host is an
always-on machine that runs Hostwarden with nobody at the keyboard:
the nightly housekeeping of the fleet, from a timer, while the
operator's workstation sleeps. It is an operations checkout like
any other (`AGENTS.md` → Development or Operations), with a
workspace cloned from the same remote. It reaches the fleet through
fleet read, never with a shell, but for a session there while the
operator has unlocked a write key (A Write Key).

## What it holds

**Its own personal files.** `memory/user.md`, `memory/blacklist.md`
and `memory/readonly.md` never sync (`rules/machine-memory.md` →
Personal versus shared), so the operations host has its own. Its
`user.md` carries:

```markdown
Operator: ops1
Report email: ops@example.com
Workspace push: always
Presence: off
```

- `Operator:` — the machine's own handle, its short name, never a
  person's (`rules/ssh-user.md` → Operator). Every key line's
  command carries it, so the journal on every host reads
  `[ops1 as root] read-only: housekeeping: …`, told apart from the
  operator's own `[alice as root]`. It is reserved in
  `memory/operators.md` as `- ops1 (operations host)`, so it counts
  toward no team (`rules/coordination.md` → Teams), and the fleet
  run starts only once the remote's copy of that list holds it.
- `Report email:` — where the nightly report goes, through the
  machine's own mail transport. Without it the report goes to the
  timer's log.
- `Workspace push: always` — the fleet run pushes its commits only
  with this line: nobody is there to answer the push question of
  `rules/changelog.md` → The Workspace. Sessions on the machine
  still ask.
- `Presence: off` — nobody works there in parallel sessions, so
  its session start starts no presence session (`rules/coordination.md`
  → The presence session).
- `Fleet key:` — the private key's path, when it is not
  `~/.ssh/id_fleet_read`.

`memory/readonly.md` holds `*`, which makes every host read-only
for every session there (`rules/access-control.md` → Read-Only
Servers), unless the operator sets up a write key (A Write Key
below). `memory/blacklist.md` carries the operator's blacklist,
copied by hand, since it never syncs; the fleet run checks it too.

**Keys the operator made, and nothing more:** the fleet key, a key
that may push to the workspace's remote, the `claude` login, and an
encrypted write key where the operator wants one (A Write Key). No
other key that is root or a shell on a managed host, and no
credential for anything else. Everything on it is what a
thief of the machine would hold.

**No `sudo`** for the account that runs Hostwarden. It needs none.

## What it runs

`bin/hostwarden-fleet-run`, from a timer, as the account that owns
the checkout. A run, in order:

1. brings Hostwarden up to date the way a session start does
   (`check-updates.sh`, pins and opt-outs included), pulls the
   workspace, and starts again as the updated script;
2. for each host whose memory has a `Fleet read:` line naming this
   machine, with the key line present, not blacklisted and with a
   jump path it can read (`rules/access-control.md` → Server
   Blacklist), sends the signed bundle and collects its output,
   four hosts at a time;
3. has a model judge each output with no tools, no MCP server and
   an empty directory, and holds the verdict to the bundle's floors,
   the host's memory and the decisions that apply to it
   (`rules/decisions.md`; the script's header says how);
4. writes one read-only line to each host's journal through the
   wrapper and the same line to its changelog, commits those
   files, and pushes;
5. sends one report for the fleet. Its notes carry the first lines
   of what the update and the pull at the start said, which the
   timer's log has whole, a bundle that does not verify
   or nears its date, and a push that did not go through.

Its exit status is `2` when a CRITICAL is not explained by the
host's memory, and `1` when the run failed, a host was not read or
got no verdict — a connection refused, a host key missing from the
workspace, the `claude` login expired — or the report could not be
mailed. Each of those is a WARN in the report as well, and checks
the model could not make are listed under "Not checked" and
counted in the subject. A unit can be told to alert on either
status.

A finding that a decision applying to the host settles is not an
issue (`rules/decisions.md` → Rating findings): the report lists it
under "Decided", with "revisit due" once the decision's `Revisit:`
date has passed, and it raises no alarm.

**One area across the fleet.** `--section <key>`, repeatable up to
32 names, sends each host `collect <key>…` instead of `collect`: the wrapper
runs only those sections of the signed bundle and its floors
(`references/bundle.md` → Layout). It is always a dry run, whatever
else is asked — a partial read writes no journal line, no changelog
line and no first-seen date, since each would pass for a full
housekeeping run — and the judge and the report are told which
sections ran. A key the host's bundle does not list on its
`SECTIONS='…'` line leaves that host "not read" with the missing
key named, before any connection; a bundle without the line runs
only whole.

```ini
# /etc/systemd/system/hostwarden-fleet-run.service
[Unit]
Description=Hostwarden fleet housekeeping
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=hostwarden
WorkingDirectory=/home/hostwarden/hostwarden
ExecStart=/usr/bin/timeout 45m /home/hostwarden/hostwarden/bin/hostwarden-fleet-run
SuccessExitStatus=2
Nice=10
```

```ini
# /etc/systemd/system/hostwarden-fleet-run.timer
[Timer]
OnCalendar=*-*-* 05:30
RandomizedDelaySec=10m
Persistent=true

[Install]
WantedBy=timers.target
```

No `NoNewPrivileges=`: most mail transports hand a message to
their queue through a setuid or setgid program, which that setting
silently stops. Both units are deployed files of the operations
host itself (`rules/deployed-files.md`).

**An interactive session** there — over SSH, or through remote
control — gets nothing from the fleet key, which opens only the
wrapper. Without a write key unlocked, it reads the workspace and
the reports, and works on the operations host itself in local mode,
read-only like every host. What it cannot do, it reports; it never
asks a session on the operator's workstation to do it instead
(`rules/borrowed-rights.md`).

## A Write Key

Optional: an interactive session there changes hosts while the
operator has unlocked a write key, and the host is read-only again
once the key is gone and every connection opened with it is closed.
The write key is Hostwarden's own SSH identity
(`rules/ssh-identity.md`), set up in the account that runs
Hostwarden, the way that file sets it up on a workstation, with
these limits:

- **Its own agent, from an encrypted key file:** `SSH identity:
  own-agent` and `SSH identity source: file <path>`, the comment
  `hostwarden@<machine handle>-<host name>`. Never a key without a
  passphrase, never a source in a password manager, which loads with
  no person there, and never a hardware key left plugged in.
- **Each host** gets its line from the operator, beside the
  fleet-read line, and a second `Hostwarden key:` line in its
  memory (`rules/ssh-identity.md` → Putting the Key on a Host).
  With the user's CA, a certificate for a few hours replaces the
  line (`rules/ssh-ca.md` → Hostwarden's Own Certificate),
  `-V +4h` for one.
- **`memory/readonly.md`:** `*` keeps every host read-only, with the
  key unlocked too. The operator takes it out themselves and lists
  instead the hosts that stay read-only and the operations host's
  own names, `localhost` among them: without `*` nothing else keeps
  its local mode read-only. Hostwarden never edits `readonly.md`
  there, not on the operator's word either.
- **Unlocking:** the operator logs in to the operations host as that
  account and runs
  `bin/hostwarden-identity load -t 2h`, or the lifetime they want, in
  a terminal of their own there. A session started there then
  works as on the workstation.
- **Before each change** on a host, the session runs
  `bin/hostwarden-identity check` (`rules/ssh-identity.md` → Every
  Connection). Where it fails, with exit 1 the key's lifetime has
  ended or the operator emptied the agent, with exit 4 the
  certificate has; either way the session locks as below and
  changes nothing more, stricter than Every Connection, since a
  connection the certificate opened outlives it too. A shared connection opened
  with the key stays open without it, as long as calls keep using it,
  and only this check ends a busy session's write access (lab,
  OpenSSH 10.0, 2026-10-24: a call ran through the shared connection
  after `ssh-add -t 10` had run out, and the login was refused once
  it was closed).
- **Locking:** the lifetime ends, or
  `SSH_AUTH_SOCK=~/.cache/hostwarden/agent.sock ssh-add -D` ends it
  sooner; then every shared connection of the sessions there is
  closed, whatever user or jump host it went to, those of every
  checkout in the account: the agent is the account's, so a session
  of any checkout there may have used the key. They are the sockets
  `ssh-<checkout number>-…`. The fleet run's connections to hosts,
  under `fleet-`, and git's to the workspace remote, under `ssh-`
  without a number, stay out of it:

  ```bash
  for s in ~/.cache/hostwarden/ssh-[0-9]*-*; do
    [ -S "$s" ] && ssh -F /dev/null -S "$s" -O exit lock
  done
  ```
- **The fleet run never uses it:** its ssh calls, their jump hosts
  included, take no agent and connections of their own, since a
  connection a session opened with the key would carry `collect`
  too (lab, 2026-10-24); the timer loads no key. An ssh that a
  `ProxyCommand` starts reads only the account's ssh configuration
  and the system's, with no agent in its environment: neither file
  there names Hostwarden's agent, its write key, `memory/ssh_config`
  or a socket under `~/.cache/hostwarden/`.
- **No agent forwarding** to the operations host, ever: anything
  there could sign with the admin's own keys while it lasts.

## What it is not

A home for other automation. A mailbox triage, a chat bot, a
deploy job — whatever is not the administration of servers — is
not Hostwarden's, even where Heinzel ran it on the same machine.
Hostwarden neither runs nor adopts it and gives it no hook. It may
share the machine; it never gets the fleet key.

## The workspace

The fleet run writes only changelog lines, one per host it tried,
never `memory.md`: no `Last connected:`, no finding. Those belong
to a session that works on a host. A host it could not read gets
its line too, marked "the host was not read". The changelog merges
by union (`templates/workspace/.gitattributes`). Where both
machines redrew the overview page or a map, `hostwarden-sync pull`
keeps the version pulled and the next commit draws it again.

It commits its own files by path, nothing another session left.
When the pull at its start fails, it runs on what it has; the
commits wait for the next run, and the operator resolves the
workspace with `git -C memory pull` on that machine.

## Setting one up

From the workstation, the operations host is a managed host like
any other: the pipeline, a baseline, its own memory. Setting it up
is a list of asked changes there, and of steps that are the
operator's:

1. An account without `sudo` that owns the checkout
   (`hostwarden-deploy-user` shows the shape), and `git`, `jq`,
   `ssh`, the `claude` CLI and a mail transport.
2. Clone Hostwarden into the account's home, and
   `bin/hostwarden-init --clone <workspace remote>` — the operator
   gives the account a key that may push there.
3. The personal files above, `memory/readonly.md` with its `*`
   among them, which the session writes once when it creates the
   file and never edits after; with an `Operator:` handle of the
   machine's own that the remote's `memory/operators.md` does not
   hold yet. One it holds belongs to a person or another machine,
   the operator's own included, and is never taken. This session
   reserves it for the machine, as
   `- <handle> (operations host)`, committed alone and pushed as
   `rules/session-start.md` → The operator handle reserves a
   person's.
4. The operator makes the fleet key and logs `claude` in. The first
   `claude` session there finds the handle reserved as the
   machine's own.
5. Fleet read for each host, from the workstation
   (`references/install.md`), with this machine's `Operator:` as
   the name in every key line.
6. `bin/hostwarden-fleet-run --no-judge` shows what each host
   returns, `--dry-run` shows the report; neither updates the
   checkouts, so run `bin/hostwarden-ssh-config` once before them.
   Then the two units.
7. Where the operator wants one, the write key (A Write Key).

Record the role in its memory, the timer and the report address
included, as for anything else the host runs.
