---
id: 20260929-proxmox-container-template-baked-with-first-boot-units
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [guests, proxmox, baseline]
---

# The Proxmox VE container template is baked, with first-boot units

## Context

Decided 2026-09-29 for `hostwarden-new-guest`. The container
template carried cloud-init, which applied the baseline from a seed
at each container's first boot. Proxmox VE gives a container no
user-data, and `pct create` already sets its network, hostname and
host keys, so cloud-init was left with three actions: place sshd's
drop-in, run the first upgrade, record the version. A fleet built
earlier bakes the baseline into the archive instead, and Hostwarden
could not build that, since only a guest that has never run may get
sshd's login options, and the build container runs.

## Decision drivers

- The sshd rule stays as it is.
- A container starts lean: no cloud-init, a shorter first boot.
- One archive, identical on every node, identified by a checksum.
- A template built elsewhere is usable without a rebuild.

## Considered options

### Bake in all but the login and first upgrade — chosen

Packages, SSH user, updates, journal and timezone go into the
archive. The drop-in and keys sit as inert files, and a first-boot
unit places them before sshd starts; a second unit upgrades and
records the version. The login unit is required by sshd, so a
failure leaves no sshd, not a wrong login. Against it: the scripts
are Hostwarden's own code for each family.

### Keep cloud-init in the template

The path that existed. The shared seed cannot carry a guest's CA
trust or a password anyway, and Proxmox VE owns what cloud-init
would configure. Lost: its weight in every container, for three
actions.

### Write the drop-in into the build container

Rejected: the build container runs, so that changes a running sshd,
which the rule and the guard forbid.

## Decision

The Proxmox VE container template is baked with two first-boot
units, systemd or OpenRC, for Debian and Ubuntu, the RHEL family
from release 9, openSUSE and Alpine; other distributions get
adoption or a VM. Incus, LXD and classic LXC keep cloud-init. A
template built elsewhere is measured by reading its archive and
adopted.

## Consequences

`references/proxmox-template.md` and `firstboot/` carry the build,
`references/adopt-template.md` the adoption, `rules/baseline.md` →
Rendered Versions the `<family>-bake-<n>/` directory and
`rules/appliance/proxmox-ve.md` → Guests the line with the
checksum. The guard needs no new rule.

## Confirmation

A proposal to write the sshd drop-in or a key into the build
container, or to run the login unit on a container that has started
once, is the moment to reread this record.
