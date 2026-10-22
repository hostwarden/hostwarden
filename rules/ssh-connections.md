# SSH Connections: Few and Shared

Firewall rules that rate-limit new connections to
port 22 (`ufw limit`: 6 in 30 seconds; iptables
`recent` or `hashlimit`) and network IPS signatures
for SSH scans count **TCP connections, not
commands**, successful logins included. A busy
Hostwarden session can trip them and lock itself out,
and the block looks like a broken host. If that has
already happened, see `rules/ssh-unreachable.md`.

fail2ban, sshguard and sshd's own
`PerSourcePenalties` (OpenSSH 9.8+) count failed
logins instead; see section 3.

## 1. Bundle commands

One call per logical step, not one per command:

    ssh … host 'sh -s' <<'EOS'
    export LC_ALL=C
    cmd1
    cmd2
    EOS

Its first line sets the locale (`rules/locale.md`).
Where the loaded OS file names its own bundle — Windows,
`rules/os/windows.md` → Reaching PowerShell, and DrayOS,
`rules/appliance/drayos.md` → Access and Shell — use that.

`sh -s` also decides what a pattern with no match
does. `sh` keeps it as it is. zsh, macOS's login
shell, aborts the whole command line on it, and csh
the command it stands in; a trailing `|| true` turns
either into a silent success.

- Send several files in one `scp`/`rsync`.
- Do not poll a host every few seconds. Run a long
  job on the host and read it back with one call
  that waits there (→ Long jobs).
- `ProxyJump` costs a connection to the jump host
  **and** one to the target. Both are shared
  afterwards, since the jump host reads the same file
  (`rules/ssh-config.md` → Jump Hosts).

## 2. Share connections

The standard options in `AGENTS.md` → SSH Options
turn on OpenSSH connection sharing (`ControlMaster`):
repeated calls ride **one TCP connection per local
user, remote user, host and port**. Later calls are
several times faster, open no new connection, and
key agents that confirm each use ask only once.

It does not help with the first connection per host
and remote user, with the first one after
`ControlPersist` expires, or with **failed logins**,
which are never shared.

### Why these values

`bin/hostwarden-ssh-config` writes them into
`memory/ssh_config`. Keep them as they are:

- **Hostwarden's own file, ahead of `~/.ssh/config`:**
  works on every machine without setup, reaches a jump
  host, and wins over a `ControlMaster` block the user
  keeps for themselves, since ssh keeps the first value
  it finds.
- **`~/.cache/hostwarden/`, not `~/.ssh/` or `/tmp`:**
  the taboo guard reads any path under `.ssh/` as key
  material and would block every remote `rm`, `mv` or
  `chmod`; `/tmp` is writable by other users.
- **`%C`:** a fixed-length hash. Readable names can
  pass the 104-byte socket path limit on macOS, and
  SSH then fails the call (`ControlPath too long`).
- **`<id>`:** a checksum of the checkout's path, ten
  digits at most. `%C` knows host, port and users,
  not which known_hosts checked the key, and a call
  that rides a master skips the check. Two checkouts
  under one account must not share one.
- **`ServerAliveInterval=15`,
  `ServerAliveCountMax=3`:** retire a master with a
  dead network path after 45 seconds, whatever
  `~/.ssh/config` says. `ConnectTimeout` does not
  cover a call over an existing connection.
- **The known_hosts lines:** `memory/known_hosts`
  alone decides (`rules/host-keys.md`).
  `GlobalKnownHostsFile /dev/null`,
  `KnownHostsCommand none` and `VerifyHostKeyDNS no`
  switch off the other sources an `ssh_config` can
  add, SSHFP records in DNS among them, and
  `UpdateHostKeys no` keeps ssh from rewriting the
  shared file behind the rule's back. An ssh older
  than OpenSSH 8.5 has no `KnownHostsCommand` and
  rejects the keyword (`Bad configuration option`,
  exit 255, before any connection), so the generator
  writes it only where ssh accepts it: such an ssh
  has no source of that kind to switch off.
  `bin/hostwarden-doctor` reports the case.

### Fresh-login options

For an access test, and for the single retry after a
call that hangs:

    ssh -F "<checkout>/memory/ssh_config" \
      -o ControlMaster=no -o ControlPath=none …

An option given with `-o` wins over the file, so the
call opens a login of its own instead of riding the
shared master. Everything else, the host-key check
included, stays as on every other call. A jump host
reads only the file and keeps sharing: the login
tested is the target's, and a retry through a stale
jump host master hangs until the keepalives retire
it, 45 seconds at most.

Use them for:

