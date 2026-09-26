---
sidebar_position: 3
description: Creates VMs and containers with the server baseline
  applied at first boot.
---

# New guests

```
 ❯ Create a Debian VM on pve1.example.com
 ❯ Leg einen neuen LXC auf pve1 an
```

## VMs from cloud images

Hostwarden creates VMs and containers on Proxmox VE, libvirt,
Incus, LXD and classic LXC, with the platform's own tools. A VM
starts from the distribution's official cloud image, checked
against its checksum and, where the distribution signs one, its
signature, and gets the baseline as cloud-init user-data at its
first boot, so there is no golden image to go stale. The rendered
user-data is kept, numbered, in `memory/baseline/`, and each guest
records the version it got. On Proxmox VE, containers come from a
baseline template Hostwarden builds from the official container
template; housekeeping says when it is due for a rebuild.

## Guests without cloud-init

A guest that reads no cloud-init gets the same baseline in the
form its system does read: Butane and Ignition for Fedora CoreOS
and Flatcar, a kickstart, preseed, autoinstall or AutoYaST file
where the guest has to be installed rather than copied from an
image, and a seed written into the root filesystem or the disk
image before the first start for everything else. On Incus the
baseline lives in a profile of its own per version, so it is
written once rather than on every command line. Whichever form it
takes, it is applied only to a guest that has never run: the SSH
server of a machine that is already up is never touched, in the
guest or through its host.

## Logging in

You log in with your SSH keys from the first boot on. If you have
no key and want a password, the guest generates one and shows it
only on its console, where you change it at the first login; a
container from the Proxmox VE baseline template gets no generated
password, and you set one at its console. Hostwarden then checks
the baseline on the guest, asks about adding it to a backup job,
and the guest goes through the usual first connection and is
registered with its host like every other guest.

## Appliances whose UI has no field

On Unraid, ZimaOS and TrueNAS you get the steps for the web UI and
a small seed ISO that carries the configuration, since their UIs
have no field for it; on XCP-ng you get the user-data to paste
into Xen Orchestra's cloud-init field. Replacing the OS of a
machine that already exists is
[Installing an operating system](os-install.md), not this one.
