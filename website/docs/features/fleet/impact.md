---
sidebar_position: 2
description: Answers from memory what a reboot or restart would
  take down.
---

# What a reboot would hit

Ask before a disruptive step what it takes with it.

```
 ❯ What goes down if pve1 reboots?
 ❯ Wen trifft ein Neustart von unbound auf dns1?
```

Hostwarden answers from memory alone, without connecting anywhere:
the host's guests, the hosts behind it as a jump host, the hosts
that depend on a service it runs, and its cluster peers, each with
its role and services. The answer also says how old the records
are that it relied on, and which hosts were only registered and
never onboarded, since the radius is only as complete as memory.
Onboarding and housekeeping record the NFS or SMB shares a host
mounts and the resolver it uses as its `Depends on:` line; a
database, directory or login service it needs from another host
goes there when you name it.
