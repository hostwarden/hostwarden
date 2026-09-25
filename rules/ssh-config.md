# SSH Config

Every SSH, scp and rsync call passes
`-F "<checkout>/memory/ssh_config"` (`AGENTS.md` → SSH Options).
What Hostwarden writes is `memory/ssh_hosts`: how a host is
reached when its name alone does not say it. `/srv/hostwarden`
stands for `<checkout>` in the commands below.

## The Files

- **`memory/ssh_config`:** written by `bin/hostwarden-ssh-config`
  for this checkout on this machine, at every
  `bin/hostwarden-sync pull` and so at every session start. Never
  edited and never committed: it names this machine's paths. Its
  order is its precedence, since ssh keeps the first value it
  finds: the host blocks of `memory/ssh_hosts`, then `Match all`
  with the standard options, then the user's `~/.ssh/config` and
  `/etc/ssh/ssh_config`.
- **`memory/ssh_hosts`:** host blocks in ssh_config syntax,
  limited to five keywords. Shared in a shared workspace
  (`rules/server-memory.md` → Personal versus shared).
- **`~/.ssh/config`:** the user's own. It still applies to every
  call, for what the two above leave open. Hostwarden never
  writes it.

## What memory/ssh_hosts Holds

One keyword and one value per line, indented under its `Host`
line. A comment takes a line of its own:

- **`Host`:** the names the block applies to, those memory and
  the user connect by; the host's `- FQDN:` adds none
  (`rules/dns-aliases.md` → The FQDN). Plain names, or patterns
  with `*`, `?` and `!`.
- **`HostName`:** the name or address to connect to.
- **`Port`:** an SSH port other than 22.
- **`ProxyJump`:** `[user@]host[:port]`, several comma-separated,
  or `none`.
- **`HostKeyAlias`:** the name the host's key is looked up by in
  `memory/known_hosts`.

```
Host db1 db1.example.com
  HostName 192.0.2.30
  Port 2222
  ProxyJump jump.example.com
```

Nothing else passes `bin/hostwarden-ssh-config`: no `User`, no
`IdentityFile`, no forwarding, no `Match`, `Include`,
`ProxyCommand` or any other keyword, and no value with a quote, a
`%` token, a `$` or a leading `-`. In a shared workspace, anyone who
can push to it writes this file, and ssh_config can run commands
on every workstation that shares it; the five keywords cannot.

- **The SSH user stays in `memory/user.md`** (`rules/ssh-user.md`):
  it is personal, and the call names it as `user@host`, which wins
  over any `User` line.
- **A key file, an agent, a host only this user reaches** stay in
  the user's `~/.ssh/config`.

One line that fails keeps every host block out of
`memory/ssh_config`, the good ones too, and the script names each
failing line; the standard options still apply. A
`memory/ssh_hosts` that is a symbolic link is never read and keeps
them out the same way. Correct or remove the line, or replace the
link with a plain file. Never reach the same effect through
`memory/ssh_config`, `~/.ssh/config` or `-o` on the command line.

## Adding a Block

When the user says a host answers on another port, only through a
jump host, or at an address its name does not resolve to. A block
the user's own `~/.ssh/config` already has works through the
include: in a shared workspace, offer once to copy its
`HostName`, `Port` and `ProxyJump` into `memory/ssh_hosts`, so every
machine that shares it reaches the host too. Never copy it unasked.

1. Add the block to `memory/ssh_hosts`. A specific `Host` goes
   above a pattern that also matches it.
2. Run `bin/hostwarden-ssh-config`. Any output names a failing
   line: fix it before going on.
3. Check what ssh will do, without connecting, as the user the
   calls log in as, since a `Match user` block can change the
   answer:

   ```bash
   ssh -F "/srv/hostwarden/memory/ssh_config" -G alice@db1.example.com |
     grep -E '^(hostname|port|proxyjump|hostkeyalias) '
   ```

