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
  limited to five keywords. Shared in team mode
  (`rules/server-memory.md` → Personal versus shared).
- **`~/.ssh/config`:** the user's own. It still applies to every
  call, for what the two above leave open. Hostwarden never
  writes it.

## What memory/ssh_hosts Holds

One keyword and one value per line, indented under its `Host`
line. A comment takes a line of its own:

- **`Host`:** the names the block applies to, the name memory and
  the user use and its FQDN; plain names, or patterns with `*`,
  `?` and `!`.
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
`%` token, a `$` or a leading `-`. In team mode, anyone who can
push to the workspace writes this file, and ssh_config can run
commands on every teammate's workstation; the five keywords
cannot.

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
include: in team mode, offer once to copy its `HostName`, `Port`
and `ProxyJump` into `memory/ssh_hosts`, so teammates reach the
host too. Never copy it unasked.

1. Add the block to `memory/ssh_hosts`. A specific `Host` goes
   above a pattern that also matches it.
2. Run `bin/hostwarden-ssh-config`. Any output names a failing
   line: fix it before going on.
3. Check what ssh will do, without connecting:

   ```bash
   ssh -F "/srv/hostwarden/memory/ssh_config" -G root@db1.example.com |
     grep -E '^(hostname|port|proxyjump|hostkeyalias) '
   ```

4. A new `HostName` or `Port` for a known host changes its
   identity and the name its key is looked up by: IP Verification
   in `rules/dns-aliases.md`, then Before the First Connection in
   `rules/host-keys.md`.
5. Commit it like every workspace file, by its path
   `memory/ssh_hosts` (`rules/parallel-sessions.md` → The
   workspace).

When a host's memory directory is removed, remove its block too,
and run the script again.

## Jump Hosts

ssh hands `-F` on to the `ProxyJump` hop, so the jump host reads
the same file: its key is checked against `memory/known_hosts`
(`rules/host-keys.md` → Jump Hosts), and it keeps a shared
connection of its own, so only the first call pays for two logins.
Options given with `-o` reach the target alone. A jump host on the
blacklist blocks every host behind it (`rules/access-control.md` →
Server Blacklist).

## Port Forwardings

Never in `memory/ssh_hosts` or any other file. A forwarding in a
shared file would open a port on every teammate's machine at every
connection, held by a master that outlives the need. A session
that needs one adds it to its shared connection, which an earlier
call has opened, and takes it away with the same arguments when
it is done:

```bash
ssh -F "/srv/hostwarden/memory/ssh_config" -O forward \
  -L 127.0.0.1:8443:127.0.0.1:443 root@web1.example.com
ssh -F "/srv/hostwarden/memory/ssh_config" -O cancel \
  -L 127.0.0.1:8443:127.0.0.1:443 root@web1.example.com
```

- **Bind to `127.0.0.1`,** never to every address: other machines
  on the network would reach the host through the workstation.
- **Cancel it, never close the master for it:** other sessions'
  calls ride the same master (`rules/ssh-connections.md` →
  Caveats).
- **A remote forwarding (`-R`) opens the workstation to the
  host:** ask first.
