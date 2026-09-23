# OS Replacement

Replacing one OS with another on the same server
(wipe and reinstall).

This is NOT dual-boot — the old OS is removed
entirely. See `references/dual-boot.md` for running
two OSes side by side.

## Prerequisites

The four-part gate in `SKILL.md` holds before the first
disk write — explicit request, understood loss, verified
backup, the taboo guard disabled by the operator.
Boot-entry changes are not part of it; see
`references/efi-boot.md` and § Boot Configuration Safety
below.

One more thing this workflow needs that the gate does
not cover: **inventory the current system** before
anything is wiped. The next section says what to
capture.

## Pre-Replacement Inventory

Gather and save this information from the running
system before it is wiped. Store it in
`memory/servers/<hostname>/pre-replacement.md`.

### System Facts

- OS, version, architecture
- Partition layout (`lsblk`, `gpart show`,
  `zpool status`)
- Filesystem types and mount points
- Bootloader type (GRUB, systemd-boot, FreeBSD
  loader)

### Network Configuration

- IP addresses (static or DHCP)
- Gateway, DNS servers
- Interface names and bonding/VLAN config
- Firewall rules (export full ruleset)
- `/etc/hosts` entries
- WireGuard or VPN configs

### Installed Services

- List all enabled services
  (`systemctl list-unit-files --state=enabled`,
  `sysrc -e -a | grep -E '^[A-Za-z0-9_]+_enable='`)
- For each service: config files, data directories,
  listening ports
- Database dumps (PostgreSQL, MySQL, etc.)
- Web server configs (sites, SSL certs)
- Cron jobs (`crontab -l`, `/etc/cron.d/`)

### User Accounts

- System users with login shells
- SSH authorized keys
- sudo/doas configuration
- Home directory contents (if relevant)

### Package List

- Explicitly installed packages
  (`apt-mark showmanual`, `pkg info -o`,
  `dnf history userinstalled`)
- Custom repositories

### Certificates

- SSL/TLS certificates and keys
  (`/etc/letsencrypt/`, `/usr/local/etc/ssl/`)
- SSH host keys (`/etc/ssh/ssh_host_*`) — save if
  you want to avoid host key change warnings. A host
  certificate (`*-cert.pub`) goes with its key; a new
  key needs a newly signed one
- SSH CA trust: run the Host Certificate and User CA
  Trust probes of `rules/ssh-ca.md` now, whatever the
  host's memory says — a missing `SSH user CA:` line
  proves nothing. They name the CA's public key, the
  principals files and the revocation list. The new
  system gets them at first boot where a user CA of
  the user's covers the host
  (`references/cloud-image.md`, the nocloud image
  steps); without them, certificate logins stop

**Never store private key material anywhere
under the Hostwarden repo.** `pre-replacement.md`
can be git-shared in team mode. Copy keys to a
location outside the repo (e.g.
`~/hostwarden-keys/<hostname>/`) with `0600` file
and `0700` directory permissions, and record
only that path in the inventory file. The
general secrets-handling rule is in
`rules/secrets.md`.

### Config File Backups

Back up all modified config files. Use the backup
procedure from `rules/backups.md`. At minimum:
- `/etc/` (or `/usr/local/etc/` on FreeBSD)
- Firewall config
- Web server configs
- Database configs
- Any custom application configs

## Boot Configuration Safety (CRITICAL)

**Never modify the bootloader or EFI fallback path
until the new OS root filesystem is confirmed
written to disk.**

Violating this rule can brick the server: if the
new root filesystem write fails but the bootloader
already points to it, the system reboots into a
bootloader that references a non-existent root.
With SSH-only access and no console, the server
becomes unrecoverable.

### Mandatory order of operations

1. **Write the new root filesystem first.** Confirm
   the write completed successfully (check exit
   code, verify bytes written).
2. **Verify the new root filesystem.** If possible,
   mount or probe it to confirm it is valid.
3. **Only then modify boot configuration.** Install
   the new bootloader, update EFI entries, or
   change BootOrder/BootNext.
4. **Keep the old bootloader intact as fallback**
   until the new OS is confirmed bootable. Use
   BootNext (one-shot) for the first boot into
   the new OS. See `references/efi-boot.md`
   § BootNext (One-Shot Boot).

### What this means in practice

- Do NOT replace `/efi/boot/bootaa64.efi` (or
  `bootx64.efi`) with a new bootloader before the
  new OS is on disk.
- Do NOT change BootOrder to prioritize the new
  OS before confirming it boots.
- Do NOT remove old boot entries before the new
  OS is confirmed working.
- If the root filesystem write fails (dd error,
  permission denied, I/O error), **stop
  immediately**. Do not reboot. The old OS is
  still intact and bootable — keep it that way.

## Installation

### Method

