# Filling a root filesystem you cannot boot

Reached from `references/os-replacement-ssh-only.md` once a target
filesystem exists but nothing can run inside it yet — no chroot,
because the binaries are for the wrong architecture or the wrong
OS. Two ways to populate it, whichever the surrounding workflow
needs.

Blocks fenced `guard-off` below run only once the operator
relaunched with `HOSTWARDEN_GUARD_DISABLE=1` in the
environment — `SKILL.md` § The gate, step 4.

## QEMU as a Cross-OS Chroot Alternative

When the old and new OS are entirely different
(e.g. FreeBSD → Linux), `chroot` into the new
rootfs does not work — the running kernel cannot
execute binaries built for a different OS. Manual
package extraction (see next section) is one
workaround, but it is tedious and error-prone
because every postinst script must be replicated
by hand.

**Install QEMU on the old OS** and use it to boot
the new rootfs in a lightweight VM instead:

1. Install QEMU (`pkg install qemu` on FreeBSD,
   `apt-get install qemu-system-aarch64` on
   Debian, etc.).
2. Boot the new rootfs partition or image directly
   in QEMU, passing the real disk/partition as a
   block device.
3. Inside the QEMU VM, the new OS runs its own
   kernel — `dpkg`, `apt`, `chroot`, `useradd`,
   and all postinst scripts work normally.
4. Install and configure packages, generate SSH
   host keys, enable services, set up users — all
   with the real package manager.
5. Shut down the VM. The rootfs on the partition
   is now fully configured and ready to boot
   natively.

