---
name: hostwarden-os-install
argument-hint: "[hostname]"
description: Install, replace, or dual-boot an operating system on a
  managed machine, including the disk and EFI work that comes with
  it — wipe-and-reinstall, adding a second OS beside an existing
  one, deploying from a cloud image (qcow2, raw, VMDK), freeing a
  partition on a live system, and managing EFI boot entries and
  boot order. Use when the user asks to "replace the OS on
  <host>", "reinstall this server", "migrate from CentOS to
  Debian", "set up dual-boot", "install FreeBSD next to Linux",
  "deploy this cloud image", "repartition the disk", "der Server
  soll ein anderes Betriebssystem bekommen", or asks about boot
  entries, BootOrder, or a machine that no longer boots after an
  install. Destructive and irreversible in most of its paths —
  needs an explicit request, a confirmed backup, and the operator
  to relaunch with the taboo guard disabled.
---

# OS Installation, Replacement and Boot Management

Five workflows that share one disk, one boot loader and one
irreversible moment. Read the gate below first, then the reference
that matches what the user asked for.

## The gate — before anything touches a disk

Every path here is destructive. None of them starts until all four
hold:

1. **The user asked for it in this session.** Not inferred from a
   full disk, a broken boot, or an old release. This skill is never
   the answer to "why is this machine slow".
2. **The user understands what is lost.** Say it plainly: which
   disk, which data, and that it does not come back. For a VM,
   offer a snapshot first.
3. **A backup exists and was verified**, not merely claimed. See
   `rules/backups.md`.
4. **The taboo guard is off for this session.** The shipped
   PreToolUse hook blocks `mkfs`, every partition-table writer and
   `dd` onto a raw device — exactly what these workflows run by
   design. The operator relaunches with `HOSTWARDEN_GUARD_DISABLE=1`
   in the environment; an inline assignment on the command line
   does not work and is itself blocked. Ask them to unset it again
   when the work is done.

Being blocked by the guard before step 4 is the expected outcome.
Never rephrase a command to get past it.

Code blocks in the references that only run with the guard off
carry `guard-off` on their fence. Blocks marked `operator` are for
the user to type at a console, not for hostwarden to run.

## Which reference

- **Wipe and reinstall, same machine, new OS** →
  `references/os-replacement.md`. The long one: pre-replacement
  inventory, boot configuration safety, installation methods, and
  the two SSH-only paths (hot-migration and tmpfs rescue) for a
  machine nobody can reach physically.
- **A second OS beside the existing one** →
  `references/dual-boot.md`. Partition planning, ZFS root
  repartitioning, filesystem choice, and testing a new OS without
  betting the boot order on it.
- **Boot entries, BootOrder, BootNext, boot loaders, a machine
  that stopped booting** → `references/efi-boot.md`. Also read it
  whenever EFI comes up at all in the other paths.
- **Deploying a qcow2 / raw / VMDK image, cloud-init trouble, a
  fresh VM that will not boot or take SSH** →
  `references/cloud-image.md`.
- **Freeing a partition on a running system, repartitioning
  without physical access, needing scratch space on a disk that is
  in use** → `references/partition-staging.md`.

Read only the ones the task needs. They cross-reference each other
where a path continues.

## Rules that still apply

The pipeline in `rules/first-connection.md` runs before the first
remote command here, like everywhere else. Beyond that:

- `rules/backups.md` — the backup that gate step 3 verifies.
- `rules/secrets.md` — host keys and credentials recovered from
  the old system are secrets; inspect metadata, never contents.
- `rules/<family>.md` — for every OS involved, old and new.
- `rules/server-memory.md` — the host's memory file describes a
  machine that is about to stop existing. Capture the inventory
  before the wipe, and rewrite memory after.
- `rules/changelog.md` — a replacement is the single largest entry
  a host will ever get.

## After

Run the post-replacement checklist in the reference you used, then
verify against the live system before reporting success
(`rules/verify-before-reporting.md`). A machine that answers SSH is
not yet a machine that survives a reboot.
