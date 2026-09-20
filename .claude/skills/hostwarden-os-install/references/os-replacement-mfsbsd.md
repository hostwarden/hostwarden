# Cross-OS to FreeBSD over SSH with mfsBSD

Reached from `references/os-replacement.md` § Installation when
the target is FreeBSD and there is no console. mfsBSD boots
entirely from RAM, which is what makes it possible to overwrite
the disk it came from.

Step 4 below writes an image over a whole disk, and nothing
here is a read: `SKILL.md` § The gate holds first, including
the operator having relaunched with
`HOSTWARDEN_GUARD_DISABLE=1` in the environment.

## SSH-Only Cross-OS via mfsBSD

When replacing one OS with a completely different one
over SSH (e.g. Linux → FreeBSD), use **mfsBSD** — a
FreeBSD system that runs entirely from RAM.

### Why mfsBSD

mfsBSD loads the entire OS into a memory filesystem
at boot. Once booted, the disk is completely free —
no mounted filesystems, no page cache dependencies.
The autoinstaller (or manual SSH session) can safely
partition, format, and write to the disk without
risk of crashing the running OS.

**This solves the fundamental problem** of same-disk
replacement: regular installer media (memstick,
disc1 ISO) mount root from the disk. Partitioning
that disk destroys the running system.

**Never use the regular FreeBSD memstick/disc1
installer for same-disk SSH-only replacement.** Any
attempt to partition that disk from rc.local or
`installerconfig` destroys the system it is running
on.

### Pre-built mfsBSD images

Download from https://mfsbsd.vx.sk/:

- **Standard:** minimal FreeBSD in RAM, sshd
  enabled, root password `mfsroot`.
- **Special Edition (SE):** includes `base.txz`
  and `kernel.txz` for installation — no network
  download needed.
- **Mini:** stripped-down with dropbear SSH.

### Lock Down Access BEFORE dd'ing (MANDATORY)

An unmodified mfsBSD image boots with sshd
running, root login enabled, and the *published*
default password `mfsroot`. On a production IP
this is an open door: anyone scanning the
address can log in as root for as long as the
default password is active. Never create that
exposure window.

Before writing the image to disk, do at least
one of:

- **Bake access into the image.** mfsBSD
  supports baked-in configuration: rebuild with
  an authorized SSH key and a changed root
  password (`rootpw`/`rootpw_hash` in the build
  config), or mount the pre-built image and
  inject `authorized_keys` plus a new password
  hash before dd'ing. Prefer key-only access:
  with a key baked in, the password is only a
  console fallback.
- **Restrict at the provider firewall.** Limit
  SSH on that IP to the operator's address until
  the installation is complete, then lift the
  restriction.

### Workflow

1. Build tmpfs rescue on the running Linux (sshd
   only — no QEMU needed).
2. Download the mfsBSD SE image and verify it
   against the published checksum (see
   `references/os-replacement-ssh-only.md`
   § "Streaming the New OS Image").
3. Bake in an SSH key / changed root password,
   or restrict the provider firewall (see
   above).
4. Confirm with the user (point of no return),
   then dd the image to `/dev/sda` from the
   rescue.
5. Reboot.
6. mfsBSD boots into RAM, starts sshd.
7. SSH in as `root` with the key or password you
   baked in, and run the install script:
   partition, format, extract base+kernel,
   configure, set up EFI bootloader.
8. Reboot into the installed FreeBSD.

Step 7 can be fully scripted from the local
machine over SSH key authentication (bake the
key into the image — step 3).

### AutoBSD (repeatable deployments)

For automated, repeatable installations, use
[AutoBSD](https://gitlab.com/btrgk-lab/freebsd/autobsd)
to build custom mfsBSD-based images with
`installerconfig` pre-baked. The built image
auto-installs FreeBSD without any SSH interaction.

AutoBSD requires a FreeBSD system to build images.
Use it for fleet deployments; use raw mfsBSD + SSH
for one-off replacements.
