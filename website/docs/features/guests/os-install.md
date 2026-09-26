---
sidebar_position: 4
description: Replaces an OS, sets up dual-boot, and manages EFI
  boot entries and boot order.
---

# Installing an operating system

```
 ❯ Replace the OS on web1.example.com with Debian
 ❯ Set up dual-boot with FreeBSD on this machine
```

`hostwarden-os-install` covers replacing an OS, dual-boot, EFI
boot entries and boot order, cloud images and freeing a partition
on a live system. Reading and diagnosing always work.

:::warning
Before any write to a disk, four things must hold: your explicit
request, your understanding of what is lost, a verified backup,
and a session started with the guard switched off
(`HOSTWARDEN_GUARD_DISABLE=1`, Claude Code).
:::

It never writes to an appliance on its vendor's hardware or to a
Mac.