**Prefer debootstrap** (or the equivalent bootstrap
tool for the target distro) over cloud images
whenever possible. debootstrap produces a clean,
minimal system with full control over installed
packages and configuration. Cloud images carry
cloud-init baggage, may lack `openssh-server`
(nocloud variants), and use GRUB which fails on
ARM64 QEMU/UTM.

Fall back to cloud images only when debootstrap is
not feasible (e.g. no network access from the
server, target distro has no bootstrap tool, or
the user explicitly requests a cloud image).

Choose installation method based on access:

- **Console/IPMI/KVM:** boot from ISO, run
  installer. Most reliable. Which console this host
  has: `rules/management-controller.md` → The rescue
  path.
- **Cloud provider:** use provider's reinstall
  feature or deploy a new image.
- **VM (UTM/QEMU/VMware):** boot from ISO, or use
  debootstrap via rescue/chroot. Cloud images are
  a fallback — see `references/cloud-image.md`.
  **ARM64 QEMU/UTM:** cloud images use GRUB, which
  fails silently on these platforms. Replace GRUB
  with systemd-boot before first boot (see
  `references/efi-boot.md`, `references/cloud-image.md`).
- **SSH-only, no console at all:** see § Doing this
  without a console below.
- **Network install (PXE):** if available in the
  datacenter.
- **In-place via rescue mode:** some providers offer
  a rescue system — boot into it, partition, and
  install via debootstrap or equivalent.

### Partition Planning

- Reuse the existing partition layout if it was
  working well.
- Keep the EFI partition if present (reformat only
  if necessary).
- Match or exceed previous partition sizes for
  services that will be restored.

### Freeing Partitions for Staging

Read `references/partition-staging.md` for the full
strategy. Key techniques:

1. **Reclaim swap** — `swapoff` frees a partition
   for staging (images, backups, debootstrap).
2. **Hot-migrate** — on ZFS, LVM, or btrfs, add
   the freed swap to the pool, migrate data off
   the original partition, remove it. Now the
   original partition is free for the new OS.

Always check RAM before disabling swap (free RAM
after absorbing used swap must be >= 512 MB).

### Static IP

Configure the same IP address the old OS used.
The server's DNS records and firewall rules on
other servers depend on this IP staying the same.

## Post-Replacement Checklist

After the new OS is installed and accessible:

1. [ ] SSH access works
2. [ ] OS detected and server memory updated
3. [ ] Hostname set correctly
4. [ ] Network configured (same IP as before)
5. [ ] Firewall installed and configured
6. [ ] Automatic security updates enabled
7. [ ] SSH host keys restored (optional — avoids
       host key warnings for other users/scripts)
8. [ ] User accounts and SSH keys restored; SSH CA
       trust in place, and a host certificate for the
       new host keys handed to the user to sign,
       where the host had them (`rules/ssh-ca.md`)
9. [ ] Services reinstalled and configured
10. [ ] Data restored (databases, web content, etc.)
11. [ ] SSL certificates restored or renewed
12. [ ] Cron jobs restored
13. [ ] Firewall rules match pre-replacement config
14. [ ] All services tested and running
15. [ ] GPT partition types match the new OS
        (see `references/partition-type-codes.md`)
16. [ ] `pre-replacement.md` reviewed — nothing
        missed
17. [ ] Changelog entry logged
18. [ ] `pre-replacement.md` deleted after
        everything is confirmed working

## Doing this without a console

When nobody can reach the machine and it has no out-of-band
console — which `rules/management-controller.md` → The rescue
path settles, rather than the user being asked again — the
installation methods above are not available. Two references
carry those paths:

- `references/os-replacement-ssh-only.md` — a same-family
  target: getting a rescue environment running over SSH and
  writing the new system from it (hot-migration, the tmpfs
  rescue root, and why writing straight to the live disk does
  not work).
- `references/os-replacement-mfsbsd.md` — a FreeBSD target,
  which has its own RAM-booted rescue image.

Everything in this file still applies to them: the inventory, the
boot-order rules, the checklist.

## Cross-Family Considerations

When switching OS families (e.g. RHEL → Debian,
FreeBSD → Linux):

- **Package names differ.** `httpd` (RHEL) vs
  `apache2` (Debian) vs `apache24` (FreeBSD).
- **Config paths differ.** `/etc/nginx/` (Linux) vs
  `/usr/local/etc/nginx/` (FreeBSD).
- **Service managers differ.** systemd (Linux) vs
  rc.d (FreeBSD).
- **Firewall tools differ.** ufw/firewalld (Linux)
  vs pf (FreeBSD).
- **Config file syntax may differ** between
  versions of the same software on different
  distros. Don't blindly copy configs — review
  and adapt.

Read the rule file for the new OS family before
restoring services.

## Memory Updates

After replacement:
- Update `memory.md` with the new OS, services,
  and configuration.
- Keep the changelog — add an entry for the OS
  replacement.
- Delete `pre-replacement.md` once everything is
  confirmed working.
