# GPT partition type codes

Checklist item 15 of `references/os-replacement.md`, run after
the new OS is booted and confirmed working. A partition written
by one OS often keeps the type code of the one before it, which
the new system tolerates until something — a boot loader, an
installer, a rescue image — reads the code instead of the
filesystem.

Reading a type code is a read. Changing one is a partition-table
write, so the gate in `SKILL.md` § The gate holds first,
including the operator having relaunched with
`HOSTWARDEN_GUARD_DISABLE` set to the host the disk writes run on in the
environment.

## GPT Partition Type Codes

When replacing one OS with another, the GPT
partition table retains the old OS's type codes.
For example, replacing FreeBSD with Linux leaves
partitions marked as `freebsd-swap` and
`freebsd-zfs` even though they now contain Linux
swap and ext4. **Always fix partition type codes
after a cross-OS replacement.**

Wrong type codes can confuse tools, installers,
and rescue systems that rely on them to identify
partition contents.

### Expected type codes by OS

| Partition    | Linux          | FreeBSD (gpart type)            |
|--------------|----------------|---------------------------------|
| Root / data  | `8300` (Linux) | `freebsd-zfs` or `freebsd-ufs`  |
| Swap         | `8200` (swap)  | `freebsd-swap`                  |
| EFI          | `ef00` (EFI)   | `efi`                           |

### How to fix

**From Linux** (after replacement):

```sh guard-off
# sgdisk: -t PARTNUM:TYPECODE
sgdisk -t 2:8200 -t 3:8300 /dev/vda
partprobe /dev/vda
```

**From FreeBSD** (after replacement):

```sh guard-off
# gpart modify: -t TYPE -i PARTNUM DEVICE
gpart modify -t freebsd-swap -i 2 vtbd0
gpart modify -t freebsd-zfs -i 3 vtbd0
```

### When to fix

Fix partition types as a post-replacement step,
after the new OS is booted and confirmed working.
Verify with `fdisk -l` or `gpart show` — look for
type names that belong to the old OS.
