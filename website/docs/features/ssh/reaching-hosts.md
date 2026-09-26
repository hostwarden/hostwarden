---
sidebar_position: 3
description: Configures SSH options, jump hosts, and alternative
  ports for each server.
---

# Reaching a host

Every SSH call passes one file, `memory/ssh_config`, which
Hostwarden writes for your machine at every session start. Your
own `~/.ssh/config` keeps working: it is read after Hostwarden's
settings, for whatever they leave open, such as a key file or your
user name on a host.

## Non-standard hosts

A server that answers on another port, only through a jump host,
or at an address its name does not resolve to goes into
`memory/ssh_hosts`, in ssh_config syntax:

```
Host db1 db1.example.com
  HostName 192.0.2.30
  Port 2222
  ProxyJump jump.example.com
```

Only `Host`, `HostName`, `Port`, `ProxyJump` and `HostKeyAlias` are
accepted, with plain values. In a team the file is shared, and
those five cannot run a command on a teammate's machine; a file
with any other line or value is left out whole until it is fixed.
SSH usernames stay in `memory/user.md`, which is personal.

## Jump hosts

Every jump host goes through the blacklist as the user it logs in
as, and gets the same host-key check and shared connection as the
server behind it. A `ProxyCommand` whose path Hostwarden cannot
read is treated as a listed hop: it asks you, each session,
whether it passes a blacklisted host.

## Ports

A non-standard port is recorded, and a refused connection tries a
short, bounded list before it asks:

- **A port given with the host is recorded.**
  `web1.example.com:2222`, `ssh://alice@web1.example.com:2222` or
  `-p 2222` becomes such a block, unless your own ssh configuration
  already has it.
- **A known name on a new port asks first.** It brings the question
  whether sshd moved or another machine answers there.
- **A refused port 22 tries a short list.** Hostwarden tries the
  ports you list as `Alternative SSH ports:` in `memory/user.md`,
  and 2222 where your known_hosts has a key for it, those with a
  key first, three at most; then it asks.
- **It never scans.** After a timeout it tries no other port on its
  own.

## Port forwarding

Port forwardings are never stored. A session that needs one adds
it to the shared connection, bound to `127.0.0.1`, and cancels it
when done; a remote forwarding is asked first.
