---
sidebar_position: 2
description: Every file and directory in memory/, what each holds, and
  which stay personal in a shared workspace.
---

# The workspace

`memory/` is the workspace: everything Hostwarden knows about your
servers and everything you told it, as text files in a git repository
of its own. `bin/hostwarden-init` creates it. Hostwarden's own files
are replaced on every update; the workspace is never touched by one.

## Layout

```
memory/
├── README.md             generated overview, read it first
├── user.md               your SSH users, language, handle   personal
├── blacklist.md          hosts never to connect to          personal
├── readonly.md           hosts to inspect, never change     personal
├── ssh_config            written each session start         personal
├── opencode.json         your OpenCode config               personal
├── operators.md          the handles in use in a team
├── known_hosts           your servers' SSH host keys
├── ssh_hosts             other ports, addresses, jump hosts
├── service-policy.md     auto-reload and restart per service
├── housekeeping.md       your own housekeeping checks
├── network.md            facts that belong to no one host
├── topology.md           sites, ranges, gateways, links
├── dns.md                the fleet's DNS name spaces
├── naming.md             your naming scheme
├── custom-rules/         your overrides
├── decisions/            decisions about a group, or all hosts
├── plans/                work that spans sessions
├── maps/                 generated Mermaid maps
├── fleet/                files deployed to several hosts
├── tools/                scripts for your own machine
├── clusters/<name>/      a cluster: members, guests, decisions
└── machines/<host>/     one directory per host
    ├── memory.md
    ├── changelog.log
    ├── network.md
    ├── guests.md         on a hypervisor
    ├── storage.md        on bare metal, ZFS or btrfs
    ├── todo.md           while a session's steps are open
    ├── decisions.md
    ├── rules.md          overrides for this host
    ├── deployed.md       files Hostwarden deployed, with hashes
    ├── files/            their masters, at their path on the host
    └── notes/            evidence kept, named with its date
```

Most files appear only once there is something to put in them; a host
that never had a guest has no `guests.md`. The tree is text and
typically well under a megabyte, so a backup is one `tar` command
([Backup and restore](../running-it/setup/backup.md)).

## What each file is for

### You and your access

- **`user.md`** — SSH usernames, the SSH ports you use instead of 22
  (`Alternative SSH ports:`), your language, your handle
  (`Operator:`), your full name for email signatures
  (`Operator name:`), `Coordinator: off` where you turned it off, and
  `Multi-host: agents` where you want work on several hosts in
  subagents
  ([One task on many hosts](../features/fleet/multi-host.md)).
- **`blacklist.md`, `readonly.md`** — the access lists
  ([Access control](../safety/access.md)).
- **`operators.md`** — the handles in use, and which are inactive or
  an operations host's ([A shared workspace](../running-it/team/shared-workspace.md)).
- **`service-policy.md`** — per service, whether a reload or restart
  may proceed on its own ([What it asks first](../safety/approvals.md)).

### Reaching hosts

- **`known_hosts`** — the host keys of your servers, each with a note
  on how it was obtained ([Host keys](../features/ssh/host-keys.md)).
- **`ssh_hosts`** — hosts on another port, behind a jump host, or at
  an address their name does not resolve to
  ([Reaching a host](../features/ssh/reaching-hosts.md)).
- **`ssh_config`** — written from `ssh_hosts` for this machine at
  every session start. Never edit it.

### What Hostwarden learned

- **`machines/<host>/`** — one directory per host:
  [A host's memory](host-memory.md). A DNS alias of a host is a
  symlink to its directory, sharing its memory.
- **`clusters/<name>/`** — a hypervisor cluster or pool: its members,
  HA state, guest inventory and decisions.
- **`network.md`** — facts that belong to no single host: a mesh VPN,
  which machine holds the backup target, which UPS powers what,
  management controller addresses, the SSH CAs the hosts trust.
- **`topology.md`** — the networks the hosts share: sites, ranges,
  gateways and the routes between them. The maps are drawn from it.
- **`dns.md`** — the fleet's DNS name spaces.
- **`maps/`** — [Infrastructure maps](maps.md), generated.
- **`README.md`** — the overview page, generated with the maps: sites,
  open findings, hosts not reached lately
  ([The overview page](maps.md#the-overview-page)).

### What you decided and planned

- **`custom-rules/`** — your overrides
  ([Overrides](../running-it/tailoring/overrides.md)).
- **`decisions/`** and each host's `decisions.md` —
  [Decisions](decisions.md).
- **`plans/`** — [To-do lists and plans](todo-and-plans.md).
- **`housekeeping.md`** — checks of your own that housekeeping adds.
- **`naming.md`** — the naming scheme your hosts follow.

### Files on your servers

- **`machines/<host>/files/`, `fleet/`, `clusters/<name>/files/`** —
  the masters of files Hostwarden wrote onto a server
  ([Files Hostwarden deploys](../features/changes/deployed-files.md)).
- **`tools/`** — scripts for your own machine.

## Personal and shared

Alone, the workspace has no remote. A team, or one person on several
machines, shares it through a private one
([A shared workspace](../running-it/team/shared-workspace.md)). Then
the split matters:

- **Always personal, never shared:** `user.md`, `blacklist.md`,
  `readonly.md`, `ssh_config`, `opencode.json`, and the memory
  directory of anyone's own machine. The workspace's `.gitignore` names
  them; your machine's hostname directory you add there yourself.
- **Shared:** everything else — every host's memory, rules, decisions
  and masters, the clusters, plans, host keys, `ssh_hosts`,
  `operators.md`, the network and topology files, and your overrides.

:::warning Keep the remote private

The workspace holds hostnames, addresses and the layout of your
network. Its remote is never public.

:::