- **Access tests.** Anything that answers "can this
  login still succeed?" — after changing
  `authorized_keys`, an account, its shell or groups,
  PAM, host keys, or firewall rules on the SSH port,
  and the root SSH probe in
  `rules/privilege-escalation.md`. A shared master
  answers from the login **before** the change, so a
  broken login reads as working. Make all related
  changes first, then run one fresh-login call that
  also prints what you need (`id; groups`).
- **A call that hangs or fails while sharing:** a
  stale master. Follow `rules/ssh-unreachable.md`.

`Session open refused by peer` is different: the
master is fine but full (sshd `MaxSessions`, default
10 per connection). Let your own parallel calls to
that host finish, then repeat the call as usual.

### Caveats

- **The socket directory must exist.** If it is
  missing, every call fails *after* the login with
  `unix_listener: cannot bind to path … No such file
  or directory` and exit 255. The host is fine:
  create the directory
  (`mkdir -p -m 700 ~/.cache/hostwarden`) and repeat
  the call.
- **`scp` never starts a master.** It passes
  `-oControlMaster=no` ahead of your options, so it
  only reuses one. Open it with an `ssh` call first;
  the onboarding already does.
- **Never close a master you did not start.** Other
  Hostwarden sessions and scripts on the same local
  account use the same socket path, and
  `ssh -O exit`/`-O stop` ends their sessions too.
  For experiments, add a path of their own
  (`-o ControlPath=~/.cache/hostwarden/test-%C`) and
  close only that one.
- **Login records understate activity.** `last`,
  `who` and the sshd log show one login for many
  calls. Use `rules/activity-check.md` to judge
  whether someone else is working on the host.
- **Security.** While a master is open, any process
  of the same local user can use it without key
  approval. Keep `~/.cache/hostwarden` at `0700`; on a
  shared account, shorten `ControlPersist`.

## 3. Avoid failed logins

With fail2ban's defaults, 5 counted events in 10
minutes ban the source address for 10 minutes. If
the `recidive` jail is on, 5 bans in a day become a
week on all ports. The user's own failed logins
count toward the same limit. Counted are:

- an unknown user (`Invalid user`);
- a root login refused although the key fits
  (`ROOT LOGIN REFUSED`);
- more wrong keys than `MaxAuthTries` (default 6),
  ending in `Too many authentication failures`;
  the rejected keys count too, unless a later key
  logs in;
- in fail2ban's `ddos` and `aggressive` modes and
  for `PerSourcePenalties`: connections that never
  log in (`nc -z`, `ssh-keyscan`, the latter only
  ever run on a server against itself,
  `rules/ssh-ca.md` → Host Certificate); those two
  fail2ban modes also count every rejected login.

The rules that own these steps keep Hostwarden clear of
them: `rules/ssh-user.md` (user names),
`rules/privilege-escalation.md` (root probe) and
`rules/ssh-unreachable.md` (rejected logins, port
probes).

## 4. Long jobs

The tool's own time limit ends a call long before a
host is done with a big job (Claude Code: 2 minutes
by default, 10 at most). A dropped connection or a
context reset ends it just the same. The command
runs on, and the session never learns its exit
status or sees its output.

So a command that can take more than a minute, or
that must not be left half done (package upgrades,
database migrations, `rsync` of a large tree,
backups, builds, a long `find`), never runs inside
the SSH call. It runs as a **job** on the host: one
directory under `~/.hostwarden-jobs` (the SSH user's
home, `/root` for root), the command in a file, its
output and exit status in files beside it. The call
only starts it and returns. The directory is not
`$BACKUP_DIR`: the retention `find` there
(`rules/backups.md`) would delete a job's files.

A job writes files, so a host in read-only mode
(`rules/access-control.md`) gets none, and neither
does a host a rule forbids writing to. Its long
check runs in the foreground, narrowed or split
into pieces that each end within the tool's limit.

```
ssh … host 'sh -s' <<'EOS'
export LC_ALL=C
set -e
umask 077
mkdir -p ~/.hostwarden-jobs
find ~/.hostwarden-jobs -mindepth 2 -maxdepth 2 \
  -name status -mtime +7 | while read -r s; do
  rm -r "${s%/status}"; done
d=$(mktemp -d ~/.hostwarden-jobs/$(date +%Y%m%d-%H%M%S)-upgrade.XXXXXX)
cat >"$d/cmd" <<'CMD'
apt-get -o DPkg::Lock::Timeout=300 -y dist-upgrade
CMD
(nohup sh -c 'sh "$1/cmd" >"$1/out" 2>"$1/err" &
  echo $! >"$1/pid"; trap "" TERM
  wait $!; echo $? >"$1/status"' sh "$d" \
  </dev/null >/dev/null 2>&1 &)
echo "$d"
EOS
```

