# System Containers (LXC, Incus, LXD, Proxmox, FreeBSD Jails)

A system container shares the host's kernel and clock but boots
its own init, package manager and journal. For Hostwarden it is a
server, not a service, and so is a VM: each has its own memory
directory and runs the whole pipeline. Application containers
(Docker, Podman) are `rules/containers.md`.

## Reaching It

**SSH first, always.** Via-host mode
(`rules/first-connection.md` → Via-host mode) is the fallback
for the first two cases below, and the last two are contacts of
their own:

- **SSH gives no answer:** only as `rules/ssh-unreachable.md` →
  A guest on a known host allows, for this session. Machine memory
  keeps its SSH access.
- **No sshd in the guest:** ask the user once: install one (then
  SSH), or record `Mode: via` in its memory
  (`rules/machine-memory.md`). Not for a Windows guest: Hostwarden
  reaches Windows over OpenSSH only (`rules/os/windows.md`), and
  the pipeline's `sh -c` finds no shell there. Install OpenSSH,
  or leave the guest to its console.
- **Registering a guest from its host's inventory:** read-only,
  once per guest, as `rules/hypervisors.md` → Registering Guests
  describes.
- **A guest being created:** read-only until its first SSH login,
  to wait for its first boot and read its public host key; and
  the build container of a baseline template, which never becomes
  a server (`hostwarden-new-guest`).

Through the host's manager, as root inside. Treat each as a new
environment, where the command inside sets the locale again: the
bundle it reads opens with `export LC_ALL=C`, or a single command
takes `env LC_ALL=C` in front (`rules/locale.md`).

- **Incus:** `incus list --all-projects`,
  `incus exec <ct> -- <cmd>`
- **LXD:** `lxc list --all-projects`, `lxc exec <ct> -- <cmd>`
- **LXC:** `lxc-ls -f`, `lxc-attach -n <ct> -- <cmd>`
- **Proxmox container:** `pct list`, `pct exec <vmid> -- <cmd>`
- **FreeBSD jail**, whichever manager made it: `jls -N`,
  `jexec <jail> <cmd>`, with the name `jls -N` prints: iocage's
  `web.example` is `ioc-web_example`, its dots turned into
  underscores. Use `jexec` rather than `bastille cmd`, which
  puts a header line of its own into the output; `jexec` passes
  stdin on to the `sh -s` bundle. Leave out `jexec -l`, which
  cuts `PATH` down to `/bin:/usr/bin` and loses `sysctl` and
  `pkg`. Never `iocage exec --force`: it starts a stopped jail.
- **Proxmox VM:** `qm guest exec <vmid> --timeout <s> -- <cmd>`,
  after `qm guest cmd <vmid> ping` in the same call, within the
  limits of → The QEMU Guest Agent below.

An Incus or LXD guest lives in a project, and every command
except `--all-projects` acts in the default one. So carry the
project the listing showed into each later command —
`incus exec <ct> --project <name> -- <cmd>`, and the same for
`config`, `info` and the snapshot commands — and into the
`Runs on:` line of its memory. Two projects may hold a guest
of the same name: without the project, the pipeline and every
change after it land on the wrong server.

LXD's client is named `lxc`; the classic LXC tools are `lxc-*`.
On an appliance, only the tools its file names: on Proxmox VE
`pct` and `qm`, never `lxc-attach` or `virsh`, although its
guests are LXC and QEMU underneath.
A libvirt VM, or one without the QEMU guest agent, has only its
console: interactive, the user's tool, not Hostwarden's.

### The QEMU Guest Agent

`qm guest exec` hands one command to the agent inside the VM,
then asks the agent once a second whether it has exited, until it
has or `--timeout` runs out; each of those questions fails after
5 seconds without an answer (`got timeout`). The default timeout
is 30 seconds, and `--timeout 0` waits for ever
(<https://pve.proxmox.com/pve-docs/qm.1.html>, `src/PVE/CLI/qm.pm`
and `src/PVE/QMPClient.pm` in `qemu-server`).

- **Every call names its timeout,** never `0`, and runs under the
  host's `timeout` with 15 seconds more, so neither a slow command
  nor an agent that stops answering between two questions holds
  the call: `timeout 75 qm guest exec 105 --timeout 60 -- …`.
- **One call carries at most 2 KiB of script,** whether as the
  `sh -c` argument or on stdin with `--pass-stdin 1`. Measure it
  before sending (`printf %s "$P" | wc -c`), and split a bundle
  that is larger at its steps, then within a step, one call each.
  The protocol would take far more — up to 1 MiB on stdin — so
  the cap is Hostwarden's: a bundle of about 5 KB has timed out
  and left the agent answering nothing, and a small call keeps
  what one failure takes with it small. A step that cannot be
  split below the cap is not sent through the agent: a guest that
  has SSH gets it on its first own connection, and for one
  without, ask the user.
