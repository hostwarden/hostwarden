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

Decided 2026-09-29 for `hostwarden-new-guest`. The template for
containers on Proxmox VE carried cloud-init, and
every container applied the baseline from a seed at its first
boot. Proxmox VE gives a container no user-data, and `pct create`
already sets its network, hostname and `/etc/hosts` and writes new
SSH host keys, so the seed switched those parts of cloud-init off.
What cloud-init still did was three things: place sshd's drop-in,
run the first upgrade and record the version.

A user's fleet, run by Heinzel before, builds the other way: the
baseline baked into the archive, no cloud-init, every guest made
with `pct create` from it. Hostwarden could not build that
template, because the sshd rule in `AGENTS.md` → Critical Safety
Rules allows only the first-boot configuration of a guest that
has never run to set sshd's login options and keys, and the build
container runs.

## Decision drivers

- Keep the sshd rule as it is: nothing writes to a running sshd
  or to a key, in the build container least of all.
- A container should start lean: no cloud-init, a shorter first boot.
- One rendering that the archive's checksum identifies, identical
  on every node.
- A template somebody else built and measured against the baseline
  should be usable without a rebuild.

## Considered options

### Bake in all but the login and first upgrade, two units — chosen

The archive carries the packages, the SSH user and its sudo rule,
unattended upgrades, the journal and the timezone. The drop-in and
the keys sit as inert files in a directory of their own, and a
unit placed there moves them into place before sshd first starts,
in the container made from the archive. A second unit runs the
upgrade and records the version. Each skips itself once its
marker exists, and the login unit is a requirement of sshd, so a
failed login leaves a container with no sshd instead of one with
the wrong one. Against it: the units and scripts are Hostwarden's
own code to keep correct for each family, and each family it serves is a recipe
to verify on a real container.

### Keep cloud-init in the template

The path that existed. Its per-container reach is limited anyway:
the shared seed cannot carry a guest's CA trust or a password, and
Proxmox VE owns what cloud-init would otherwise configure. Lost:
the weight it adds to every container, for three actions.

### Write the drop-in into the build container

The whole baseline baked. Rejected: the build container runs, so
that is a change to a running sshd, which the rule and the guard
forbid, and it leaves the same host keys and login in every guest
that a template must never carry.

## Decision

The Proxmox VE container template is baked with two first-boot units, replacing
the cloud-init template, for every family that has a family file and a baseline
recipe under `rules/os/`: Debian and Ubuntu, the RHEL family from release 9
(not Fedora), openSUSE and Alpine, on systemd or OpenRC. The admin picks any
official template of those. A
distribution with no family file (Arch, Gentoo, Devuan) has no baseline to bake
and is offered adoption or a VM instead. Classic
LXC and Incus/LXD stay on cloud-init: Incus and LXD hand user-data
over natively, and classic LXC has no template workflow to justify
a second one. A template that Hostwarden did not build is measured
against the baseline by reading its archive, and adopted when the
user agrees.

## Consequences

`hostwarden-new-guest`'s `references/proxmox-template.md` and the
files under `firstboot/` carry the build; `references/adopt-template.md`
the adoption; `rules/baseline.md` → Rendered Versions the
`<family>-bake-<n>/` directory; `rules/appliance/proxmox-ve.md` →
Guests the memory line with its checksum. The guard needs no new
rule: the build writes nothing that reaches sshd's configuration
or a key.

## Confirmation

A proposal to write the sshd drop-in or a key into the build
container, or to make the login unit run on a container that has
started once, is the moment to reread this record.
