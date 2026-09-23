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
`incus network list --project <project>` for the networks,
`incus profile list --project <project>` for the baseline
profiles already there, and
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
  instead; Ubuntu 20.04 and older under LXD are such images. Where
  a guest has to be configured after it exists but before it runs,
  `incus init`, the configuration, and `incus start` are the
  documented order — never a key set on an instance that has
  already started, which cloud-init would not read.
- Networking: cloud-init asks for DHCP on `eth0` by default. On a
  network Incus manages, pin the address there at `launch`, the
  same way `-d root,size=` sets the disk:
  `-d eth0,ipv4.address=192.0.2.24`.
  On a bridge Incus does not manage, give a `network-config` as
  `references/libvirt.md` shows, through
  `-c cloud-init.network-config="$(cat <file>)"`.
- A `proxy` device publishes a port through the host.

## The baseline as a profile

A `-c` at `launch` puts the whole rendered file on one command
line, once per guest. A profile holds it once for every guest of
that family and release, and it is where the documentation puts
it: "you should specify `vendor-data` in a profile and `user-data`
in the instance configuration".

So the baseline is the profile's `cloud-init.vendor-data`, and what
belongs to this one guest — its hostname, a static address — stays
`cloud-init.user-data` at `launch`. cloud-init merges the two;
where a key would appear in both, it is in the profile only
(<https://linuxcontainers.org/incus/docs/main/cloud-init/>).

One profile per rendered version, named as
`rules/baseline.md` → Rendered Versions says, and never edited
afterwards. The launch above makes a container, so it takes the
container rendering's profile; with `--vm` it takes the VM
rendering's. It is created in the same call as the launch, which
gains `-p default -p hostwarden-baseline-debian-ct-3`, and whose
`cloud-init.user-data` then carries only this guest's copy — its
hostname and network — never the rendered baseline a second time:
the two are merged, and a key in both is replaced rather than
added to. A guest whose copy carries SSH CA trust is the exception
(`references/user-data.md` → SSH CA):

```bash
incus profile create hostwarden-baseline-debian-ct-3 --project <project>
incus profile edit hostwarden-baseline-debian-ct-3 --project <project> < <file>
```

The YAML given to `incus profile edit` is the profile's own
document, with the rendered file indented under the key in
literal style:

```yaml
config:
  cloud-init.vendor-data: |
    #cloud-config
    # hostwarden-baseline debian-ct-3 (2026-09-22)
    …
description: hostwarden baseline debian-ct-3
devices: {}
```

Why a new profile each time rather than an edit: "if you edit a
profile, the changes are automatically applied to all instances
that use the profile". Instances already running would take the
device and limit changes at once, and that is a change to servers
nobody asked about. `incus profile show <name> --project <project>`
lists its `used_by`; a profile with anything in that list is read,
never written. The `default` profile is never touched at all.

A profile belongs to a project, like the guest: every `profile`
command here carries the guest's `--project`, as
`rules/system-containers.md` → Reaching It says for every command,
or the launch in that project does not find it.

An older baseline profile that `used_by` shows as empty can be
removed with `incus profile delete <name> --project <project>`:
offer it, name the
profile, and leave the decision to the user.

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