4. A new `HostName` or `Port` for a known host changes its
   identity and the name its key is looked up by: IP Verification
   in `rules/dns-aliases.md`, then Before the First Connection in
   `rules/host-keys.md`. Where the user has confirmed that its
   sshd moved, set its `- SSH port:` line to the new port first,
   and name its `- DNS alias:` names on the block's `Host` line
   too, or the aliases stay on the old port. Once the host's key
   is in place on the new port, give each alias its key there as
   `rules/host-keys.md` → DNS Aliases says. A new `HostName`
   drops the `- Resolved via:` line for the name ssh connected to
   before (`rules/mdns.md`).
5. Commit it like every workspace file, by its path
   `memory/ssh_hosts` (`rules/parallel-sessions.md` → The
   workspace). A block for a host with no memory yet goes in with
   the memory step 6 of `rules/first-connection.md` writes.

When a host's memory directory is removed, remove its block too,
and run the script again.

## A Port the User Names

The user may write the port with the host:
`web1.example.com:2222`, `alice@web1.example.com:2222`,
`ssh://alice@web1.example.com:2222`, `-p 2222`, or "port 2222".
An IPv6 address carries a port only in brackets,
`[2001:db8::1]:2222`; a bare one has none. The host is the name
without the scheme, the user and the port, and that is the name
everything reads: the blacklist and read-only checks, the
directory under `memory/servers/`, the entry in `memory/user.md`.
A user written with it is one named on the command line
(`rules/ssh-user.md`).

- **The local machine with a port** — `localhost:2222`,
  `127.0.0.1:60022`, `[::1]:2222`, the user's own hostname with a
  port — is a guest behind a port this workstation forwards
  (Vagrant, QEMU, WSL in NAT mode), never local mode. Only this
  workstation reaches it, and the same port can lead to another
  guest tomorrow, so it gets no block in the shared
  `memory/ssh_hosts`. It belongs in the user's own
  `~/.ssh/config` (The Files), under a name of its own with
  `HostName`, `Port` and a `HostKeyAlias` of that name, which
  the user writes. Say so, and go on with that name once it is
  there.
- **A WSL instance in memory:** where memory holds
  `<windows-hostname>-wsl-*` directories for the name, the one
  whose `SSH port:` is this port is the host
  (`rules/server-memory.md`): use it, and write nothing.

Where the `port` line of `ssh -G <user>@<host>` already shows that
port, nothing is written. Otherwise the port goes into
`memory/ssh_hosts` as Adding a Block says:

```
Host web1.example.com
  Port 2222
```

- **The block:** where one already names the host, its `Port`
  line is set to the port, never joined by a second one: ssh keeps
  the first. An IPv6 address goes on the `Host` line without its
  brackets.
- **A host with no memory yet**, a new host or a new name below:
  written where `rules/first-connection.md` step 3 says, and
  committed with the memory step 6 writes (Adding a Block,
  step 5). Where the work on the host ends before then — the port
  refused or timed out, the user stopped, the session moved on to
  another host or ended — undo what it wrote: the
  block it added, or, in a block that was there, the `Port` line
  it set, back to what it was. A port the user named that fails
  is reported, and no other port is tried in its place: Finding
  the Port is for a host whose port nobody named.
- **A known name on another port:** the port is part of the
  host's identity (Adding a Block, step 4). Before writing
  anything, ask whether its sshd has moved to that port or
  another machine answers there, such as a WSL distribution on a
  Windows host or a machine behind a router's forwarded port.
  Moved: change its `Port` as Adding a Block, step 4 says,
  `- SSH port:` and aliases included. Another machine: the known
  name's
  block stays as it is, since every later call to that name
  would reach the new machine. Ask for a name of its own — for a
  WSL distribution `<windows-hostname>-wsl-<distribution>`
  (`rules/server-memory.md`) — and give that name a block with
  the shared name as `HostName`:

  ```
  Host win1-wsl-ubuntu
    HostName win1.example.com
    Port 2222
  ```

  That name is its memory directory, its `memory/user.md` entry
  and its `Reached as:` destination. The key is still looked up
  as `[win1.example.com]:2222`.
