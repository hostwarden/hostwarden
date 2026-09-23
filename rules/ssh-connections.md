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
    cmd1
    cmd2
    EOS

Where the loaded OS file names its own bundle — Windows,
`rules/os/windows.md` → Reaching PowerShell — use that.

`sh -s` also decides what a pattern with no match
does. `sh` keeps it as it is. zsh, macOS's login
shell, aborts the whole command line on it, and csh
the command it stands in; a trailing `|| true` turns
either into a silent success.

- Send several files in one `scp`/`rsync`.
- Do not poll a host every few seconds. Run a long
  job on the host (`nohup`, `systemd-run`, `daemon`)
  and read its log at an interval of minutes.
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
