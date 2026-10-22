# EFI Boot Management

Cross-OS rules for EFI boot management, dual-boot
setups, and boot loader configuration. The guard
blocks the commands that write boot entries, the
boot order or a boot loader, so those run behind the
skill's gate, with the guard off toward the host
(SKILL.md → Boot writes are behind the gate); the
blocks below that run one of them carry `guard-off`
and run only once the operator relaunched with
`HOSTWARDEN_GUARD_DISABLE` set to that host. These
rules say what to change and in which order.

## Safety

- **Prefer BootNext** (one-shot) over BootOrder
  changes for testing.
- **Never delete boot entries** without asking the
  user first.
- **Verify before changing** — always show current
  state before modifying.
- **Keep the current default** until the new OS is
  confirmed working.
- **Make the new entry the default before the old
  system goes** — set, read back, one plain reboot,
  and a boot path that outlives it
  (§"Making the New Entry the Default").
- A wrong BootOrder change can make the system
  unbootable (fixable via EFI shell or rescue, but
  disruptive).

## Inspecting EFI State

### Linux (efibootmgr)

```
efibootmgr -v          # all entries with paths
efibootmgr             # summary (BootOrder,
                        # BootCurrent, BootNext)
```

Key fields:
- `BootCurrent` — entry that booted this session
- `BootOrder` — persistent boot priority
- `BootNext` — one-shot override (cleared after use)

### FreeBSD (efibootmgr)

```
efibootmgr -v          # same command, same output
```

FreeBSD's `efibootmgr` has the same interface as
Linux. Install with `pkg install -y efibootmgr` if
missing.

## BootNext (One-Shot Boot)

The safe way to test a new OS or boot loader.
Boots the specified entry exactly once, then
reverts to the normal BootOrder.

```sh guard-off
# Linux
efibootmgr -n XXXX     # XXXX = boot entry number

# FreeBSD
efibootmgr -n XXXX
```

**Always use BootNext for the first boot into a
new OS.** If the new OS fails to boot, the next
reboot returns to the working OS automatically.

## BootOrder (Persistent)

Changes the default boot priority. Riskier than
BootNext — if the new entry doesn't work, the
system may boot into a broken OS repeatedly.

```sh guard-off
# Set new order (comma-separated entry numbers)
efibootmgr -o XXXX,YYYY,ZZZZ
```

**Only change BootOrder after BootNext has
confirmed the new entry works.**

## Making the New Entry the Default

A one-shot boot proves the new entry once, and
the boot after it takes the old default again.
Making the new entry permanent is a step of its
own, with its own proof, and it comes **before
anything removes the old system** — its partition,
its EFI directory, its boot entry. Until then a
plain reboot returns to the old default, so
removing the old system first leaves the default
pointing at nothing: BootNext confirmed, BootOrder
never set, the old partition formatted, and the
next reboot stops in the old loader with nothing
behind it.

1. **Set the default** for the layer the one-shot
   used:

   | One-shot | Permanent |
   |---|---|
   | `efibootmgr -n XXXX` | `efibootmgr -o XXXX,…` |
   | `grub-reboot <entry>` | `grub-set-default <entry>` |
   | `bootctl set-oneshot <id>` | `bootctl set-default <id>` |

   `grub-set-default` only counts with
   `GRUB_DEFAULT=saved` in `/etc/default/grub`;
   otherwise set `GRUB_DEFAULT` there and
   regenerate the config. RHEL and its relatives
   spell the tools `grub2-reboot` and
   `grub2-set-default`.

   A GRUB default counts only in the loader the
   firmware starts. Run the tool in the system
   whose loader that is, or with that loader's
   `--boot-directory`; run from the new system
   without it, the tool edits the new system's own
   environment and the old loader keeps its
   default. Where the firmware starts the old
   loader, `efibootmgr -o` with the new entry
   first is the plain way. `bootctl set-default`
   writes an EFI variable that every system
   shares, but the entry it names must exist for
   the systemd-boot the firmware starts: with a
   separate ESP per system, `bootctl status` shows
   the ESP in use and `efibootmgr -v` the one the
   firmware starts. Where they differ, switch
   the firmware entry to the new system's ESP with
   `efibootmgr -o`; an entry copied onto the old
   system's ESP ties the new system to it. A
   `default` line in `loader.conf` lives on the
   ESP in use and counts there.
