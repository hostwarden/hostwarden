# System Containers (LXC, Incus, LXD, Proxmox)

A system container shares the host's kernel and clock but boots
its own init, package manager and journal. For Hostwarden it is a
server, not a service, and so is a VM: each has its own memory
directory and runs the whole pipeline. Application containers
(Docker, Podman) are `rules/containers.md`.

## Reaching It

**SSH first, always.** Via-host mode
(`rules/first-connection.md` → Via-host mode) is the fallback
for the first two cases below, and the third is one read-only
first contact:

- **SSH gives no answer:** only as `rules/ssh-unreachable.md` →
  A guest on a known host allows, for this session. Server memory
  keeps its SSH access.
- **No sshd in the guest:** ask the user once: install one (then
  SSH), or record via-host mode in its memory
  (`rules/server-memory.md`). Not for a Windows guest: Hostwarden
  reaches Windows over OpenSSH only (`rules/os/windows.md`), and
  the pipeline's `sh -c` finds no shell there. Install OpenSSH,
  or leave the guest to its console.
- **Registering a guest from its host's inventory:** read-only,
  once per guest, as `rules/hypervisors.md` → Registering Guests
  describes.

Through the host's manager, as root inside:

- **Incus:** `incus list --all-projects`,
  `incus exec <ct> -- <cmd>`
- **LXD:** `lxc list --all-projects`, `lxc exec <ct> -- <cmd>`
- **LXC:** `lxc-ls -f`, `lxc-attach -n <ct> -- <cmd>`
- **Proxmox container:** `pct list`, `pct exec <vmid> -- <cmd>`
- **Proxmox VM:** `qm guest exec <vmid> -- <cmd>`, after
  `qm guest cmd <vmid> ping` in the same call. It answers with a
  JSON object, not with the guest's own output and exit status:
  read the command's output from `out-data`, its errors from
  `err-data`, and treat any `exitcode` other than 0 as a failed
  command — a probe whose output is taken from the raw answer
  reads the serialised JSON as if it were the guest's, and a
  failed command passes for an answer:

  ```bash
  qm guest exec 105 -- sh -c '…' \
    | jq -e '.exitcode == 0' >/dev/null && \
  qm guest exec 105 -- sh -c '…' | jq -r '."out-data"'
  ```

  Where a single call has to do, keep the two apart in it: run the
  probe once, hold the object, then read `exitcode` and `out-data`
  from what is held.

An Incus or LXD guest lives in a project, and every command
except `--all-projects` acts in the default one. So carry the
project the listing showed into each later command —
`incus exec <ct> --project <name> -- <cmd>`, and the same for
`config`, `info` and the snapshot commands — and into the
`Mode: via …` line of its memory. Two projects may hold a guest
of the same name: without the project, the pipeline and every
change after it land on the wrong server.

LXD's client is named `lxc`; the classic LXC tools are `lxc-*`.
On an appliance, only the tools its file names: on Proxmox VE
`pct` and `qm`, never `lxc-attach` or `virsh`, although its
guests are LXC and QEMU underneath.
A libvirt VM, or one without the QEMU guest agent, has only its
console: interactive, the user's tool, not Hostwarden's.

## Privileges

Managing guests needs root on the host
(`rules/privilege-escalation.md`). A privileged container's root
is the host's UID 0: record `- Container: privileged` in its
memory. Find them with
`grep -L '^unprivileged: 1' /etc/pve/lxc/*.conf` (Proxmox) or
`security.privileged: "true"` in
`incus config show <ct> --expanded`. Without `--expanded`, Incus
prints what is set on the instance alone, and a key the guest
inherits from a profile is missing.

## Changes

Creating and changing guests is ordinary work on the host, and
every change is asked first:

- Restarting a container or VM is a reboot of that server
  (`AGENTS.md` → Critical Safety Rules → Ask before).
- Before a config change (`incus config set`, `pct set`): a
  snapshot (below), else a copy of `/etc/pve/lxc/<vmid>.conf` or
  of `incus config show <ct>` (`rules/backups.md`).
- **Stopping or deleting one** powers off or destroys a server:
  only on the user's explicit request. First show, from the live
  host and in one call, what it hits: ID, name, host, state,
  disks, and the newest backup (a snapshot goes with the guest).
  A run with no human to ask never does it: the user runs the
  command.
- Deleting a snapshot, or rolling back to one, which discards
  everything since: name what goes.

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
same case. Back those up on their own (`rules/backups.md`), or
say plainly that the snapshot does not cover them before the
change starts.

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
`todo.md` (`rules/server-memory.md` → Session to-do list).

Docker in a system container (common with Proxmox `nesting=1`):
`rules/containers.md`.
