---
sidebar_position: 3
title: A host's memory
description: What memory.md, guests.md, storage.md and network.md look
  like for a real-world host, and who writes each line.
---

# A host's memory

Each host has a directory `memory/machines/<hostname>/`. Its heart is
`memory.md`: what the host is, in about thirty lines. Next to it,
larger inventories get files of their own. The examples on this page
are fictional hosts, in the exact form Hostwarden writes.

## `memory.md`

```markdown
# pve1.example.com
- IP: 192.0.2.5
- SSH port: 22
- FQDN: pve1.example.com
- OS: Debian 13 (Trixie)
- Distro family: debian
- Appliance: Proxmox VE 9.0.3, standalone
- Role: server (inferred)
- Shell: bash (root)
- CPU: 8x AMD Ryzen 7 PRO 5750GE
- Arch: x86_64, AMD
- RAM: 64 GB
- Disk: 1 TB (/ zfs, 12% used)
- Virtualization: none (bare metal)
- Site: home (user)
- Network: dual-stack, v6 egress OK — see network.md
- Storage: disks; ZFS rpool (storage.md)
- Management: iDRAC (BMC), reachable from the host
- Accounts: local (team roster, certificates), sudo %sudo
- Time sync: chrony
- Depends on: nas1.example.com (NFS /srv/data), dns1.example.com
  (resolver)
- Auto restarts: reboot when needed, 06:00–07:00
- Backup: restic to backup1.example.com, verified 2026-09-24
- Baseline check: 2026-09-24, complete
- Onboarded: 2026-09-20
- Housekeeping: 2026-09-24
- Last connected: 2026-09-26
- Flags: vmbr1 carries the router guest's WAN; never restart
  networking without the console open (2026-09-21 18:02)
```

How to read it:

- **One owner per line.** Every line has exactly one rule or skill that
  writes it and says when it changes; everything else only reads it.
  `OS:` is refreshed on every connection, `Backup:` by housekeeping,
  `Site:` is your answer to a question asked once.
- **Lines join when their moment comes.** A host without a backup
  question answered has no `Backup:` line yet, and most hosts never get
  most of the possible lines.
- **`(user)` marks your word.** A line that records your answer rather
  than something Hostwarden measured says so; a line it only inferred
  says `(inferred)`.
- **Dates tell the age.** `Onboarded:` and `Housekeeping:` date the
  last full probe; lines they refresh are stale after 90 days.
- **Standing lines come last.** A `Flags:` line is a constraint later
  work must respect, a `Rollback:` line the way back from a change that
  stays in place. Each carries the timestamp of its changelog entry,
  where the full story is ([Journal and changelog](journal.md)).

It is kept compact: outdated entries are removed and related ones
merged when a change is recorded, never left to pile up.

## `guests.md`

On a hypervisor, every guest — stopped ones and templates included —
with how Hostwarden linked it to the guest's own memory:

```markdown
# Guests on pve1.example.com

- Inventoried: 2026-09-22

- 101 web1 (VM): running, autostart. Debian 13 (agent),
  192.0.2.21. mac bc:24:11:00:01:01,
  uuid 6f1c2a3e-0000-4000-8000-000000000101
  → web1.example.com
- 102 db1 (container): running, autostart. 192.0.2.22.
  mac bc:24:11:00:01:02 → probably db1.example.com
- 110 mail-old (VM): stopped. Retired, keep until 2026-12-31
  (user, 2026-09-22). mac bc:24:11:00:01:10
- 9000 debian13-tpl (VM): template (hypervisor).
```

The guest's own `memory.md` points back:

```markdown
- Guest identity: mac bc:24:11:00:01:01,
  uuid 6f1c2a3e-0000-4000-8000-000000000101
- Runs on: pve1.example.com (VM 101)
```

The link comes from what both sides see — MAC addresses, and for KVM
VMs the UUID — never from a name alone. Why a stopped guest is off is
asked once and kept, so `mail-old` does not come up again
([Hypervisors and their guests](../features/guests/hypervisors.md)).

## `storage.md`

On bare metal, and on any host with ZFS or btrfs: each disk once, by
the serial you would replace it by, and the settings that decide how
the storage behaves.

