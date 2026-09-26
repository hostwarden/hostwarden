# Replacing an OS with no console

Reached from `references/os-replacement.md` § Installation, when
nobody can reach the machine physically and it has no out-of-band
console. Two ways in, and the reason a third obvious one does not
work.

Read `references/os-replacement.md` first: the inventory, the
boot-order rules and the checklist apply here unchanged.

Blocks fenced `guard-off` below run only once the operator
relaunched with `HOSTWARDEN_GUARD_DISABLE` set to the host the disk writes run
on in the environment — `SKILL.md` § The gate, step 4.

## SSH-Only Replacement via Hot-Migration

When no console, IPMI, or rescue mode is available
and the server uses ZFS, LVM, or btrfs, use
hot-migration to free the main partition while the
old OS keeps running. This is the safest SSH-only
replacement method because the old OS remains
bootable as a fallback throughout the process.

### Overview

1. **Reclaim swap** — `swapoff` frees the swap
   partition.
2. **Add swap to pool** — add the freed partition
   to the filesystem pool (ZFS, LVM, btrfs).
3. **Evacuate main partition** — hot-remove the
   original root partition from the pool. All data
   migrates to the former swap partition. The old
   OS now runs entirely from the swap partition.
4. **Delete and repartition** — delete the freed
   main partition. Create new partitions: swap +
   new root for the replacement OS.
5. **Install new OS** — write the new OS to the
   new root partition (debootstrap, cloud image
   extraction, etc.) while the old OS is still
   running.
6. **Set up bootloader** — install systemd-boot on
   the EFI partition. See `references/efi-boot.md`.
7. **BootNext for safe first boot** — use
   `efibootmgr -n` (one-shot) so the system tries
   the new OS once. On failure, it automatically
   falls back to the old OS bootloader.
8. **Clean up after confirmation** — once the new
   OS is confirmed working, remove the old OS from
   the swap partition and restore swap.

See `references/partition-staging.md` for hot-migration
details. See `references/efi-boot.md` for BootNext
setup.

### When hot-migration fails

Hot-migration requires the staging partition to
hold all data from the evacuated partition. If the
swap partition is too small (e.g. 2 GB swap, 1.5 GB
ZFS data + metadata overhead), `zpool remove` will
fail with "out of space." In that case, fall back
to the **tmpfs rescue + full-disk dd** method
described below.

## SSH-Only Replacement via Tmpfs Rescue

When hot-migration is not feasible (swap too small,
no volume manager, cross-OS replacement), use a
tmpfs-based rescue environment to keep SSH alive
while overwriting the entire disk with the new OS
image.

### Safety Rules (CRITICAL)

1. **Never overlay system library paths.** Do NOT
   mount tmpfs at `/lib`, `/libexec`, `/bin`, or
   `/sbin` on a live system's chroot. Overlaying
   with an incomplete library set kills the ability
   to fork new processes (including sshd-session),
   permanently locking you out with no recovery
   path.

2. **Build the rescue root from scratch on tmpfs.**
   Create a self-contained root filesystem on a
   tmpfs mount. Every path the rescue sshd and its
   child processes need (`/libexec/ld-elf.so.1`,
   `/lib/*.so.*`, `/bin/*`, `/sbin/*`,
   `/usr/sbin/sshd`, `/etc/ssh/*`, `/etc/passwd`,
   `/etc/pwd.db`, `/etc/spwd.db`, etc.) must exist
   inside the tmpfs root.

3. **Copy libraries using `ldd`, not by copying
   all of `/lib`.** On FreeBSD, `/lib` is ~10 MB
   and can be copied wholesale. On Linux (especially
   with QEMU installed), `/lib` can be 700+ MB —
   too large for tmpfs. Instead, use `ldd` on each
   rescue binary and copy only the specific
   libraries it needs. Missing a library causes
   `sshd-session` to abort, so verify every binary
   works in the chroot before proceeding.

4. **Start the rescue sshd on a new port, then
   VERIFY it works before proceeding.** Connect to
   the new port from a separate terminal. Run a
   test command. Only after confirmation, proceed
   with destructive operations.

