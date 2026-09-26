---
sidebar_position: 1
description: How Hostwarden detects a host's operating system and
  onboards it into memory.
---

# Onboarding a host

The first connection to any host detects its operating system in
one SSH call and records what it finds. Onboarding does the same
thing in full, up front, rather than piecemeal as work happens to
touch the host.

```
 ❯ onboard web1.example.com
 ❯ nimm web1 in Hostwarden auf
```

## Auto OS-detection

One SSH call covers the common case; a few hosts need more:

- **One call detects a Linux, FreeBSD or macOS host.** It reads
  family and version, architecture, hardware, virtualization, and
  the markers of an appliance, a hypervisor and a platform.
- **The login shell rides along.** It comes back in the same call,
  with one more on a busybox host (Alpine, OpenWrt).
- **The host's memory records what it found**, among them
  `Virtualization:` (bare metal, VM or container, and the cloud
  provider where the firmware names one) and `Arch:`.
- **A menu stops the probe.** A console menu or a banner in place
  of a shell stops it; Hostwarden never answers the menu.
- **Windows takes two calls.** `cmd /c ver`, then PowerShell; only
  Windows Server goes on.
- **An unknown distribution still gets best practice.** A
  distribution without a family file is named, and Hostwarden goes
  on with general best practice.

Later connections send a short version check. A full probe reports
each line that changed, such as a release upgrade.

## Onboarding a host

That first connection happens whenever a host is first needed. To
have it now, ask for it — "onboard web1.example.com", "nimm web1
in Hostwarden auf", or `/hostwarden-onboard web1.example.com` in
Claude Code.

Onboarding probes the host in full, up front, rather than
piecemeal:

- **Memory and network.** It writes the host's memory
  ([A host's memory](../../memory/host-memory.md)) and records its
  network where it can read it.
- **The hypervisor's guests.** On a hypervisor it lists and
  registers them.
- **SSH trust.** It reads the SSH CA setup.
- **Hardware and services.** It records USB devices,
  passed-through devices, disks, accounts, backup, container
  registries and, where it has root, the management controller.
- **A gap report.** It reports what the host lacks against the
  server baseline, or a workstation's expectations where its role
  replaces the baseline.

It changes nothing on the server beyond one read-only line in its
journal, and in the journal of each registered guest that has
`logger`. Then it asks which gaps to take on first; a read-only
host gets a report of the changes instead. Several hosts at once
go hypervisors first. A host it already knows is probed in full
again, and its memory is brought up to date.

A guest that its hypervisor registered finishes its onboarding on
its first own login, read-only, before whatever you asked for. The
report ends with what keeps the record current:
[housekeeping](../checks/housekeeping.md) for health and settings,
the [fleet audit](../checks/fleet-audit.md) for drift between
hosts. Neither runs by itself, so it offers to schedule
housekeeping. What housekeeping records counts as stale after 90
days, and the fleet audit lists stale hosts and those never
onboarded.

## What you get

The run closes with one report block, then a question about which
gap to close first:

```
Onboarded 3 hosts, read-only
pve1.example.com — Proxmox VE 9.0.3, 11 guests: 9 registered
  baseline: missing automatic security updates, backup;
  no baseline template for containers
web1.example.com — Debian 13, known host re-probed, its record
  140 days old:
  OS: Debian 12 in memory, Debian 13 now
  baseline: complete; Management: not settled (needs root)
  gateway 192.0.2.1 is not in Hostwarden — onboarding it
  (read-only, SSH) gives the full picture of ranges and VLANs
db1.example.com — not onboarded: SSH timeout
Written: memory.md and a read-only journal line for each onboarded
  host, network.md for pve1 and web1, guests.md for pve1, the
  workspace committed
Registered guests finish onboarding on their first own login.
Nothing on the servers was changed.
Housekeeping keeps health and settings current, the fleet audit
  the drift between hosts; neither runs by itself.
```

Hostwarden then asks which gaps to take on first.