- **A new name that detection finds to be a WSL distribution:**
  its directory is `<windows-hostname>-wsl-<distribution>`, not
  the name. Move the port from the name's block to a block of
  that directory's name, as above, with the `memory/user.md`
  entry, before step 6 writes `Reached as:`.

## Finding the Port

A new host — no `memory/servers/<host>/` yet — for which `ssh -G`
shows port 22, and whose first call fails without an answer from
sshd. A known host never comes here: a port that stops answering
is `rules/ssh-unreachable.md`'s.

A session that ended before it could undo its block leaves the
change uncommitted, and `bin/hostwarden-sync pull` names it
(`rules/parallel-sessions.md` → Changes a session left behind).
Where the change sets a port for a host with no memory yet, say
so when showing it: no session confirmed that port.

Hostwarden tries a port only on evidence: a key known_hosts holds
for it, the user's own list, the user's answer. It never scans
(`nc -z`, `nmap`, `ssh-keyscan`): several ports in a row on one
host look like a port scan to psad, portsentry and a provider's
IPS, and each connection that does not log in counts for fail2ban
(`rules/ssh-connections.md` → Avoid failed logins). The one
`ssh-keyscan` Hostwarden runs is on a server against its own
sshd, to read the host certificate it presents
(`rules/ssh-ca.md` → Host Certificate).

First read which host the error names. Behind a jump host,
`connect to host jump.example.com port 22: Connection refused` is
the jump host's: `rules/ssh-unreachable.md`, nothing here. The
target's refusal arrives as `channel 0: open failed: connect
failed: Connection refused`.

- **`Connection refused`:** the host is up and rejects port 22:
  nothing listens there, or a firewall or a fail2ban ban refuses
  it. A `No route to host` that comes back at once is the same: a
  firewall rejecting the port, as firewalld and a default
  iptables `REJECT` rule answer. Steps 1, 2 and 3.
- **A timeout, or a `No route to host` that takes seconds:** the
  host is down, or a filter drops the packets, possibly one
  Hostwarden's own connections tripped. It says nothing about the
  port, so Hostwarden tries no other one on its own and asks
  nothing about ports. Follow `rules/ssh-unreachable.md`. Tell the user
  which ports step 1 found, if any; a port they then name is
  tried as A Port the User Names says, no sooner than that file's
  wait allows.
- **A login, `Permission denied`, `Host key verification
  failed`:** sshd answers on 22, and nothing here applies.
- **Anything else**, such as `Connection reset` or a closed
  banner exchange: `rules/ssh-unreachable.md`, and nothing here.

### 1. Look in known_hosts, without a connection

Look for the ports of `Alternative SSH ports:` in
`memory/user.md` (`rules/ssh-user.md`) and for 2222, under the
name `rules/host-keys.md` → Before the First Connection looks the
host up by, in `memory/known_hosts` and in each of the user's own
files that its Getting a Key source 2 names; the example shows the
first default of those. One call:

```bash
for p in 52222 2222; do
  ssh-keygen -F "[web1.example.com]:$p" -f "/srv/hostwarden/memory/known_hosts"
  ssh-keygen -F "[web1.example.com]:$p" -f ~/.ssh/known_hosts
