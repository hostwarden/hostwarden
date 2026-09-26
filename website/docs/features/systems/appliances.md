---
sidebar_position: 2
description: Special handling for appliances that run their own
  updater, configuration, and firewall.
---

# Appliances

An appliance runs its own updater, configuration and firewall,
often on top of an OS family, so it gets a file of its own that
replaces what the family file would get wrong.

## The appliance table

| Appliance         | Base    | Appliance file                      |
| ----------------- | ------- | ----------------------------------- |
| Proxmox VE        | Debian  | `rules/appliance/proxmox-ve.md`     |
| OpenMediaVault    | Debian  | `rules/appliance/openmediavault.md` |
| OPNsense          | FreeBSD | `rules/appliance/opnsense.md`       |
| pfSense           | FreeBSD | `rules/appliance/pfsense.md`        |
| TrueNAS           | Debian  | `rules/appliance/truenas.md`        |
| TrueNAS CORE      | FreeBSD | `rules/appliance/truenas-core.md`   |
| XCP-ng            | RHEL    | `rules/appliance/xcp-ng.md`         |
| Home Assistant OS | —       | `rules/appliance/haos.md`           |
| Synology DSM      | —       | `rules/appliance/synology-dsm.md`   |
| UGREEN UGOS Pro   | —       | `rules/appliance/ugos.md`           |
| UniFi OS          | —       | `rules/appliance/unifi-os.md`       |
| Unraid            | —       | `rules/appliance/unraid.md`         |
| OpenWrt           | —       | `rules/appliance/openwrt.md`        |
| ZimaOS            | —       | `rules/appliance/zimaos.md`         |
| QNAP QTS, hero    | —       | `rules/appliance/qnap.md`           |

Each file says how the appliance updates, where its settings live
— mostly in its web UI or its own tools — which firewall it runs
and where it logs.

- **Some files name the releases they cover** (Synology DSM, QNAP,
  Unraid, UGOS Pro, ZimaOS); Hostwarden stops on any other release
  before changing anything. UniFi OS works read-only there.
- **TrueNAS CORE is covered far enough to report it as end of
  life.**
- **The fleet audit compares an appliance only with its own kind.**
- **Some appliances run on their vendor's hardware.** Synology DSM,
  QNAP, UGOS Pro and UniFi OS do, and `hostwarden-os-install` never
  writes to it.

## Appliance APIs

Unraid, TrueNAS, Synology DSM and UniFi Network are read through
their local APIs, each with its own read-only account: an Unraid
`VIEWER` key, a TrueNAS Readonly Admin, a DSM user for the VM guest
list, a UniFi View Only user.

- **A write account exists only if you ask for it**, and is used
  only for a change you approved.
- **You create each account and fill its credential file** (mode
  0600); Hostwarden names the file and passes it to `curl` on
  stdin.
- **A call from your workstation pins the certificate's public
  key** you confirmed, and an API that answers only on plain HTTP
  is refused.
- **Hostwarden never tries a write** to prove that a read-only
  account cannot write.
