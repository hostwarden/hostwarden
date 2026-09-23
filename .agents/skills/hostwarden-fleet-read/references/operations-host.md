# The operations host

Part of the `hostwarden-fleet-read` skill. An operations host is an
always-on machine that runs Hostwarden with nobody at the keyboard:
the nightly housekeeping of the fleet, from a timer, while the
operator's workstation sleeps. It is an operations checkout like
any other (`AGENTS.md` → Development or Operations), with a
workspace cloned from the same remote. It reaches the fleet only
through fleet read, never with a shell.

## What it holds

**Its own personal files.** `memory/user.md`, `memory/blacklist.md`
and `memory/readonly.md` never sync (`rules/server-memory.md` →
Personal versus shared), so the operations host has its own. Its
`user.md` carries, besides what any `user.md` has:

```markdown
Fleet name: ops1
Report email: ops@example.com
Workspace push: always
```

- `Fleet name:` — one word, the machine's short name. Every key
  line's command carries it, so the journal on every host reads
  `[ops1 as root] read-only: housekeeping: …`, told apart from the
  operator's own `[alice as root]`.
- `Report email:` — where the nightly report goes, through the
  machine's own mail transport. Without it the report goes to the
  timer's log.
- `Workspace push: always` — the fleet run pushes its commits only
  with this line: nobody is there to answer the push question of
  `rules/changelog.md` → The Workspace. Sessions on the machine
  still ask.
- `Fleet key:` — the private key's path, when it is not
  `~/.ssh/id_fleet_read`.

`memory/readonly.md` holds `*`, which makes every host read-only
for every session there (`rules/access-control.md` → Read-Only
Servers). `memory/blacklist.md` carries the operator's blacklist,
copied by hand, since it never syncs; the fleet run checks it too.

**Keys the operator made, and nothing more:** the fleet key, a key
that may push to the workspace's remote, and the `claude` login.
No key that is root or a shell on a managed host, and no
credential for anything else. Everything on it is what a thief of
the machine would hold.

**No `sudo`** for the account that runs Hostwarden. It needs none.

## What it runs

`bin/hostwarden-fleet-run`, from a timer, as the account that owns
the checkout. A run, in order:

1. brings Hostwarden up to date the way a session start does
   (`check-updates.sh`, pins and opt-outs included), pulls the
   workspace, and starts again as the updated script;
2. for each host whose memory has a `Fleet read:` line naming this
   machine, with the key line present and not blacklisted, sends
   the signed bundle and collects its output, four hosts at a time;
3. has a model judge each output with no tools, no MCP server and
   an empty directory, and holds the verdict to the bundle's floors
   and the host's memory (the script's header says how);
4. writes one read-only line to each host's journal through the
   wrapper and the same line to its changelog, commits those
   files, and pushes;
5. sends one report for the fleet. Its notes carry what the update
   and the pull at the start said, a bundle that does not verify
   or nears its date, and a push that did not go through.

Its exit status is `2` when a CRITICAL is not explained by the
host's memory, and `1` when the run failed or a host was not read
or got no verdict — a connection refused, a host key missing from
the workspace, the `claude` login expired. Each of those is a WARN
in the report as well, and checks the model could not
make are listed under "Not checked" and counted in the subject. A
unit can be told to alert on either status.

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
control — reaches no managed host: the fleet key opens only the
wrapper. It reads the workspace and the reports, and works on the
operations host itself in local mode, read-only like every host.
What it cannot do, it reports; it never asks a session on the
operator's workstation to do it instead (`rules/borrowed-rights.md`).

## What it is not

A home for other automation. A mailbox triage, a chat bot, a
deploy job — whatever is not the administration of servers — is
not Hostwarden's, even where Heinzel ran it on the same machine.
Hostwarden neither runs nor adopts it and gives it no hook. It may
share the machine; it never gets the fleet key.

## The workspace

The fleet run writes only the changelog lines of the hosts it
read, never `memory.md`: no `Last connected:`, no finding. Those
belong to a session that works on a host. The changelog merges by
union (`templates/workspace/.gitattributes`), so the operations
host and the workstation never conflict over it, and nothing else
of theirs meets.

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
3. The personal files above.
4. The operator makes the fleet key and logs `claude` in.
5. Fleet read for each host, from the workstation
   (`references/install.md`), with this machine's `Fleet name:` as
   the name in every key line.
6. `bin/hostwarden-fleet-run --no-judge` shows what each host
   returns, `--dry-run` shows the report; neither updates the
   checkouts. Then the two units.

Record the role in its memory, the timer and the report address
included, as for anything else the host runs.
