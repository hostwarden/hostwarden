---
name: hostwarden-new-guest
argument-hint: "[hypervisor] [guest name]"
description: Create a new virtual machine or system container on a
  hypervisor Hostwarden manages — Proxmox VE, libvirt, Incus, LXD
  or classic LXC — from the distribution's official cloud image,
  container template or installer, with the Hostwarden server
  baseline applied at first boot in whatever form that guest reads
  (cloud-init, Ignition, kickstart, preseed, autoinstall,
  AutoYaST), then registered like every other guest. Also builds
  and rebuilds the baseline template for containers on Proxmox VE.
  Use when the user asks to "create a VM on pve1", "set up a new
  container", "spin up a Debian guest", "make me a new server on
  <host>", "build the container template", "neuen LXC anlegen",
  "setz mir eine VM auf", "leg einen neuen Container auf pve1 an",
  "ich brauche eine neue VM". Not for installing or replacing the
  OS on an existing machine, which is hostwarden-os-install.
---

# hostwarden-new-guest

Creates a guest and hands it over as a server in memory that
meets `rules/baseline.md`. Nothing here is destructive: the guard
stays on, and a step it asks about is asked of the user.

## Before anything else

1. **Overrides:** keys `hostwarden-new-guest` and `baseline`, per
   `rules/overrides.md`.
2. **The host's pipeline** (`rules/first-connection.md`). The host
   must be in memory with a `Hypervisor:` line, and not on the
   read-only list (`rules/access-control.md`). Register the
   session on it (`rules/parallel-sessions.md`): creating a guest
   is the first change.
3. **Which reference:** by the `Hypervisor:` line.
   - `Proxmox VE (qm, pct)` → `references/proxmox.md`
   - `libvirt` → `references/libvirt.md`
   - `Incus`, `LXD` → `references/incus.md`
   - `LXC` → `references/lxc.md`
   - Anything marked `read-only`, or an appliance whose file says
     its web UI owns the guests (Unraid, ZimaOS, TrueNAS, XCP-ng
     through Xen Orchestra): the user creates it; see Hosts that
     keep guests to their UI below.
   - Anything else: say that Hostwarden has no creation path for
     it and stop.

## The request

First, one call on the host for what the defaults and the
capacity check need: the reference's Before the creation. The
guests' memory comes from the inventory the pipeline already ran
(`rules/hypervisors.md` → Inventory).

Then settle every parameter before the first change, in one
question with defaults filled in (`AskUserQuestion` where it
exists):

- **Kind:** VM or container. A container shares the host's
  kernel; a VM is the default for anything that needs its own
  kernel, a firewall of its own at kernel level, or Docker
  without nesting.
- **Distribution and release:** the current stable release,
  looked up live (`rules/version-check.md`); never an image the
  distribution no longer supports.
- **Name:** the guest's FQDN. No directory of that name under
  `memory/servers/`, no guest of that name in the host's
  `guests.md`, and neither the name nor a static address on the
  blacklist or the read-only list (the lookup of
  `rules/access-control.md`).
- **ID** (Proxmox VE): the next free one.
- **Address:** DHCP, or a static address with prefix, gateway and
  DNS resolvers. The resolvers default to the host's own, from its
  `/etc/resolv.conf`; Proxmox VE takes those by itself when none
  are given (`--nameserver` in `qm.1` and `pct.1`), every other
  path writes them into the network config. DNS for the name is
  the user's; say so when it does not resolve to the address.
- **Resources:** vCPUs, memory, disk size, storage, bridge.
  Defaults: 2 vCPUs, 2 GiB, 20 GiB for a VM and 8 GiB for a
  container, the storage and bridge the host's other guests use.
