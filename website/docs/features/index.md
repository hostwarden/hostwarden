---
sidebar_position: 1
description: An overview of every feature, grouped the way the sidebar is.
---

# Features

What Hostwarden does, with example prompts. A feature that exists
only in Claude Code says so; in other tools the same rules reach
the agent as instructions.

## Knowing your hosts

- [Onboarding a host](hosts/onboarding.md) — detects the OS on
  first connection and builds the host's memory.
- [Names and aliases](hosts/names.md) — recognizes when several
  DNS names point at the same server.
- [A host's network](hosts/network.md) — the network profile,
  VPNs, and out-of-band access recorded for a host.

## Supported systems

- [Supported systems](systems/overview.md) — the OS families,
  appliances, platforms, and roles Hostwarden tells apart.
- [Appliances](systems/appliances.md) — special handling for
  Proxmox VE, OPNsense, Synology DSM, and other appliances.
- [WSL and workstations](systems/workstations.md) — how a WSL
  instance or a workstation is treated differently from a server.
- [Windows Server](systems/windows-server.md) — read-only
  housekeeping and security reporting over OpenSSH.
- [Local administration](systems/local-mode.md) — runs commands
  directly on the machine Hostwarden runs on, without SSH.

## Checking servers

- [Housekeeping checks](checks/housekeeping.md) — routine health
  inspection: disk, updates, services, hardware, and more.
- [Security audit](checks/security-audit.md) — checks SSH
  hardening, firewall posture, accounts, and other settings.
- [Server baseline](checks/baseline.md) — what every server is
  expected to have, and how to bring one up to it.
- [Disks, ZFS and btrfs](checks/storage.md) — tracks disks by
  serial and rates ZFS and btrfs settings.
- [Fleet audit](checks/fleet-audit.md) — compares key policies
  across every server Hostwarden knows about.

## Changing servers

- [Plan mode](changes/plan-mode.md) — plans a complex or
  unfamiliar change before touching anything.
- [Configuration management](changes/config-management.md) —
  works alongside Ansible, Puppet, Chef, and similar tools.
- [Services in containers](changes/containers.md) — changes the
  file that recreates a container, not the running one.
- [Accounts](changes/accounts.md) — creates and removes accounts,
  groups, and sudo rules the way each host manages them.
- [Files Hostwarden deploys](changes/deployed-files.md) — keeps a
  master copy of every script and config file it writes.
- [Renaming a host](changes/rename.md) — finds everywhere the old
  name is used before renaming a host.
- [Language runtimes and deploy users](changes/runtimes.md) —
  installs language runtimes and sets up restricted CI/CD accounts.
- [Email reports](changes/email.md) — sends ad-hoc text or files
  about a managed server by email.

## Many servers

- [One task on many hosts](fleet/multi-host.md) — runs one
  question, check, or change across several servers at once.
- [What a reboot would hit](fleet/impact.md) — answers from
  memory what a reboot or restart would take down.
- [Planning a maintenance window](fleet/maintenance-windows.md) —
  plans a disruptive step ahead, with who to tell and by when.
- [Fleet read](fleet/fleet-read.md) — gives an operations host a
  key limited to read-only checks.

## Guests and hypervisors

- [Hypervisors and their guests](guests/hypervisors.md) — lists
  and reads inside the guests of every hypervisor it manages.
- [Changing a guest](guests/changing-guests.md) — prefers a
  snapshot before a risky change, and asks before stop or delete.
- [New guests](guests/new-guests.md) — creates VMs and containers
  with the server baseline applied at first boot.
- [Installing an operating system](guests/os-install.md) —
  replaces an OS, sets up dual-boot, and manages EFI boot entries.

## SSH access

- [Host keys](ssh/host-keys.md) — checks every server's SSH host
  key against the workspace's known_hosts file.
- [SSH certificates and your CA](ssh/ssh-ca.md) — audits an
  existing SSH CA and uses it wherever it sets up SSH trust.
- [Reaching a host](ssh/reaching-hosts.md) — configures SSH
  options, jump hosts, and alternative ports for each server.

The safety rules behind all of this are in
[Safety at a glance](../safety/index.md). What Hostwarden remembers
between sessions, and how, is in
[How Hostwarden remembers](../memory/index.md).