**Prefer manual shell installation over interactive
installers.** Dialog-based installers (FreeBSD's
bsdinstall, Debian's d-i) use escape sequences for
cursor movement that break when sent through serial
pipes. Instead: boot the ISO to a live shell, then
partition, extract, and configure manually. For
FreeBSD: boot the installer ISO, exit to "Live
System" or login at the console, then use `gpart`,
`newfs`, `tar` to install by hand.

### When to prefer QEMU over manual extraction

- The new OS needs many packages installed or
  configured (manual extraction does not scale).
- Package postinst scripts are complex (e.g.
  `initramfs-tools`, kernel hooks, `dbus`
  machine-id generation).
- Same architecture but different OS kernel
  (e.g. FreeBSD aarch64 → Linux aarch64). QEMU
  uses KVM/HVF when available (near-native speed)
  or TCG software emulation (slow but functional
  — expect 5–15 minutes for a debootstrap).

### When manual extraction is still fine

- Only a few packages are needed (e.g. just
  `openssh-server`).
- The rootfs comes from a cloud image that already
  has most packages pre-installed.
- QEMU is not available or cannot be installed on
  the old OS.

### QEMU Serial Console for Headless Use

When running QEMU over SSH (no graphical display),
the guest OS console must be routed to a serial
port that you can read and write.

**Required QEMU flags:**

```
qemu-system-x86_64 \
  -nographic \
  -monitor tcp:127.0.0.1:4445,server,nowait \
  -cpu max \
  ...
```

- `-nographic` removes the VGA adapter and
  redirects the BIOS, boot loader, and serial
  console to stdio. **Without this, the boot
  loader and kernel output go to an invisible
  virtual VGA and the serial port stays empty.**
- `-monitor tcp:...` puts the QEMU monitor on a
  separate TCP port so `sendkey` commands can be
  sent without interfering with stdio.
- Do **not** use `-vga none -display none` with a
  separate `-serial chardev:socket` — the boot
  loader still uses VGA BIOS calls (INT 10h) and
  its output will go nowhere.

**Keeping stdin writable (for interactive guests):**

When QEMU reads from stdin (via `-nographic`), it
must have a writable file descriptor. If stdin is
`/dev/null`, the guest receives EOF and cannot
accept typed input on the serial console.

Use a named pipe with a persistent writer:

```
mkfifo /tmp/qemu_in
sleep 86400 > /tmp/qemu_in &
qemu-system-x86_64 ... -nographic \
  < /tmp/qemu_in > /tmp/qemu_out.log 2>&1 &
```

Send input to the guest serial:
`printf "command\n" > /tmp/qemu_in`

Read output: `tail /tmp/qemu_out.log`

**Sending keystrokes via the QEMU monitor:**

The `sendkey` command sends PS/2 keyboard events
to the guest, independent of serial. Use it to
interact with boot menus that read from keyboard
(e.g. FreeBSD's boot loader menu before switching
to `comconsole`):

```
exec 3<>/dev/tcp/127.0.0.1/4445
echo "sendkey 3" >&3   # press "3"
echo "sendkey ret" >&3  # press Enter
exec 3>&-
```

Note: after the guest switches console to serial
(e.g. FreeBSD `set console="comconsole"`), the
boot loader reads from serial, not keyboard.
Further input must go through the FIFO, not
`sendkey`.

**FreeBSD-specific console setup:**

The FreeBSD boot loader defaults to `vidconsole`
(VGA). To get output on serial:

1. At the boot menu, press `3` (Escape to loader
   prompt) — send via `sendkey` since the menu
   reads from keyboard.
2. Type `set console="comconsole"` — send via
   `sendkey` (still on keyboard). Each character
   must be sent individually:
   ```
   for key in s e t spc c o n s o l e \
     equal shift-apostrophe c o m c o n \
     s o l e shift-apostrophe; do
     echo "sendkey $key" >&3
     sleep 0.15
   done
   echo "sendkey ret" >&3
   ```
3. Type `boot` — send via the FIFO (the loader
   now reads from serial after the console switch).

**Timing is critical.** The boot menu has a
10-second default timeout. Send `sendkey 3` within
5 seconds of QEMU starting the ISO boot. If the
timeout expires, the kernel boots with VGA as
primary. The serial console still receives kernel
messages and the installer dialog (with escape
sequences), so interaction is possible but fragile.

**If you miss the boot menu:** The installer still
outputs to serial as secondary console. Accept the
terminal type prompt (press Enter via FIFO for
vt100 default), then use Tab + Enter to navigate
to "Shell" in the installer menu.

Or pre-configure `console="comconsole"` in
`/boot/loader.conf` for subsequent boots.

**TCG (software emulation) performance:**

Without KVM/HVF, QEMU uses TCG. Expect:
- FreeBSD kernel boot: 3–8 minutes
- base.txz extraction (~170 MB): 5–10 minutes
- RSA 4096-bit key generation: 1–3 minutes

Budget at least 20 minutes for a full FreeBSD
installation under TCG.

### QEMU Device Name Mapping (CRITICAL)

**Device names inside QEMU do not match the real
hardware.** The QEMU virtual disk uses virtio
(`vtbd0` in FreeBSD, `vda` in Linux), but the
real server's disk controller determines the
native device name.

| Controller     | Linux    | FreeBSD   |
|----------------|----------|-----------|
| SATA / AHCI    | `sda`    | `ada0`    |
| virtio-blk     | `vda`    | `vtbd0`   |
| virtio-scsi    | `sda`    | `da0`     |
| NVMe           | `nvme0n1`| `nvd0`    |
| IDE            | `sda`    | `ada0`    |

**Before launching QEMU, record the real device
names** from the running OS:

```
# Linux — check the block device name
lsblk -o NAME,TRAN   # TRAN column shows: sata,
                      # nvme, virtio, usb
```

If Linux shows `sda` with transport `sata`, the
FreeBSD device name will be `ada0`. If it shows
`vda` with transport `virtio`, it's `vtbd0`.

**After the QEMU installation, fix all device
references** before rebooting:

- `/etc/fstab` (FreeBSD) — replace `vtbd0` with
  the real device name (e.g. `ada0`)
- `/etc/fstab` (Linux) — replace `vda` with the
  real name (e.g. `sda`)
- `/boot/loader.conf` `vfs.root.mountfrom` — set
  this explicitly with the real device name
- Any scripts or configs referencing device paths

**Always set `vfs.root.mountfrom` in
`/boot/loader.conf`** with the real device name:

```
# In /boot/loader.conf (using real device name):
vfs.root.mountfrom="ufs:/dev/ada0p3"
# Console — see rules/freebsd.md §Console:
console="vidconsole"  # x86_64 UTM/QEMU or VGA
# console="efi"       # ARM64 UTM/QEMU only
```

**Console must match the target platform, not QEMU.**
When installing FreeBSD via QEMU for a target that
boots natively, the console in loader.conf must
match the real hardware (e.g. `efi` for a UTM VM,
`vidconsole` for physical server). See
`rules/freebsd.md` §"Console Configuration".

Without it, the loader guesses root from
`currdev`, which may resolve differently between
QEMU and real hardware. An explicit
`vfs.root.mountfrom` eliminates guesswork.

**The FreeBSD boot loader auto-detects `currdev`**
from the EFI boot path, so the kernel will mount
root correctly even with wrong fstab. But `fsck`
and `mount -a` during multi-user boot will fail
if fstab has the wrong device names, potentially
dropping to single-user mode.

### Post-Extraction Verification (MANDATORY)

After extracting the new OS (base.txz, kernel.txz,
debootstrap, cloud image, etc.), **always verify
critical files exist** before proceeding:

**FreeBSD:**
```
# All of these must exist:
ls /mnt/boot/kernel/kernel      # kernel binary
ls /mnt/boot/lua/loader.lua     # boot loader
                                # scripts (14.x+)
ls /mnt/boot/loader.conf        # loader config
ls /mnt/etc/passwd               # user database
ls /mnt/etc/rc.conf              # service config
ls /mnt/usr/sbin/sshd            # SSH server
```

**Linux (Debian):**
```
ls /mnt/boot/vmlinuz-*           # kernel
ls /mnt/boot/initrd.img-*        # initramfs
ls /mnt/etc/fstab                # mount table
ls /mnt/usr/sbin/sshd            # SSH server
```

If any critical file is missing, **stop and
re-extract.** Do not reboot. A common cause is
tar truncation errors — re-download and re-extract
the archive.

**FreeBSD 14.x+:** The boot loader uses Lua
scripts in `/boot/lua/`. If `/boot/lua/loader.lua`
is missing, the loader drops to an `OK` prompt
instead of booting the kernel. This is a fatal
extraction failure — re-extract `base.txz`.

## Manual Package Extraction into Offline Rootfs

When installing packages into a rootfs that cannot
be booted yet (e.g. cross-OS replacement via SSH,
where you mount the new root from the old OS),
`dpkg`/`apt`/`pkg` cannot run because the target
architecture or OS doesn't match the running host.
The workaround is to download `.deb` (or equivalent)
packages, extract their file contents, and place
them into the target rootfs manually.

**This bypasses all package manager scripts.** The
following critical steps are skipped and must be
handled manually:

### 1. System Users and Groups

Many services require dedicated system users
(e.g. `sshd` needs the `sshd` user). These are
normally created by the package's postinst script.

**Always check the package's postinst for
`adduser`/`useradd` calls** and create the required
users manually:

```
# Common service users to create:
useradd -r -d /run/sshd -s /usr/sbin/nologin sshd
useradd -r -d /var/lib/ntp -s /usr/sbin/nologin ntp
```

Write `useradd` commands directly into the target
rootfs's `/etc/passwd`, `/etc/shadow`, and
`/etc/group` if `chroot` is not possible (different
architecture or OS). Use the next available UID in
the system range (100–999).

### 2. Configuration Files

Package postinst scripts often generate config
files from templates or run `ucf` to manage them.
Copy the default config from the package's
`/usr/share/` directory:

```sh guard-off
# Example: openssh-server
cp <rootfs>/usr/share/openssh/sshd_config \
   <rootfs>/etc/ssh/sshd_config
```

### 3. Systemd Service Enablement

Extracting a `.deb` places the service unit files
in `/lib/systemd/system/`, but does **not** create
the symlinks in `/etc/systemd/system/*.wants/` that
enable the service. Create them manually:

```
ln -sf /lib/systemd/system/ssh.service \
  <rootfs>/etc/systemd/system/\
multi-user.target.wants/ssh.service
```

### 4. State Directories and Permissions

Some services need specific directories with
specific ownership:

```
mkdir -p <rootfs>/run/sshd
```

### Summary Checklist

Before rebooting into a rootfs with manually
extracted packages:

- [ ] All required system users/groups created
- [ ] Config files copied from defaults and
      customized
- [ ] Systemd services enabled via symlinks
- [ ] State/runtime directories created
- [ ] File ownership correct (especially for
      service users)

**If in doubt**, inspect the package's postinst
script. On Debian: download the `.deb`, run
`ar x <package>.deb`, extract `control.tar.*`,
and read the `postinst` file.