2. **Read it back.** `efibootmgr` shows `BootOrder`
   with the new entry first and no `BootNext`;
   `grub-editenv <grubenv of the loader the
   firmware starts> list` shows `saved_entry` and
   no `next_entry` (RHEL: `grub2-editenv`);
   `bootctl status` names the new entry as
   `Default Boot Loader Entry`. For GRUB, also
   read `GRUB_DEFAULT` in that system's
   `/etc/default/grub` and its generated config: a
   stale `GRUB_DEFAULT=0` can still point at the
   old system.
3. **Reboot once without the one-shot** and check
   which system came up. A GRUB or systemd-boot
   default starts through the same firmware entry
   for both systems, so `BootCurrent` cannot tell
   them apart there; read `/etc/os-release`,
   `uname -r` or the root device. With `efibootmgr`
   alone, `BootCurrent` is the new entry. Then
   check that the login works and the services
   run.
4. **Check that the boot path outlives the old
   system.** The loader that starts the new system,
   its configuration and the kernel files it reads
   must live on the new system or on the shared
   ESP. Mounts of the running system do not show
   that; read where the loader looks:
   - GRUB: the stub `grub.cfg` on the ESP names the
     file system it reads, as `search.fs_uuid <uuid>`
     (Debian, Ubuntu) or `search --fs-uuid` (RHEL).
     Compare the UUID with the new system's root or
     `/boot` (`findmnt -no UUID /`, then
     `findmnt -no UUID /boot`, one mount point per
     call). With no stub on the ESP, the prefix sits
     inside the loader image: reinstall it from the
     new system.
   - systemd-boot: the `linux` and `initrd` paths
     of the entry resolve on the ESP or, with a
     separate XBOOTLDR partition, there
     (`bootctl status` shows both). The ESP the
     firmware starts and that partition must each
     be the new system's or one that stays, not
     the old system's.
   - FreeBSD `loader.efi`: the partition UUID it
     boots (`gpart list`, `rawuuid`) or the pool's
     `bootfs` (`zpool get bootfs`) is the new
     system's.

   A default that still goes through the old
   system's GRUB or `/boot` stops working once that
   is removed: install the new system's own loader
   first, point the firmware at it with
   `efibootmgr -o`, and repeat steps 2 and 3.
5. **Only then** remove the old system.

## Boot Loaders

### systemd-boot

- Best choice for Linux on ARM64 and UEFI systems.
- Simple, reliable, no BIOS/CSM compatibility
  baggage.
- Config: `/boot/efi/loader/loader.conf` (or
  `/efi/loader/loader.conf` depending on mount).
- Entries: `/boot/efi/loader/entries/*.conf`
- Install: `bootctl install`
- Update: `bootctl update`
- Status: `bootctl status`
- Entry format:
  ```
  title   Debian 13
  linux   /vmlinuz
  initrd  /initrd.img
  options root=UUID=... rw
  ```

### GRUB (EFI)

- Works on x86_64 UEFI systems.
- **Does NOT work on ARM64/QEMU/UTM.** GRUB's
  ARM64 EFI support is unreliable in virtual
  machines — it fails silently or hangs.
  Use systemd-boot instead.
- Config: `/boot/grub/grub.cfg` (generated)
- Update: `update-grub` (Debian) or
  `grub2-mkconfig -o /boot/grub2/grub.cfg` (RHEL)
- Install to EFI: `grub-install --target=arm64-efi`
  (do not use on ARM64 VMs)

### FreeBSD Loader

- FreeBSD's native EFI boot loader.
- Binary: `/boot/loader.efi`
- Default EFI path: `/efi/freebsd/loader.efi` or
  `/efi/boot/bootaa64.efi` (ARM64) /
  `/efi/boot/bootx64.efi` (x86_64)
- Config: `/boot/loader.conf`
- The loader can also be installed as the default
  EFI boot entry at `/efi/boot/boot*.efi`.

## GRUB ARM64/QEMU Warning

**GRUB does not work reliably on ARM64 virtual
machines (UTM, QEMU).** This includes both aarch64
Linux guests and FreeBSD guests.

Symptoms:
- GRUB installs without errors but fails to boot
- Black screen or immediate reboot
- EFI shell drops to prompt instead of booting

**Use systemd-boot for Linux on ARM64 VMs.** For
FreeBSD, use the native FreeBSD loader.

## EFI System Partition Layout

The EFI System Partition (ESP) is typically the
first partition, formatted as FAT32, mounted at
`/boot/efi` (Linux) or `/boot/msdos` (FreeBSD).

Recommended layout for dual-boot:
```
/efi/
├── boot/
│   └── bootaa64.efi    # default fallback
├── freebsd/
│   └── loader.efi      # FreeBSD loader
├── systemd/
│   └── systemd-bootaa64.efi
├── loader/
│   ├── loader.conf     # systemd-boot config
│   └── entries/
│       ├── debian.conf
│       └── freebsd.conf
├── vmlinuz             # Linux kernel
└── initrd.img          # Linux initramfs
```