done 2>/dev/null | grep -E '^# Host .* found: line [0-9]+ *$'
```

Each line it prints names a port, hashed entries included. The
filter drops a match through a `@cert-authority` or `@revoked`
line, which ssh-keygen marks `CA` or `REVOKED`: a pattern such as
`*` matches every port and says nothing about this one. Step 2
tries these ports first.

### 2. Try the ports

Step 1's ports first, then those of `Alternative SSH ports:` in
their order: each port once, at most three in all. Each try is one
call that runs nothing, as the user `rules/first-connection.md`
step 3 chose, never as root in its place:

```bash
ssh -F "/srv/hostwarden/memory/ssh_config" -p 52222 alice@web1.example.com true
```

- **`Connection refused`, or a `No route to host` at once:** the
  next port.
- **`Host key verification failed`, `Permission denied` or a
  login:** an SSH server answers on that port. It may be another
  SSH service on the same address, such as a container's or a Git
  server's, and a key in known_hosts from a `git clone` looks the
  same. Ask as `rules/ssh-user.md` → Interview format says,
  *"An SSH server answers on port `<port>` of `<host>`. Is it the
  host's own sshd?"*, with `yes, use it`, `no, another service`
  and `stop`. Yes: Recording It below. No: the next port.
- **Anything else**, a timeout, a slow `No route to host`, a
  reset or a failed banner exchange: stop trying, and go on as
  for the same answer on port 22 above.

### 3. Ask

As `rules/ssh-user.md` → Interview format says: *"Port 22 on
`<host>` refused the connection. Which SSH port should Hostwarden
use?"*

1. the first alternative port not tried yet — "from your
   alternative ports"
2. `2222` — "a common alternative"
3. `Other…` — "type a port"

Leave out an option whose port was already tried or that repeats
another; with both gone, ask for the port as plain text. Try the
answer once with step 2's call. Where an SSH server answers on
a port the user typed, Recording It; on option 1 or 2, step 2's
question first: the list names ports the user runs sshd on
somewhere, not on this host. Where none does,
tell the user what the port answered and try nothing more until
they name another.

### Recording It

The port goes into `memory/ssh_hosts` as A Port the User Names
says for a new host. Then run step 4 of
`rules/first-connection.md` again with it: the same address on
that port can be a known host (`rules/dns-aliases.md`), and the
key is looked up as `[<name>]:<port>` (`rules/host-keys.md`). An
answer the user gave to Getting a Key's question for this host
still holds; do not ask it again.

Where the port is not yet in `Alternative SSH ports:`, ask once
more, on its own: *"Also try `<port>` on new hosts whose port 22
refuses?"* (yes / no). A yes appends it to that line in
`memory/user.md`, and writes the line where there is none.

## Jump Hosts

ssh hands `-F` on to the `ProxyJump` hop, so the jump host reads
the same file: its key is checked against `memory/known_hosts`
(`rules/host-keys.md` → Jump Hosts), and it keeps a shared
connection of its own, so only the first call pays for two logins.
Options given with `-o` reach the target alone. A `ProxyCommand`
in the user's own configuration gets no `-F`: an ssh it starts
reads the user's own files, or those its command names. A jump
host on the blacklist blocks every host behind it, whichever of
the two reaches it (`rules/access-control.md` → Server Blacklist).

## Port Forwardings

Never in `memory/ssh_hosts` or any other file. A forwarding in a
shared file would open a port on every machine that shares it at every
connection, held by a master that outlives the need. A session
that needs one adds it to its shared connection, which an earlier
call has opened, and takes it away with the same arguments when
it is done:

```bash
ssh -F "/srv/hostwarden/memory/ssh_config" -O forward \
  -L 127.0.0.1:8443:127.0.0.1:443 alice@web1.example.com
ssh -F "/srv/hostwarden/memory/ssh_config" -O cancel \
  -L 127.0.0.1:8443:127.0.0.1:443 alice@web1.example.com
```

- **Name the shared connection's own user:** its socket is kept
  per user, so another user's `-O` finds no connection.
- **Bind to `127.0.0.1`,** never to every address: other machines
  on the network would reach the host through the workstation.
- **Cancel it, never close the master for it:** other sessions'
  calls ride the same master (`rules/ssh-connections.md` →
  Caveats).
- **A remote forwarding (`-R`) opens the workstation to the
  host:** ask first.
