# Incus and LXD

Incus's client is `incus`, LXD's is `lxc`; the commands below are
the same for both. Sources:
<https://linuxcontainers.org/incus/docs/main/cloud-init/>,
<https://linuxcontainers.org/incus/docs/main/reference/instance_options/>,
<https://documentation.ubuntu.com/lxd/latest/cloud-init/>.

## The image

The image server stands in for the checksum list: an image is
named by its SHA-256 fingerprint and fetched over HTTPS.

- **Incus:** `images:<distribution>/<release>/cloud`, for
  instance `images:debian/13/cloud`. Only the `/cloud` variant has
  cloud-init. The same image serves a container and, with `--vm`,
  a VM.
- **LXD:** `ubuntu:<release>` for Ubuntu, which carries
  cloud-init; LXD's `images:` remote is a different server from
  Incus's. `lxc image list images: <name>` shows what it has.

None of these images has `openssh-server`; the rendered file
installs it (`references/user-data.md`).

## Before the creation

The guest goes into a project: the one the user names, else the
one the host's other guests share, else `default`. Every command
below carries it, as `rules/system-containers.md` → Reaching It
says, and the guest's entry in `guests.md` names it (`prod/web3`).

In one call: `incus storage info <pool>` for free space,
`incus network list --project <project>` for the networks, and
the host's `free -m` and `nproc`. The instances' limits are in the
inventory listing.

## Creating it

```bash
incus launch images:debian/13/cloud web3 --project <project> \
  -s <pool> -d root,size=20GiB -c limits.cpu=2 \
  -c limits.memory=2GiB -c boot.autostart=true \
  -c cloud-init.user-data="$(cat <file>)"
```

- `--vm` for a VM. It needs `incus-agent` in the guest, which the
  `images:` VM images carry.
- `cloud-init.user-data` must be set before the first start, which
  `-c` at `launch` does. Incus resets
  `volatile.cloud-init.instance-id` when one of those keys or a
  NIC's name changes later (`needsNewInstanceID()` in Incus's
  `driver_common.go`; `rules/system-containers.md` → Changes).
  Images older than the `cloud-init.*` keys read `user.user-data`
  instead; Ubuntu 20.04 and older under LXD are such images.
- Networking: cloud-init asks for DHCP on `eth0` by default. On a
  network Incus manages, pin the address there at `launch`, the
  same way `-d root,size=` sets the disk:
  `-d eth0,ipv4.address=192.0.2.24`.
  On a bridge Incus does not manage, give a `network-config` as
  `references/libvirt.md` shows, through
  `-c cloud-init.network-config="$(cat <file>)"`.
- A `proxy` device publishes a port through the host.

## Waiting for the first boot

In one call:

```bash
timeout 570 incus exec web3 --project <project> -- \
  cloud-init status --wait --long &&
  incus exec web3 --project <project> -- \
  cat /etc/ssh/ssh_host_ed25519_key.pub
```

The key is read only once cloud-init has succeeded, so the call's
exit status is cloud-init's.