- **The answer is a JSON object,** not the guest's own output and
  exit status: read the command's output from `out-data`, its
  errors from `err-data`, and treat any `exitcode` other than 0
  as a failed command. A probe whose output is taken from the raw
  answer reads the serialised JSON as if it were the guest's, and
  a failed command passes for an answer. `out-truncated: true`
  means the output was cut at 16 MiB, and what arrived is not all
  of it
  (<https://www.qemu.org/docs/master/interop/qemu-ga-ref.html>).

  Run the probe once, hold the object, then read `exitcode` and
  `out-data` from what is held. Held under `&&`, a 124 from the
  host's `timeout` stays the call's exit status; a pipe straight
  into `jq` would put `jq`'s status in its place:

  ```bash
  r=$(timeout 45 qm guest exec 105 --timeout 30 -- \
    sh -c 'export LC_ALL=C; …') &&
  if printf '%s\n' "$r" | jq -e '.exitcode == 0' >/dev/null
  then printf '%s\n' "$r" | jq -r '."out-data"'
  else printf '%s\n' "$r"; false
  fi
  ```

  Where the gate fails, the whole object is printed: the `pid` of a
  call whose timeout ran out, or the `err-data` of a failed one.
- **A call whose timeout ran out** prints
  `timeout reached, returning pid` and answers `{"pid": <n>}`,
  with no `exitcode`: the command still runs in the guest. Never
  send it again on top. Read its end with
  `qm guest exec-status <vmid> <pid>`, in one call on the host that
  asks every 5 seconds for as long as the first call's timeout, under
  the host's `timeout` as above. Once it shows `exited` true, that
  is the answer, and the agent forgets the process, so a second
  read finds nothing. Still running after that: report the command
  and its pid as still running, and send nothing more for that step.

**When the agent stops answering** — `ping` fails, or a call ends
in `got timeout` or `QEMU guest agent is not running`, or the
host's `timeout` ends it with exit status 124 — send this
VM nothing more through the agent in this session: no retry, no
loop waiting for it. A VM that `hostwarden-new-guest` is creating
is the exception until its first boot is done: its agent is silent
until the image has installed it, and again through the reboot
first boot may cause, and that skill's wait says what follows. `qm
status <vmid>` on the host, read-only,
says whether the VM itself still runs. Report the VM, the call it
was on (the step, the script's size, the timeout), the error line
and that status, and offer what the user can choose: the guest's
own SSH where it has one, the console in the web UI, or a restart.
Restarting `qemu-guest-agent` in the guest is a service restart,
and `qm reboot`, `qm reset`, `qm shutdown` or `qm stop` a reboot
or a power cut of a server: none of them without the user's
explicit yes (→ Changes).

## Privileges

Managing guests needs root on the host
(`rules/privilege-escalation.md`). A privileged container's root
is the host's UID 0: record `- Container: privileged` in its
memory. Find them with
`grep -L '^unprivileged: 1' /etc/pve/lxc/*.conf` (Proxmox) or
`incus config show <ct> --expanded | grep 'security.privileged:'`,
never the whole output, which holds cloud-init user-data
(`rules/secrets.md`). Without `--expanded`, Incus prints what is
set on the instance alone, and a key the guest inherits from a
profile is missing.

## What the Host Owns

Where `Virtualization:` in memory names a container, a system
container or a FreeBSD jail, these belong to the host, and a probe
run inside reads the host's state as if it were the guest's:

- **The clock:** the time service and whether it is synchronised.
- **The running kernel:** its version, a pending reboot read from
  it (running against installed kernel, Livepatch's kernel state,
  needrestart's kernel lines, a missing module directory for
  `uname -r`), and the boot time and uptime.
- **Kernel-wide sysctls.** A Linux container's own are those of
  its network namespace, IP forwarding and ICMP redirect
  acceptance among them. A jail's own are `kern.securelevel`,
  `security.bsd.unprivileged_proc_debug` and, where
  `security.jail.vnet` is `1`, the `net.inet*` keys.
- **The USB bus:** a container sees the host's devices.
- **CPU microcode**, which the host kernel loads.
- **Kernel memory state:** zswap, zram, the ZFS ARC, memory
  pressure, and `/proc/swaps` unless lxcfs stands in for it. The
  container's own memory and swap are what lxcfs shows in its
  `/proc/meminfo`.

A check of one of these does not run in a container. Its line
reads `n/a (container)` and is never a finding; the USB inventory
and the microcode check report nothing at all. What the
container's own packages and files write stays its own and is
checked as usual: the timezone, the userland version,
`/var/run/reboot-required`.

## Changes

Creating and changing guests is ordinary work on the host;
creating one is the `hostwarden-new-guest` skill. Every change is
asked first:

- Restarting a container or VM is a reboot of that server
  (`AGENTS.md` → Critical Safety Rules → Ask before).
- Before a config change (`incus config set`, `pct set`,
  `iocage set`, a jail's `jail.conf`): a snapshot (below), else a
  copy of `/etc/pve/lxc/<vmid>.conf`, of `incus config show <ct>`,
  of the file that defines the jail or of `iocage get -a <jail>`
  (`rules/backups.md`).
- **Stopping or deleting one** powers off or destroys a server:
  only on the user's explicit request. First show, from the live
  host and in one call, what it hits: ID, name, host, state,
  disks (a jail's path and the dataset under it), and the newest
  backup (a snapshot goes with the guest).
  A run with no human to ask never does it: the user runs the
  command.
- Deleting a snapshot, or rolling back to one, which discards
  everything since: name what goes.
- **A guest's cloud-init settings** — Proxmox VE's `--ipconfig`
  and `--cicustom` files without a fixed meta-data file, Incus's
  and LXD's `cloud-init.*` and `user.*` keys, a NIC's name there —
  can give it a new instance ID. So can a new name: a Proxmox VE
  VM's name is the hostname in the user-data Proxmox generates,
  which the instance ID is a hash of, where `--cicustom` names no
  `user=` file (`src/PVE/QemuServer/Cloudinit.pm` in
  `qemu-server`); `incus rename` and LXD's `lxc rename` give an
  instance a new `volatile.cloud-init.instance-id`
  (`test/suites/cloud-init.sh` in `lxc/incus` and
  `canonical/lxd`). At its next boot cloud-init then
  treats it as a new server: it regenerates the SSH host keys and
  runs `users` again. Name that before asking; where the guest's
  own configuration can make the change, make it there instead.

Proxmox specifics, the clean `shutdown` against the hard `stop`
among them: `rules/appliance/proxmox-ve.md` → Guests.

## Snapshots

With access to the host, and the host not on the read-only list
(`rules/access-control.md`), a snapshot is the better safety net
before a risky change to a guest, to its config or inside it (an
upgrade, a larger config rework): it covers the guest's own
storage and rolls back in one command.

**Read the mount points first.** What a snapshot leaves out stays
changed after a rollback, and the guest comes back beside data
that moved on without it. On Proxmox, `pct config <vmid>` lists
`mp0:`, `mp1:` …; a bind or device mount point is not managed by
the storage subsystem and is not snapshotted, and a volume with
`backup=0` is left out of a backup as well (`qm config <vmid>`
for a VM's disks). An Incus or LXD disk device pointing at a host
path (`source=/…` in `incus config show <ct> --expanded`) is the
same case, and so is a jail's nullfs mount of a host directory:
the file its `mount.fstab` names (Bastille's
`<jailsdir>/<name>/fstab`), `mount +=` lines in its
configuration, or `iocage fstab -l <jail>`. Back those up on
their own (`rules/backups.md`), or say plainly that the snapshot
does not cover them before the change starts.

List what exists first, and take one only when nothing fits:

- **Proxmox:** `pct listsnapshot <vmid>`,
  `pct snapshot <vmid> <name>` (`qm` for a VM)
- **Incus / LXD:** `incus info <ct>` lists them,
  `incus config show <ct> --expanded` shows
  `snapshots.schedule` and `snapshots.expiry`, a profile's
  included; `incus snapshot create <ct> <name>`
  (LXD: `lxc info`, `lxc snapshot <ct> <name>`)
- **libvirt:** `virsh snapshot-list <dom>`,
  `virsh snapshot-create-as <dom> <name>`
- **iocage:** `iocage snaplist <jail>`,
  `iocage snapshot -n <name> <jail>`
- **Bastille** on ZFS: `bastille zfs <jail> snapshot <name>`. A
  jail from `jail.conf` on ZFS: `zfs snapshot <dataset>@<name>`,
  only where its path is a dataset of its own —
  `zfs list -H -o name,mountpoint <path>` prints the path itself
  as the mountpoint. A path inside a shared dataset (the root
  file system, a common `jails` dataset) is no case for a
  snapshot, a new or an automatic one: a rollback would take the
  host's or other jails' data back with it, so the file backup
  applies. Both list as the ZFS host entry
  below shows.
- **ZFS host**, for automatic ones (sanoid, zfs-auto-snapshot),
  the newest five of the guest's dataset:

  ```bash
  zfs list -t snapshot -H -o name,creation \
    -s creation -d 1 <dataset> | tail -n 5
  ```

A fresh automatic snapshot (hourly, say) is enough, and whatever
makes it also removes it: name it to the user and ask whether it
will do. A new one is named for Hostwarden and the change
(`hostwarden-pre-upgrade-20260919`). The storage must support
it; where it does not, the command fails and the file backup
applies. A snapshot lives on the guest's own storage: it is no
backup, and it goes with the guest.

A snapshot Hostwarden took is Hostwarden's to remove, because it
grows while it exists. Offer to delete it once the change has
proved itself; if the user wants to wait, write
`- [ ] delete snapshot <name> on <host>` into the guest's
`todo.md` (`rules/machine-memory.md` → Session to-do list).

Docker in a system container (common with Proxmox `nesting=1`):
`rules/containers.md`.
