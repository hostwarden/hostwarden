# System Containers (LXC, Incus, LXD, Proxmox)

A system container shares the host's kernel but boots its own
init, package manager and journal. For Hostwarden it is a server,
not a service, and so is a VM: each has its own memory directory
and runs the whole pipeline. Application containers (Docker,
Podman) are `rules/containers.md`.

## Reaching It

**SSH first, always.** Via-host mode
(`rules/first-connection.md` → Via-host mode) is the fallback,
for two cases only:

- **SSH gives no answer:** only as `rules/ssh-unreachable.md` →
  A guest on a known host allows, for this session. Server memory
  keeps its SSH access.
- **No sshd in the guest:** ask the user once: install one (then
  SSH), or record via-host mode in its memory
  (`rules/server-memory.md`).

Through the host's manager, as root inside:

- **Incus:** `incus list --all-projects`,
  `incus exec <ct> -- <cmd>`
- **LXD:** `lxc list --all-projects`, `lxc exec <ct> -- <cmd>`
- **LXC:** `lxc-ls -f`, `lxc-attach -n <ct> -- <cmd>`
- **Proxmox container:** `pct list`, `pct exec <vmid> -- <cmd>`
- **Proxmox VM:** `qm guest exec <vmid> -- <cmd>`, after
  `qm guest cmd <vmid> ping` in the same call

An Incus or LXD guest lives in a project, and every command
except `--all-projects` acts in the default one. So carry the
project the listing showed into each later command —
`incus exec <ct> --project <name> -- <cmd>`, and the same for
`config`, `info` and the snapshot commands — and into the
`Mode: via …` line of its memory. Two projects may hold a guest
of the same name: without the project, the pipeline and every
change after it land on the wrong server.

LXD's client is named `lxc`; the classic LXC tools are `lxc-*`.
A libvirt VM, or one without the QEMU guest agent, has only its
console: interactive, the user's tool, not Hostwarden's.

## Privileges

Managing guests needs root on the host
(`rules/privilege-escalation.md`). A privileged container's root
is the host's UID 0: record `- Container: privileged` in its
memory. Find them with
`grep -L '^unprivileged: 1' /etc/pve/lxc/*.conf` (Proxmox) or
`security.privileged: "true"` in `incus config show <ct>`.

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
upgrade, a larger config rework): it covers the whole guest and
rolls back in one command.

List what exists first, and take one only when nothing fits:

- **Proxmox:** `pct listsnapshot <vmid>`,
  `pct snapshot <vmid> <name>` (`qm` for a VM)
- **Incus / LXD:** `incus info <ct>` lists them,
  `incus config show <ct>` shows `snapshots.schedule` and
  `snapshots.expiry`; `incus snapshot create <ct> <name>`
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
