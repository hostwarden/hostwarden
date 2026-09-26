---
sidebar_position: 2
description: A first session from start to finish — onboarding a host,
  what gets written where, and a first change with its approval.
---

# Your first session

A walk through what you see and what Hostwarden writes, from the first
start to a first change. The host names are examples; the report and
file layouts are the ones Hostwarden produces. Installing comes first:
[Installing Hostwarden](install.md).

## 1. Start it

```
git clone https://github.com/hostwarden/hostwarden.git
cd hostwarden
bin/hostwarden-init
claude
```

`bin/hostwarden-init` turns `memory/` into the workspace, which makes
this checkout the one that administers your servers. In a terminal it
asks whether to share the workspace through a private git remote
([A shared workspace](../running-it/team/shared-workspace.md)); where
you leave that for later, the first session asks. The session opens
with one line:

```
Fresh Hostwarden install detected — nothing in memory yet.
Ready when you are.
```

## 2. Onboard a first host

```
 ❯ Onboard web1.example.com
```

The first connection asks what it cannot find out by itself, once:

- **Which SSH user** to log in as, offered as a short list. The answer
  goes into `memory/user.md`, which stays on your machine.
- **The host key**, when neither a verified host nor your own
  `known_hosts` has it: accept it on first use, compare it with the
  fingerprint you read at the console, or stop
  ([Host keys](../features/ssh/host-keys.md)).

Then it probes the host in full — OS, hardware, network, services,
accounts, backup, storage — and changes nothing on it except one
read-only line in its journal. The report:

```
Onboarded 1 host, read-only
web1.example.com — Debian 13
  baseline: missing automatic security updates, backup
  gateway 192.0.2.1 is not in Hostwarden — onboarding it
  (read-only, SSH) gives the full picture of ranges and VLANs
Written: memory.md and a read-only journal line for each onboarded
  host, network.md for web1, the workspace committed
Nothing on the servers was changed.
Housekeeping keeps health and settings current, the fleet audit
  the drift between hosts; neither runs by itself.
```

It then asks which gaps to take on first, or whether to schedule
housekeeping. "Not now" is always an option.

## 3. What is now in the workspace

```
memory/
├── user.md                         your SSH user, never shared
├── known_hosts                     web1's host key, with a note how
│                                   it was obtained
└── machines/
    └── web1.example.com/
        ├── memory.md               what the host is
        ├── network.md              its network profile
        └── changelog.log           the session's entry
```

`memory.md` is short on purpose:

```markdown
# web1.example.com
- IP: 192.0.2.21
- SSH port: 22
- FQDN: web1.example.com
- OS: Debian 13 (Trixie)
- Distro family: debian
- Role: server (inferred)
- Shell: bash (root)
- CPU: 2x Intel Xeon E-2236 @ 3.40GHz
- Arch: x86_64, Intel
- RAM: 4 GB
- Disk: 40 GB (/ ext4, 31% used)
- Virtualization: kvm (VM)
- Web server: nginx
- Network: dual-stack, v6 egress OK — see network.md
- Onboarded: 2026-09-26
- Last connected: 2026-09-26
```

On the server itself, the journal now holds:

```
$ journalctl -t hostwarden
Sep 26 10:14 web1 hostwarden[4711]: [alice as root] read-only:
  onboarded — the server's details recorded and checked against the
  server baseline, nothing changed
```

[A host's memory](../memory/host-memory.md) explains every file a
host can get, and [Journal and changelog](../memory/journal.md) the
two logs.

## 4. Make a change

```
 ❯ Turn on automatic security updates on web1
```

Hostwarden reads `memory.md` and the journal of the last seven days
first, so it knows what the host is and whether someone else worked on
it. Then it proposes each command with what it does and why, and waits.
Before it edits a configuration file it copies it to
`/var/backups/hostwarden/`, and where a tool has a dry run, it uses
that first.

Once the change is made, two records are written:

- **On the server**, one sentence for your colleagues:
  `[alice as root] web1.example.com now installs security updates
  automatically — because the server baseline expects it`.
- **In your workspace**, the same headline with the detail: which files
  changed, how it was verified, and how to undo it. `memory.md` gets
  the new fact, and the workspace commit carries the headline as its
  message.

## 5. Next week

```
 ❯ Check on web1.example.com
```

A new session starts from what is on record: the host's memory, its
open to-do items, your decisions for it, and what the journal says
happened since. When a colleague or another of your sessions worked on
the host in between, you are told before anything runs.

## Where to go from here

- Everything it can do, with example prompts:
  [Features](../features/index.md).
- What it asks before, and what it never does:
  [Safety](../safety/index.md).
- A team, several machines, a nightly run:
  [Running Hostwarden](../running-it/index.md).
