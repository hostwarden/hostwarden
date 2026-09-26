---
sidebar_position: 1
description: Lists and reads inside the guests of every hypervisor
  Hostwarden manages, including clusters.
---

# Hypervisors and their guests

On a hypervisor, Hostwarden lists every guest without being asked
and reads inside the ones it can reach.

## What is listed

On a hypervisor — Proxmox VE, XCP-ng, or libvirt, Incus, LXD, LXC,
vm-bhyve, Hyper-V or VirtualBox on an ordinary system, and FreeBSD
with its jails from `jail.conf`, Bastille or iocage — Hostwarden
lists every guest without being asked, stopped ones and templates
included, in `memory/machines/<host>/guests.md`.

- **The listing comes from the hypervisor and the guest tools.** It
  reads guests through the hypervisor and asks the guest tools for
  hostname, OS and addresses where they run.
- **Other jails are listed too.** Other running jails are listed as
  well, and VirtualBox lists the VMs of the user Hostwarden logs in
  as.
- **Some appliances are listed read-only.** The guests of TrueNAS,
  Synology DSM, Unraid and ZimaOS are listed read-only.

## Guests it reads inside

Every running guest the hypervisor can enter — a container or
jail, and a Proxmox VE VM with its guest agent — then gets memory
of its own, named by its hostname, read-only and without you
naming each one.

- **Some guests are skipped.** A blacklisted guest is skipped, a
  Windows guest is never entered, and on a Proxmox VE cluster only
  the guests on the node the session is on are entered.
- **This is the one unasked step through the hypervisor.** That is
  the only time Hostwarden goes through the hypervisor unasked;
  after that, SSH comes first as always.
- **It reports what it did.** Afterwards it tells you which guests
  it read inside and through which command, which it left out and
  why, what it wrote (one read-only journal line in each guest, its
  host key in `memory/known_hosts`, memory on your side), and what
  it found.
- **The first SSH connection stays yours.** Hostwarden does not
  make it for you.
- **A stopped guest stays stopped.** It is never started to look
  inside.

## Stopped guests

For stopped guests it asks you once, in one list, why they are
off: on purpose, retired, not in service yet, or a template. The
question comes back only when a guest starts and stops again. A
guest leaves the list only once its own hypervisor confirms it is
gone.

## Linking guest and host

Each guest records the host it runs on, as
`Runs on: pve1.example.com (VM 101)`. The link comes from what
both sides see, never from a name alone: the MAC addresses, and
for KVM, bhyve and Xen VMs the VM's UUID as well. Hyper-V links by
the host name the hypervisor reports to the guest. A jail without
a network stack of its own has no MAC, and links by its path or by
name and IP address together. A VM in the cloud records its
provider. Where nothing matches, Hostwarden asks once.

## Clusters

A Proxmox VE cluster, an XCP-ng pool of more than one host and an
Incus or LXD cluster are inventoried as one, from whichever member
the session is on, in `memory/clusters/<name>/`: its members, its
HA state and pool master, and every guest with the member it runs
on. Each guest is listed and rated once, not once per member. A
guest in a cluster records
`Runs on: cluster prod (VM 101), last on pve2.example.com`; after
a live migration or an HA failover the next listing moves it
without asking you.