- **Starts with the host:** yes by default.
- **Admin keys:** where no override fills the baseline's Admin
  Keys, ask which public key to use, offering the `~/.ssh/*.pub`
  files of the workstation and the keys `ssh-add -L` lists (an
  agent such as 1Password's keeps no file), and suggest recording
  it there. A user without a key who asks for a password gets one
  as `references/user-data.md` → Passwords says.

A static address must be free: no `IP:` line in memory and no
entry in `guests.md` has it, and from the host neither
`ping -c 2 -W 1 <address>` answers nor `ip neigh show <address>`
afterwards shows a MAC (`lladdr`); a `FAILED` or `INCOMPLETE`
entry means nothing answered.

Say in one line each what is tight: memory against what running
guests already hold, free space on the storage, CPUs. Creating the
guest anyway is the user's call.

Where the guest's ports are reached through the host — a NAT
network, an Incus proxy device — `rules/port-check.md` and
`rules/firewall-changes.md` apply to the host. A bridged guest
with its own address touches neither.

Show the plan in one block, and ask once: host, kind, image with
its checksum source, name, ID, address, resources, the baseline
version. Creating a guest is a change on the host
(`rules/system-containers.md` → Changes).


## The baseline

Render it as `references/user-data.md` says before the guest is
created. The reference names what each platform reads it from.

This is the guest's first-boot configuration, the one place
`AGENTS.md` → Critical Safety Rules lets Hostwarden set sshd's
login options and keys. It is the only place: the boundary is the
guest, not the format. A guest that has already started is a
server, and every rule for a server applies to it.

Which form it takes follows from what the guest reads at its
first boot, not from the hypervisor; the references are all under
`references/`:

| The guest reads          | From                     | Reference             |
| ------------------------ | ------------------------ | --------------------- |
| user-data from the host  | a cloud image            | `user-data.md`        |
| a seed in its filesystem | the container template   | `proxmox-template.md` |
| a seed in its filesystem | the LXC download image   | `lxc.md`              |
| a seed in its filesystem | a prepared disk image    | `image-prep.md`       |
| an Ignition config       | Fedora CoreOS, Flatcar   | `ignition.md`         |
| an installer's answers   | an installer ISO or tree | `answer-files.md`     |

All but Ignition carry the one rendered cloud-init file, handed
over or seeded; Fedora CoreOS and Flatcar run no cloud-init and
get a rendering of their own. Either way one version is recorded
in the guest's memory.

Hostwarden writes sshd's configuration and keys through the
mechanism the guest itself reads, never from outside into a
mounted image or an unstarted container's root filesystem. Where a
guest has no such mechanism, the files are the user's to place
(`references/image-prep.md` → Where this path ends).

## After creation

1. **Wait for the first boot** in one call on the host, as the
   reference shows: a loop there, not an SSH retry
   (`rules/ssh-unreachable.md`). What that call waits for is the
   form's own signal — cloud-init reporting done, the guest agent
   answering after an install, and for Ignition, which has neither,
   a fixed wait before the first login. Never a loop on the SSH
   port, which fail2ban and sshd's `PerSourcePenalties` count.
   Where the manager can enter the guest — `pct exec`,
   `qm guest exec`, `incus exec` — the same call waits for
   `cloud-init status --wait --long` and reads the public host key;
   read-only, and only on the guest this run created. A call that
   ends before the signal — out of time, or cut by the reboot
   `package_reboot_if_required` may cause — is run once more, then
   reported.
2. **The first login.** Record the guest's host key in
   `memory/known_hosts` (`rules/host-keys.md` → Getting a Key,
   source 1), with a read of its own into the cache file, never
   copied from the output above, then log in as usual. Where the
   manager cannot read the key (libvirt), the first login records
   it, as source 3 there says for a guest this run created, and
   waits for cloud-init over SSH.
   `cloud-init status --wait --long` exits 0 when done, 2 when it
   finished with errors it recovered from — a finding to report
   line by line — and 1 when it failed: report that, leave the
   guest as it is, and ask.
3. **The pipeline on the guest** (`rules/first-connection.md`). The
   SSH user is the one the user-data created: write its
   per-server entry in `memory/user.md` instead of asking
   (`rules/ssh-user.md`).
4. **Register it.** Run the host's inventory for the new guest
   (`rules/hypervisors.md` → Inventory): its entry goes into
   `guests.md` with `→ <directory>`, and its keys into the guest's
   `Guest identity:`, with `Runs on:` as Linking Guest and Host
   says there. The guest's memory also gets
   `- Origin: cloud image (Debian 13 genericcloud)` or
   `- Origin: <pveam template>`, and `- Baseline:` as
   `rules/baseline.md` → Rendered Versions says. A password the
   user asked for is a decision in the guest's `decisions.md`
   (`rules/decisions.md`): `## Password login`, with the user's
   reason, settling `baseline → SSH Login` for password login, and
   for SSH with it too where they asked for that.
5. **Verify the baseline** on the guest as `hostwarden-baseline`
   step 2 measures it: the check each section of
   `rules/baseline.md` names, in as few bundled calls as they
   allow. The backup is looked up from the host instead: on
   Proxmox VE a job in `/etc/pve/jobs.cfg` with `all 1` or this
   guest's ID, elsewhere the hypervisor's own backup schedule or
   the guest's as
   `.agents/skills/hostwarden-housekeeping/references/backup-presence.md`
   finds it. A section the guest misses is a finding of this run;
   for a missing backup, ask whether to add the guest to a job.
6. **Log** on both, as `rules/changelog.md` says: the host's
   journal line names the guest created, the guest's names the
   baseline version.

A guest that fails is never deleted on Hostwarden's own account,
and never rescued by writing a password or a key into it. Where
the manager can enter it, read `cloud-init status --long` and the
fingerprints of the SSH user's keys (`rules/secrets.md`) to find
out why, and report. Fix the rendered file and create the guest
again once the user has asked for the failed one to be removed
(`rules/system-containers.md` → Changes).

## Hosts that keep guests to their UI

Unraid, ZimaOS and TrueNAS create guests in their web UI, none of
which has a field for user-data. XCP-ng's is Xen Orchestra's: its
VM creation takes a custom cloud-init configuration
(<https://docs.xen-orchestra.com/manage-your-infrastructure/vm-templates>).

Give the user the steps as one list: the image with its checksum
(`references/images.md`) as the VM's disk, name, resources,
network, and the rendered user-data — on XCP-ng to paste, on the
others as a seed ISO attached as a second CD drive
(`references/seed-iso.md`). Where the UI cannot
import a disk image, the distribution's installer takes its answer
file from a second ISO instead
(`references/answer-files.md` → A host whose UI owns the guests),
and the guest still comes up on the baseline. Only a UI that can
attach no second ISO at all leaves the installer's own questions
and a password the user types: say so, and go on only if the user
wants that. Once the guest answers on SSH, go on at After creation
step 3.

## References

- `references/user-data.md` — the baseline as cloud-init
  user-data: what it carries, how it is rendered and checked,
  and a password on request.
- `references/images.md` — each distribution's cloud image, and
  how its checksum and signature are verified.
- `references/proxmox.md` — Proxmox VE: VMs from a cloud image
  and containers from the baseline template.
- `references/proxmox-template.md` — building that template.
- `references/libvirt.md` — libvirt with `virt-install`.
- `references/incus.md` — Incus and LXD, and the baseline as a
  profile.
- `references/lxc.md` — classic LXC with `lxc-create`.
- `references/ignition.md` — Fedora CoreOS and Flatcar: the
  baseline as Butane, transpiled to Ignition.
- `references/answer-files.md` — kickstart, preseed, autoinstall
  and AutoYaST, for a guest that has to be installed.
- `references/image-prep.md` — changing a disk image before the
  guest's first boot.