`mktemp -d` gives every job a directory of its own,
also for two sessions that start one in the same
second. The `find` removes the jobs that finished
more than 7 days ago: the `status` file marks them,
so a job that still runs is never touched. A
directory with no `status` is a job that died or is
still running; look it up (→ below) before removing
it by hand.

`set -e` ends the call at the first step that fails
(a home that takes no write, a full disk), before
anything is started.

The block needs only `sh` and `nohup`, which Linux,
FreeBSD, macOS and busybox all have (tried on Debian
and Alpine): no `screen` or `tmux`, nothing to
install. The job outlives the
call and the connection. Run it with the privilege
the work needs and no more: as root when the login
is root, otherwise `sudo -n` inside `cmd`
(`rules/privilege-escalation.md`).

Write the command so that a second run does no harm,
because one day you will not know whether the first
one ran: `rsync` rather than `scp` or `cp`,
`mkdir -p`, a check before `useradd`,
`DPkg::Lock::Timeout` instead of failing on the
lock, and never `&& reboot` on the same line as an
upgrade. The reboot is its own step, after the
result was read and the user said yes
(`rules/coordination.md`).

Read the job back, at the path the start call
printed, with one call that waits on the host, never
a call every few seconds (→ Bundle commands). Set
the tool's timeout to cover the wait (Claude Code:
`timeout`, up to 10 minutes):

```
ssh … host 'sh -s' <<'EOS'
export LC_ALL=C
d=~/.hostwarden-jobs/20261021-141500-upgrade.Ab3dEf
[ -d "$d" ] || { echo "no such job: $d"; exit 1; }
i=0
while [ ! -f "$d/status" ] && [ $i -lt 10 ]; do
  sleep 30; i=$((i+1))
done
cat "$d/status" 2>/dev/null || echo running
tail -n 40 "$d/out" "$d/err"
EOS
```

`status` holds the exit code and exists only once
the job is over. No `status` after the wait means it
is still running: repeat the call. No `status` and
no process whose command line names the job
directory means the host went down with the job:
read what it left behind before anything is started
again (`rules/verify-before-reporting.md` → A
command without a result ran, or it did not). The
test is the command line, never a number kept in a
file, which a reboot leaves behind for an unrelated
process to inherit:

    { ps -A -ww -o pgid= -o args= \
      || ps -A -o pgid= -o args=; } 2>/dev/null \
      | grep -F "$d" | grep -vF 'grep -F'

`-ww` keeps a pipe from cutting the lines at 80
columns; busybox `ps` takes neither it nor wider
lines, hence the second form. The output is the
wrapper and the job, each with its process group.

To stop a job, signal its process group, read from
that same output (`g`, the first column). sshd gives
every call a group of its own, and the wrapper
ignores the signal, so the status is still recorded:

    kill -TERM -"$g"

A job whose `cmd` runs under `sudo -n` belongs to
root, which the SSH user cannot signal: stop it with
`sudo -n kill -TERM -"$g"`. In local mode the job
shares the session's group, so stop it by pid, the
job and every process below it, once the command
line above shows the job still there:

    k() { for c in $(ps -A -o pid= -o ppid= \
      | awk -v p="$1" '$2==p{print $1}'); do k "$c"; done
      kill -TERM "$1"; }
    k "$(cat "$d/pid")"

**Other people see a job only if it is announced.**
The presence map marks a host busy for a foreground
call alone (`rules/coordination.md` → Presence map),
and this call returns at once. So before the start,
register or renew the entry with `<beat>` set to the
job's expected end and a task such as `job-upgrade`
(`rules/parallel-sessions.md` → Register, and
renew), and deregister only when the result is read.
Where the host has no register, the journal pair
stands in, `done` written when the result is in. A
job that restarts a service, reloads the firewall or
changes the network is announced first
(`rules/coordination.md` → Announce, wait, go), as
the same command would be in the foreground.

Record a running job and its directory in
`memory/machines/<hostname>/todo.md`
(`rules/machine-memory.md` → Session to-do list), so
the next session, or a colleague's, picks it up
instead of starting it again. Delete the job
directory once the result is in the changelog
(`rules/changelog.md`).

This is for hosts with a POSIX shell. Windows has
none, and its rules allow no write beyond the journal
and two setup changes (`rules/os/windows.md`): a long
command there runs in the foreground, narrowed or
split. An appliance that is reached through an API
only, or whose OS file names its own job mechanism,
uses that instead.
