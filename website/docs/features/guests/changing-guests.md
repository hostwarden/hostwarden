---
sidebar_position: 2
description: Prefers a snapshot before a risky change, and asks
  before stopping or deleting a guest.
---

# Changing a guest

Restarting a guest counts as a reboot and is asked. Before a risky
change inside a guest, a snapshot is preferred to a file backup,
on Proxmox VE, Incus, LXD, libvirt, iocage, Bastille and ZFS; what
the snapshot leaves out, such as bind mounts and passed-through
devices, is named first. Stopping or deleting a guest needs your
explicit request and shows its disks and newest backup first; the
guard behind it is the same as for a system container or VM
([Hard guardrails](../../safety/guardrails.md)). Housekeeping
lists what a host passes through to its guests and flags a bind
mount whose source fell back to the root filesystem.