5. **Never kill the original sshd until the rescue
   sshd is verified.** The original sshd is your
   last lifeline. Keep it running until you have
   confirmed the rescue sshd accepts connections
   and runs commands.

6. **Never `umount -l /` (lazy-unmount root).**
   Lazy-unmounting `/` orphans the rescue chroot's
   mountpoint path. Even though the tmpfs and its
   contents survive in memory, the VFS path to the
   chroot root becomes unreachable. New SSH
   connections fail because `sshd-session` cannot
   be forked into the chroot — both the rescue
   sshd and the original sshd die. The server
   stays pingable but is permanently locked out.

   **Instead: leave `/` mounted.** The rescue sshd
   runs from tmpfs; it does not need `/` to be
   unmounted. QEMU (or dd) writes to `/dev/sda`
   as a raw block device — this works even while
   the old filesystem is still mounted. The kernel
   caches become stale but that is harmless since
   nothing reads from the old root after pivoting
   to the rescue. Unmount only `/boot/efi` (needed
   for EFI partition changes) and `swapoff`
   (frees the swap partition). The old root on
   `/dev/sdaN` gets overwritten and is gone after
   reboot.

### Building the Tmpfs Rescue Root

```sh guard-off
T=/mnt/tmpfs_rescue
mkdir -p $T
mount -t tmpfs -o size=200m tmpfs $T

# Full directory tree
mkdir -p $T/{bin,sbin,lib,libexec,dev,tmp,mnt,etc}
mkdir -p $T/etc/ssh $T/root/.ssh $T/var/run/sshd
mkdir -p $T/var/empty $T/var/log
mkdir -p $T/usr/{bin,sbin,lib,libexec}

# Copy ALL of /lib (not a subset!)
cp -a /lib/* $T/lib/

# Dynamic linker
cp /libexec/ld-elf.so.1 $T/libexec/

# Binaries (adjust paths for Linux vs FreeBSD)
cp /bin/{sh,dd,mkdir,cp,cat,chmod,ls,rm,mv,ln,df} \
   $T/bin/
cp /sbin/{mount,umount,mdconfig,reboot,sysctl} \
   $T/sbin/
cp /sbin/{mount_msdosfs,newfs_msdos,gpart} \
   $T/sbin/
cp /usr/bin/fetch $T/usr/bin/
cp /usr/sbin/sshd $T/usr/sbin/
cp /usr/libexec/sftp-server $T/usr/libexec/

# Copy any /usr/lib dependencies not in /lib
ldd $T/usr/sbin/sshd $T/usr/bin/fetch \
  2>/dev/null | grep '/usr/lib/' | \
  awk '{print $3}' | sort -u | \
  xargs -I{} cp -n {} $T/usr/lib/

# Auth databases and config
cp /etc/passwd /etc/master.passwd \
   /etc/pwd.db /etc/spwd.db /etc/group \
   $T/etc/
cp /etc/ssh/ssh_host_* $T/etc/ssh/
cp /root/.ssh/authorized_keys \
   $T/root/.ssh/
chmod 700 $T/root/.ssh
chmod 600 $T/root/.ssh/authorized_keys

# Devfs
mount -t devfs devfs $T/dev

# sshd config on a new port
cat > $T/etc/ssh/sshd_config_rescue <<EOF
Port 2223
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_rsa_key
PermitRootLogin yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
UseDNS no
Subsystem sftp /usr/libexec/sftp-server
EOF
```

### Linux (Debian 13+ / OpenSSH 10.x) Adjustments

These paths are version-specific — verify the
binary layout on the actual target (e.g.
`dpkg -L openssh-server | grep sshd`) before
relying on it.

OpenSSH 10.x splits sshd into three binaries.
Copy all three into the chroot:

```
cp /usr/sbin/sshd $T/usr/sbin/
cp /usr/lib/openssh/sshd-session \
   $T/usr/lib/openssh/
cp /usr/lib/openssh/sshd-auth \
   $T/usr/lib/openssh/
cp /usr/lib/openssh/sftp-server \
   $T/usr/lib/openssh/
```

