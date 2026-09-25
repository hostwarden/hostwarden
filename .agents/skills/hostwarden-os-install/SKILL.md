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
  to relaunch with the taboo guard disabled. Not for creating a
  new VM or container on a hypervisor, which is
  hostwarden-new-guest.
---

# OS Installation, Replacement and Boot Management

Five workflows that share one disk, one boot loader and one
irreversible moment. Read the gate below first, then the reference
that matches what the user asked for.

A new VM or container is none of them: `hostwarden-new-guest`
creates it, with the guard on.

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

No workflow below **writes** on a device whose only OS is the
vendor's firmware: replacing or repartitioning it can leave the
device unbootable. That is every host whose appliance file says
`Hardware: vendor`, an `any` appliance on the vendor's own device
(`rules/first-detection.md` → Appliances), and a machine that boots
from on-board flash without EFI or BIOS. For a host that is not
`Hardware: vendor`, read the device first, in one call, and record
it in server memory as `Device: <vendor> <model>, EFI|no EFI`:

```
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
cat /proc/device-tree/model
ls -d /sys/firmware/efi
```

On macOS the machine is Apple's own hardware, so the refusal
applies to every Mac: `sysctl -n hw.model` names the model for the
record, and Hostwarden installs no other OS on it. On FreeBSD,
`kenv -q smbios.system.maker`,
`kenv -q smbios.system.product` — one name per call: a second
argument sets the first name to it — and
`sysctl machdep.bootmethod`. A missing file is no answer; where the
reads leave doubt, ask the user what the machine is.

On a vendor device, say so, and stop at the first step that would
write: no replacement, no dual boot, no repartitioning, no image
deployment, and no change to its boot configuration. Reading stays
open as Reading is always allowed says — inspecting disks and EFI
state, and working out why the machine no longer boots — and so
does `references/efi-boot.md` for what a boot entry means, as long
as nothing is written.

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
   (website/docs/getting-started/ai-tools.md → Claude Code Desktop).
   Set mid-session it has no effect, and writing it there yourself
   is blocked.

Being blocked by the guard before step 4 is the expected outcome.
Never rephrase a command to get past it.

Disable it for the write, not for the session's whole length: an
inspection that precedes the decision runs under the guard, and it
goes back on when the work is done.

Code blocks in the references that only run with the guard off
carry `guard-off` on their fence. Blocks marked `operator` are for
the user to type at a console, not for Hostwarden to run.

## Naming a target with no memory yet

Only where the target has no `memory/servers/<hostname>/` directory
yet — bare-metal hardware, or an already-provisioned VM that has
not booted. Never a reinstall of a host already in memory: its name
and `Site:` stand as they are, untouched by the wipe
(`references/os-replacement.md` → Memory Updates).

Settle this before this session's first connection to the target at
all, never merely before the disk write. The pipeline of
`rules/first-connection.md` runs before any command over SSH, a
read-only one included (`AGENTS.md` → Before Any Remote Command),
and creates `memory/servers/<hostname>/` on that first command
(step 6): reaching a rescue or minimal environment to inspect the
target, or to prepare a hot-migration
(`references/os-replacement-ssh-only.md`), takes away its "no
memory yet" status before this section would otherwise run. Naming
uses only what the operator already knows about the target — its
intended hostname or address, and, for a VM, its hypervisor —
never a read from the target itself, so nothing here needs that
first connection to happen first.

**Site**, where the target needs one it does not have. A guest
never gets a `Site:` of its own (`rules/network-topology.md` →
Sites): its site is its hypervisor's, read through `Runs on:` once
it is registered, and the question below is never asked for it —
only for the hypervisor, where that itself lacks a `Site:`. Bare
metal with no hypervisor is asked directly, at
`rules/network-topology.md` → Sites → The question's own trigger
for this moment ("before `hostwarden-os-install`'s first write on a
host whose memory has no `Site:` line"), and, in the same exchange,
the site's code where a naming scheme's template needs a `<site>`
token and the resolved site lacks one yet
(`rules/network-topology.md` → A site's code) — the way
`hostwarden-new-guest` → The request asks Site alongside the name.
With no memory directory yet to write into, the answer is held for
this session and written in when this session's own first
connection to the target creates that directory
(`rules/first-connection.md` step 6). Where the session ends before
any connection to the target happens — a bare-metal install that
spans a reboot nobody stayed at the console for — nothing carries
the answer forward, and it may have to be given again to whatever
later asks this host for its `Site:`.

**The name.** Where a `rules/naming-scheme.md` block applies to the
target's role — `Role: server`, unless this is the local machine
itself, which follows the ordinary rule instead
(`rules/first-detection.md` → Roles) — propose the next name it
gives and confirm it or take a typed name instead, exactly as
`rules/naming-scheme.md` → New hosts follow it immediately
describes for `hostwarden-new-guest`. Whichever name is settled,
proposed or typed, passes the same checks `hostwarden-new-guest` →
The request applies before creating anything: no directory of that
name already under `memory/servers/`, no guest of that name in a
host's `guests.md`, and neither the name nor a static address on
the blacklist or the read-only list (`rules/access-control.md`).
Where no block applies, the user's own hostname stands, checked the
same way.

Nothing here writes to `memory/naming.md` beyond an `Exempt:` line
where a typed name is kept off-scheme, and nothing here creates the
target's directory: that is first connection's job, whichever
connection to the target — rescue environment or new OS — turns
out to be first (After, below).

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
- **Writing a qcow2 / raw / VMDK image onto a machine's disk,
  cloud-init trouble, a fresh VM that will not boot or take SSH**
  → `references/cloud-image.md`.
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
- `rules/host-keys.md` — the new OS answers with new host keys
  unless the old ones were restored. Replace the host's lines as
  A Changed Key there says, without asking for the cause: this run
  is it. Read the new key through a session this run already
  trusts, such as the installer or rescue system that built the
  new root filesystem; where there is none, Getting a Key,
  source 3 covers a host this run reinstalled.
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

Where Naming a target with no memory yet held a `Site:`, this
session's first connection to the target — rescue environment or
new OS, whichever comes first — writes the held answer in as it
creates the `memory/servers/` entry (`rules/first-connection.md`
step 6). A first connection from a later session has no record of
it; see Naming a target with no memory yet for what that means. For
a host that already had one, `references/os-replacement.md` →
Memory Updates says why nothing needs restoring there instead.

That first connection reaches the target by whatever identifier is
actually reachable — its current address, a rescue environment's
own hostname, DHCP's transient one — which the settled name need
not match: DNS for a brand-new name often does not exist yet
(`rules/dns.md` → The proposal). Where the two differ, the
directory `rules/first-connection.md` created carries the
connection's identifier, not the settled one. Reconcile them before
reporting success, in this same session, by `rules/host-rename.md`
→ Memory's mechanism in full: the directory move and its DNS-alias
symlinks, the `Host` block `memory/ssh_hosts` needs to keep
reaching the machine (checked with `bin/hostwarden-ssh-config`),
and `memory/known_hosts`'s lines for the settled name
(`rules/host-keys.md` → DNS Aliases) — except keeping the
connecting identifier itself as a lasting alias, which that section
does for an old *hostname* someone might still reference: a bare
address or a rescue environment's own throwaway name is dropped
instead, never kept as an alias. Never leave the memory entry and
the name the install actually gave the machine reachable under two
different identifiers.