Both OSes share the same ESP. Each boot loader
gets its own subdirectory.

## Dual-Boot Considerations

- **Shared ESP:** Both OSes use the same EFI
  partition (typically p1). Do not create separate
  ESPs.
- **Boot entry per OS:** Create a separate EFI boot
  entry for each OS using `efibootmgr -c`.
- **systemd-boot menu:** Can include entries for
  both Linux and FreeBSD (chain-load FreeBSD's
  `loader.efi`).
- **FreeBSD entry in systemd-boot:**
  ```
  title   FreeBSD
  efi     /efi/freebsd/loader.efi
  ```
- **Default OS:** Set via BootOrder after both OSes
  are confirmed working.

## Kernel Updates with systemd-boot

systemd-boot does not auto-detect new kernels like
GRUB does. After a kernel update, copy the new
kernel and initramfs to the ESP manually:

```
command cp /boot/vmlinuz-* /boot/efi/debian/vmlinuz
command cp /boot/initrd.img-* /boot/efi/debian/initrd.img
```

If the boot entry uses specific filenames, update
the entry file in `/boot/efi/loader/entries/` to
match. Consider setting up a pacman/apt hook to
automate this.

## Display Issues on ARM64 VMs

On ARM64 virtual machines (UTM/QEMU), the boot
loader or early kernel may not produce visible
console output. This does not mean the boot failed.

- systemd-boot menu may not display — it still
  works, just boots the default entry silently.
- FreeBSD loader menu may not display on serial
  console.
- Add `console=ttyAMA0` (Linux) or configure
  serial console in `loader.conf` (FreeBSD) if
  console output is needed.

## QEMU Cross-OS Installation and EFI

When using QEMU to install a new OS (see
`references/os-replacement-offline-rootfs.md`
§ "QEMU as a Cross-OS Chroot Alternative"), the
QEMU VM's EFI is separate from the real hardware's
EFI NVRAM.

**QEMU cannot update the real EFI NVRAM.** Boot
entries created inside QEMU only exist in QEMU's
virtual NVRAM and are lost when QEMU shuts down.

**The real EFI NVRAM still has the old OS's boot
entries.** After the QEMU installation, the
firmware will try the old entry first (e.g.
`EFI/debian/grubx64.efi`). If that file was
deleted during installation, the firmware should
fall back to `EFI/BOOT/BOOTX64.EFI` — but some
firmware implementations do not fall back
reliably.

**Before rebooting into the new OS:**

1. **Always install the new boot loader at the
   fallback path** `EFI/BOOT/BOOTX64.EFI` (x86_64)
   or `EFI/BOOT/BOOTAA64.EFI` (ARM64). This is
   the EFI standard fallback that firmware uses
   when no boot entry matches.
2. **Use `efibootmgr` from the tmpfs rescue** (or
   the old OS before it's destroyed) to create a
   new boot entry and update BootOrder:
   ```sh guard-off
   efibootmgr -c -d /dev/sda -p 1 \
     -l '\EFI\freebsd\loader.efi' \
     -L "FreeBSD"
   efibootmgr -o XXXX   # new entry first
   ```
3. **Prefer BootNext** for the first boot into the
   new OS (see §"BootNext" above).
4. **Delete old boot entries** only after the new
   OS is confirmed working, has come up once as
   the default and boots without the old system's
   files (§"Making the New Entry the Default").

If `efibootmgr` is not available in the rescue
environment, rely on the fallback path and verify
that the firmware finds it.

**When relying on the fallback path:** deleting
the old OS's EFI directory (e.g. `EFI/debian/`)
makes the firmware's stale boot entries fail
fast and fall through to the fallback. This is
acceptable ONLY when the old root filesystem has
already been destroyed — there is nothing left
to fall back to — and even then, ask the user
first (see §"Safety"). While the old OS is still
intact and bootable, keep its loader; it *is*
the fallback (see `references/os-replacement.md`
§"Boot Configuration Safety"). Once the old root
is gone, leftover EFI files are a hazard: the
firmware may try the old boot loader (which
fails because the root partition is gone) and
may not fall through to the fallback depending
on implementation. In that case, clean the EFI
partition from within the QEMU install shell
before shutting down QEMU.

## Memory Convention

When recording boot configuration in machine memory:
```
- Boot: EFI (systemd-boot)
- Boot: EFI (FreeBSD loader)
- Boot: EFI dual-boot (systemd-boot + FreeBSD)
```
