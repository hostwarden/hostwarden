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

## Reading is always allowed

Inspection needs none of the gate below. `efibootmgr -v`, `lsblk`,
`fdisk -l`, `gpart show`, `diskutil list`, reading a boot loader's
config, working out why a fresh VM will not boot — all of it runs
under the guard like any other read-only work, and this skill is
often invoked for exactly that.

Never ask an operator to disable a safety mechanism in order to
look at something.

## Boot entries are not the gate

Changing an EFI boot entry destroys no data, and the guard does not
block `efibootmgr` in any form. Setting `BootNext` for a one-shot
test is the *safe* way to try a new OS, and needing the guard off
to do it would be backwards.

So boot-entry work follows `references/efi-boot.md` § Safety
instead, which owns those rules.

The one place boot configuration turns dangerous is ordering, not
permission — pointing the firmware at a root filesystem that is
not written yet, or overwriting the fallback binary before it is.
`references/os-replacement.md` § Boot Configuration Safety owns
that, and it applies whether or not the guard is on.

## Vendor hardware is out of scope

None of the workflows below runs on a device whose only OS is the
vendor's firmware: replacing or repartitioning it can leave the
device unbootable. That is every host whose appliance file says
`Hardware: vendor`, an `any` appliance on the vendor's own device
(`rules/os-detection.md` → Appliances), and a machine that boots
from on-board flash without EFI or BIOS. For a host that is not
`Hardware: vendor`, read the device first, in one call, and record
it in server memory as `Device: <vendor> <model>, EFI|no EFI`:

```
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
cat /proc/device-tree/model
ls -d /sys/firmware/efi
```

On FreeBSD, `kenv smbios.system.maker smbios.system.product` and
`sysctl machdep.bootmethod`. A missing file is no answer; where the
reads leave doubt, ask the user what the machine is. On a vendor
device, say so and stop.

## The gate — before the first disk write

The moment a step would write to a disk or a partition table, all
four have to hold:

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
   when the work is done. In the Claude Code desktop app there is
   no shell to export it from: the operator adds it to the `env`
   of `.claude/settings.local.json` by hand and starts a new
   session, which then opens with a note that the guard is off
   (docs/ai-tools.md → Claude Code Desktop). Set mid-session it has no
   effect, and writing it there yourself is blocked.

Being blocked by the guard before step 4 is the expected outcome.
Never rephrase a command to get past it.

Disable it for the write, not for the session's whole length: an
inspection that precedes the decision runs under the guard, and it
goes back on when the work is done.

Code blocks in the references that only run with the guard off
carry `guard-off` on their fence. Blocks marked `operator` are for
the user to type at a console, not for Hostwarden to run.

## Which reference

- **Wipe and reinstall, same machine, new OS** →
  `references/os-replacement.md`. Pre-replacement inventory, boot
  configuration safety, installation methods, and the checklist.
  It routes on to two more when the machine has no console:
  `references/os-replacement-ssh-only.md` for getting a rescue
  environment up over SSH, and
  `references/os-replacement-mfsbsd.md` for a FreeBSD target.
- **A second OS beside the existing one** →
  `references/dual-boot.md`. Partition planning, ZFS root
  repartitioning, filesystem choice, and testing a new OS without
  betting the boot order on it.
- **Boot entries, BootOrder, BootNext, boot loaders, a machine
  that stopped booting** → `references/efi-boot.md`. The other
  paths reach into it by section when EFI comes up; read the
  whole file only when boot management *is* the task.
- **Deploying a qcow2 / raw / VMDK image, cloud-init trouble, a
  fresh VM that will not boot or take SSH** →
  `references/cloud-image.md`.
- **Freeing a partition on a running system, repartitioning
  without physical access, needing scratch space on a disk that is
  in use** → `references/partition-staging.md`.
- **A root filesystem exists but nothing can run inside it** —
  the binaries are for another architecture or another OS, so no
  chroot → `references/os-replacement-offline-rootfs.md`, by QEMU
  or by extracting packages by hand. A cross-OS problem, not a
  console one; the cloud-image and EFI paths reach it too.
- **A partition carries the previous OS's type code** →
  `references/partition-type-codes.md`. Post-install fixup, run
  from the replacement checklist.

Read only the ones the task needs. They cross-reference each other
where a path continues.

## Rules that still apply

The pipeline in `rules/first-connection.md` runs before the first
remote command here, like everywhere else. Beyond that:

- `memory/custom-rules/hostwarden-os-install.md` and
  `memory/servers/<hostname>/rules.md` — the override chain for
  this skill, read before the work starts (later wins).
- `rules/backups.md` — the backup that gate step 3 verifies.
- `rules/secrets.md` — host keys and credentials recovered from
  the old system are secrets; inspect metadata, never contents.
- `rules/os/<family>.md` — for every OS involved, old and new.
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
