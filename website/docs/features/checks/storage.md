---
sidebar_position: 4
description: Tracks disks by serial and rates ZFS and btrfs
  settings.
---

# Disks, ZFS and btrfs

Hostwarden tracks storage down to the disk serial and rates the
settings that decide how ZFS and btrfs behave.

## Tracking disks

On bare metal, and in a VM for the disks passed through to it,
housekeeping records each disk once — type, bus, size, model,
serial and firmware — in `memory/machines/<host>/storage.md`, so a
failing disk is known by the serial you replace it by. It reads
SMART there and on the appliances whose file asks for it, and says
when a disk appears, disappears, or its error counts grow, and
says "not checked" rather than "healthy" where `smartctl` is
missing.

## Scheduled maintenance

TRIM on flash, RAID array checks, ZFS and btrfs scrubs and
`smartd` are part of the [server baseline](baseline.md): what a
distribution schedules by itself differs — Alpine schedules none,
openSUSE only scrubs `/` — so housekeeping reports what is missing
and bringing a server up to the baseline turns it on. A new VM
gets its TRIM schedule at creation; nothing is set up on an
appliance that schedules this itself.

## ZFS and btrfs settings

On a host with ZFS pools or btrfs, Hostwarden also records the
settings that decide how the storage behaves — layout,
compatibility, dataset and pool properties set by hand, encryption
roots, ARC limits, btrfs profiles and quotas — and rereads them on
every run.

- **It rates what it finds** — `sync=disabled` on data that
  matters, dedup without the RAM for it, autotrim off on flash, an
  ARC that crowds out a hypervisor's guests, and more.
- **A pool feature is reported, never enabled.** A feature
  `zpool upgrade` would turn on is only reported, since that step
  cannot be undone.
- **A settled reason stops the question.** Tell it why a setting is
  the way it is, and it stops asking.

## When storage fails

When storage fails, Hostwarden reads, asks about your backup, and
hands the repair command to you: repairing or destroying a file
system, array, volume group or pool is one of its taboos
([Hard guardrails](../../safety/guardrails.md)).