**Critical sshd_config settings for chroot:**

```
UsePAM no          # PAM libraries are not in
                   # the chroot
UseDNS no          # no resolver in chroot
```

Without `UsePAM no`, sshd-auth fails silently
and all logins are rejected.

**nsswitch.conf must use `files` only:**

```
cat > $T/etc/nsswitch.conf << 'EOF'
passwd:         files
group:          files
shadow:         files
hosts:          files
EOF
```

If `nsswitch.conf` references `systemd` (Debian
default), user lookups fail and sshd reports
"invalid user root" even though `/etc/passwd`
is correct.

**The user's login shell must exist in chroot:**

sshd validates that the user's shell (from
`/etc/passwd`) exists. If root's shell is
`/bin/bash`, copy `bash` into the chroot:

```
cp /bin/bash $T/bin/
```

Without it, sshd rejects the login with
"User root not allowed because shell /bin/bash
does not exist."

**Privilege separation directory:**

```
mkdir -p $T/run/sshd
```

OpenSSH 10.x looks in `/run/sshd` (not
`/var/run/sshd`).

**Open the rescue port in the firewall** before
starting the rescue sshd — otherwise the
connection will time out:

```
ufw allow 2223/tcp    # Linux
# or: pfctl rule      # FreeBSD
```

### Additional Rescue Binaries (CRITICAL)

The rescue environment must include tools beyond
sshd. **Verify each binary is present and
functional** after building the rescue — do not
rely on silent `cp ... || true` patterns.

**`efibootmgr` (Linux):**

Required for creating boot entries and setting
BootNext. Copy the binary AND all its shared
libraries:

```
cp /usr/sbin/efibootmgr $T/usr/sbin/
ldd /usr/sbin/efibootmgr 2>/dev/null | \
  grep -oP '/\S+\.so\S*' | while read lib; do
    dir=$(dirname "$lib")
    mkdir -p "$T$dir"
    cp -n "$lib" "$T$lib" 2>/dev/null
  done
# Verify:
chroot $T /usr/sbin/efibootmgr --version
```

Without `efibootmgr`, you cannot set BootNext and
must rely on the EFI fallback path
(`EFI/BOOT/BOOTX64.EFI`), which is less reliable.

**`reboot`:**

On Linux, `reboot` links against `libsystemd`,
which is large and complex. The chroot's `reboot`
will fail with missing library errors. Alternatives:

1. **SysRq (preferred):** mount `/proc` in the
   chroot, then:
   ```sh guard-off
   echo 1 > /proc/sys/kernel/sysrq
   echo s > /proc/sysrq-trigger   # sync
   sleep 1
   echo u > /proc/sysrq-trigger   # remount ro
   sleep 1
   echo b > /proc/sysrq-trigger   # reboot
   ```
2. **Copy a static `reboot`** (e.g. from busybox).
3. Use `kill -TERM 1` to ask init to reboot (may
   not work from chroot).

**Warning:** On virtual machines (UTM/QEMU), SysRq
`b` may power off the VM instead of rebooting it.
The hypervisor decides whether to restart the guest.
If the VM does not come back after SysRq reboot,
the user must start it manually from the
hypervisor console.

**QEMU and ROM files (when using QEMU inside
rescue):**

If QEMU is included in the rescue for cross-OS
installation, copy ROM files alongside the binary:

```
mkdir -p $T/usr/share/qemu
cp /usr/share/seabios/vgabios-stdvga.bin \
   $T/usr/share/qemu/
cp /usr/share/seabios/vgabios.bin \
   $T/usr/share/qemu/
cp /usr/share/seabios/bios-256k.bin \
   $T/usr/share/qemu/
cp /usr/share/qemu/efi-virtio.rom \
   $T/usr/share/qemu/
cp /usr/share/qemu/kvmvapic.bin \
   $T/usr/share/qemu/
```

Without these, QEMU fails at startup with
"failed to find romfile" errors.

### Starting and Verifying the Rescue sshd

