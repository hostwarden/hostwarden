---
sidebar_position: 1
description: Routine health inspection covering disk, updates,
  services, hardware, and more.
---

# Housekeeping checks

Run routine health inspections on any server.

```
 ❯ Run housekeeping on app.example.com
```

Problems come first in a short report.

## What it checks

### The basics

Disk, memory and swap (zram and zswap included, the ZFS ARC
counted as available), load, pending updates, the firewall, TLS
certificates, failed services, the network, log anomalies, a
kernel waiting for a reboot, a service still running an old
binary, the timezone and the persistent journal.

### The baseline

Automatic security updates, time sync, the SSH host certificate,
backups, storage maintenance. See
[Server baseline](baseline.md).

### Hardware

SMART and `smartd`, USB devices with an unwatched UPS flagged, CPU
microcode on bare-metal x86, and the BMC event log.

### Services

Container engines (Docker, Podman, containerd), mesh VPN agents
that are down or whose login is about to expire, Home Assistant on
an ordinary host, Pi-hole, AdGuard Home, CasaOS, and the services
the host's memory names.

### Hosts and guests

The guests of a hypervisor and what it passes through to them, the
Proxmox VE baseline template's age, and files Hostwarden deployed
that changed on either side.

### Releases

An Ubuntu LTS past standard support, fixes waiting on Ubuntu Pro.

### macOS

Failed launchd jobs, kernel panics and local Time Machine
snapshots.

## Coverage and limits

It covers Linux (Debian, Ubuntu, RHEL, Fedora, SUSE, Alpine),
FreeBSD, macOS and Windows Server. In a container, clock and
kernel findings belong to the host and are not reported twice.
Nothing is updated, pruned or restarted. Your own checks go into
`memory/housekeeping.md`. A scheduled run can mail you the report
([Scheduled housekeeping](../../running-it/unattended/scheduled.md)).

## What the report looks like

```
## Housekeeping Report: app.example.com

Date: 2026-09-26 06:17
OS: Debian 12 (Bookworm) | Last boot: 14 days ago

### Issues

CRITICAL  Disk / at 97%
WARN      12 security updates pending
WARN      SSL cert expires in 12 days

### Services

PostgreSQL    OK — 4 databases, 2.1 GB total
nginx         OK — config valid
Backups       OK — latest 6 hours ago

### System

Disk       / 97% (1.75 TB / 1.8 TB)
Memory     8.2 GB / 64 GB available
Swap       zram 1.2 / 8 GB (zstd, 3.1:1), disk 0 / 4 GB, zswap off
Load       0.42 / 0.38 / 0.35 (4 cores)
Firewall   ufw active, deny incoming
NTP        synchronized
Kernel     6.1.0-31 (matches installed — no reboot
           needed)
Updates    12 pending, all security
Auto-updates  unattended-upgrades active
```

The issues section only appears when problems exist, sorted by
severity. A finding a decision settles shows as
`DECIDED — <heading> (<who>, <date>)` on its line instead of a
severity — see [Decisions](../../memory/decisions.md).