```markdown
# Storage on nas1.example.com

- Inventoried: 2026-09-23
- ARC: max 8 GiB (/etc/modprobe.d/zfs.conf), min default;
  RAM 32 GiB

## Disks
- nvme0n1: NVMe, 1 TB, Samsung SSD 990 PRO 1TB, serial
  S7XXNJ0W000001, fw 4B2QJXD7
- sda: HDD, SATA, 8 TB, WDC WD80EFZZ-68BTXN0, serial
  WD-CA0000001, fw 81.00A81; reallocated 8 (2026-09-23)

## ZFS pool tank
- Layout: raidz2 × 6; special mirror × 2; logs mirror × 2;
  cache × 1; ashift 12 (all vdevs)
- Size 43.6T; autotrim off; compatibility off
- Features: 3 not enabled
- Set here: compression=lz4, atime=off (tank);
  recordsize=1M (tank/media); sync=disabled (tank/scratch,
  scratch data: user, 2026-09-23)
- Zvols: 12, volblocksize 16K
- Encrypted: tank/private (aes-256-gcm, passphrase, key
  prompt)
```

Housekeeping rereads it on every run and says when a disk appears,
disappears or its error counts grow — here, the eight reallocated
sectors on `sda` are the baseline the next run compares against
([Disks, ZFS and btrfs](../features/checks/storage.md)).

## `network.md`

The network profile: who manages the configuration, which stack runs,
whether DNS agrees, and — on a host that forwards or bridges guests —
which way traffic flows. `memory.md` carries a one-line summary and
points here.

```markdown
# Network — host.example.com
Probed: 2026-09-19

## Summary
- Stack: dual-stack (v4 public, v6 GUA)
- Egress: v4 OK, v6 OK (deb.debian.org)

## Management
- Manager: netplan → systemd-networkd
- Source: /etc/netplan/50-cloud-init.yaml
- cloud-init: owns network config
- Hooks: none
- Conflicts: none

## Interfaces
- Uplink: eth0, MTU 1500, physical
- Overlay: wg0 · Container interfaces: 3

## IPv4
- 203.0.113.10/32 static, public
- Default: via 192.0.2.1 dev eth0, MAC 00:00:5e:00:53:01

## IPv6
- 2001:db8:1:2::1/64 static, GUA
- Default: via fe80::1 dev eth0, static, MAC 00:00:5e:00:53:01
- RA: networkd (userspace), kernel accept_ra 0
- Forwarding: 0 · Temporary addrs: none

## DNS
- resolv.conf: symlink → systemd-resolved stub
- Upstream: 2 v4 + 1 v6 on eth0, link-provided
- Own name: hostname -f resolves to itself
- mDNS responder: none

## Public DNS (from workstation)
- A: matches · AAAA: matches
- PTR v4: host.example.com, forward-confirmed
- PTR v6: missing

## Findings
- INFO: no PTR for 2001:db8:1:2::1
```

A traffic-flow section — bridges, NAT, policy routing — is added where
the host has them, and is read before any NAT or bridge change
([A host's network](../features/hosts/network.md)).

## The other files

- **`changelog.log`** — every change, with detail and rollback:
  [Journal and changelog](journal.md).
- **`todo.md`** — an interrupted session's open steps:
  [To-do lists and plans](todo-and-plans.md).
- **`decisions.md`** — your standing choices for this host:
  [Decisions](decisions.md).
- **`rules.md`** — overrides for this host alone:
  [Overrides](../running-it/tailoring/overrides.md).
- **`deployed.md`, `files/`** — files Hostwarden wrote onto the host
  and their masters:
  [Files Hostwarden deploys](../features/changes/deployed-files.md).
- **`notes/`** — evidence a session kept, such as a list of files
  quarantined before a cleanup, named with its date. The changelog
  entry that produced it names the file.

## How it is used

Next week, in a new session:

```
 ❯ Check on pve1.example.com.
```

Hostwarden reads `memory/machines/pve1.example.com/memory.md`, the
host's open to-do items, your decisions for it, and the local
changelog, before it sends a single command. The answer to "what goes
down if pve1 reboots?" comes from `guests.md` and the `Depends on:`
lines of other hosts alone, without connecting anywhere
([What a reboot would hit](../features/fleet/impact.md)).