```
chroot $T /usr/sbin/sshd \
  -f /etc/ssh/sshd_config_rescue

# === STOP. Verify from a second terminal: ===
# ssh -p 2223 root@hostname "id && echo OK"
# Only proceed after "OK" is confirmed.
```

### Streaming the New OS Image

**Verify the image before it touches the disk.**
Fetch the published SHA256/checksum file from the
project's official site and verify the download.
Prefer download-then-verify when staging space
allows:

```
fetch -o /mnt/staging/image.raw \
  "https://url/to/image.raw"
sha256 /mnt/staging/image.raw   # FreeBSD
sha256sum /mnt/staging/image.raw  # Linux
# compare against the published checksum
```

When the image must be streamed directly to disk
(no space to stage it), verify the published
checksum out-of-band first and tell the user the
residual risk: a corrupted or tampered transfer
is only detected after the disk is already
overwritten.

**POINT OF NO RETURN.** The dd overwrites the
disk; the old OS is unrecoverable afterwards.
Get a final explicit user confirmation
immediately before running it.

After rescue sshd is verified, connect via the
rescue port and stream the image to disk:

```sh guard-off
sysctl kern.geom.debugflags=0x10   # FreeBSD only
fetch -o - "https://url/to/image.raw" | \
  dd of=/dev/vtbd0 bs=1M
```

All processes run from tmpfs — the disk overwrite
does not affect them.

### Post-dd EFI Partition Modification

After the dd, the disk has the new OS layout but
GEOM still caches the old partition table. To
modify the new EFI partition from tmpfs:

```sh guard-off
# Copy EFI partition to a memory-backed device
mdconfig -a -t swap -s 130m -u 1
dd if=/dev/vtbd0 bs=512 skip=EFI_START \
   count=EFI_SECTORS of=/dev/md1
mount -t msdosfs /dev/md1 /mnt/efi

# Modify GRUB config, add systemd-boot, etc.

umount /mnt/efi
dd if=/dev/md1 of=/dev/vtbd0 bs=512 \
   seek=EFI_START count=EFI_SECTORS
mdconfig -d -u 1
```

Replace `EFI_START` and `EFI_SECTORS` with the
values from the cloud image's partition table
(inspected before the dd).

### SSH Access for Cloud Images

Cloud images (nocloud variant) boot with root
console login but no SSH key. To inject SSH access
when the rootfs is ext4 (unmountable from FreeBSD),
use QEMU to configure the image before writing it
to disk. See `references/os-replacement-offline-rootfs.md`
§ "QEMU as a Cross-OS Chroot Alternative".

If QEMU is not available, try mounting the image's
ext4 partition from FreeBSD (`mount -t ext2fs`).
Modern ext4 features often prevent this, but some
images work. If it mounts, inject
`/root/.ssh/authorized_keys` directly.

## Why dd-to-Live-Disk Fails

**Never dd a full disk image over the running
system's own disk.** This approach is tempting but
fails catastrophically:

- The running OS crashes when its root filesystem
  is overwritten mid-write. Buffers, metadata, and
  open files become inconsistent instantly.
- If dd does not complete (crash, I/O error, power
  loss), the disk is left in an inconsistent state
  — partially old OS, partially new image. The
  server is bricked with no recovery path.
- Even if the entire image is cached in RAM, the
  reboot command may not execute after the
  filesystem corruption that dd causes. The kernel
  panics or hangs instead of rebooting.
- On ZFS or other CoW filesystems, overwriting the
  underlying device corrupts pool metadata first,
  causing an immediate pool fault before dd
  finishes.

**Use hot-migration instead:** keep the old OS
running on a different partition while the new OS
is written to the freed partition. The old OS
remains intact as a fallback at every step.

**Exception:** dd to the live disk IS safe when a
fully self-contained tmpfs rescue environment is
running (see §"SSH-Only Replacement via Tmpfs
Rescue"). The rescue sshd and all its binaries
live in RAM — the disk overwrite does not affect
running processes. The old OS is lost, so a backup
is mandatory.
