# guard-taboos.d/disks.sh — filesystems, partition tables and raw devices.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh

# --- Disks: one precheck --------------------------------------
# Every disk rule from here to shred, and the write onto a device
# after the storage rules, needs a word of its own in the command,
# so one case finds out whether any can match, and the twenty-odd
# greps below run only then. A new disk rule adds its word here; the
# storage rules between the two parts keep prechecks of their own. The words are case-sensitive as the rules read them,
# diskutil and PhysicalDrive in any case; dd, shred and a write onto
# a device need a device path. The Windows rules in between keep
# their own precheck, WIN, which opens this one too.
DISK=$WIN
case "$TEXT" in
*mkfs*|*mke2fs*|*mkntfs*|*mkdosfs*|*mkexfatfs*|*mkudffs*) DISK=1 ;;
*newfs*|*wipefs*|*fdisk*|*gdisk*|*parted*|*growpart*) DISK=1 ;;
*gpt*|*gpart*|*[Dd][Ii][Ss][Kk][Uu][Tt][Ii][Ll]*) DISK=1 ;;
*blkdiscard*|*nvme*|*hdparm*|*badblocks*) DISK=1 ;;
*/dev/*|*[Pp][Hh][Yy][Ss][Ii][Cc][Aa][Ll][Dd][Rr][Ii][Vv][Ee]*) DISK=1 ;;
esac
if [ -n "$DISK" ]; then
# --- Filesystem creation --------------------------------------
if full && hit '(^|[^[:alnum:]_.-])mkfs(\.[[:alnum:]]+)?([^[:alnum:]_.-]|$)'
then
  deny "mkfs destroys the filesystem on its target"
fi
# newfs_msdos and friends: the suffix must be part of the match,
# otherwise the trailing word boundary rejects the underscore.
if full && hit '(^|[^[:alnum:]_.-])newfs([._][[:alnum:]]+)*([^[:alnum:]_.-]|$)'
then
  deny "newfs destroys the filesystem on its target"
fi
if full && hit '(^|[^[:alnum:]_.-])(mke2fs|mkntfs|mkdosfs|mkexfatfs|mkudffs|mkfs2?)([^[:alnum:]_.-]|$)'
then
  deny "this filesystem creator destroys the data on its target"
fi
if full && hit '(^|[^[:alnum:]_.-])wipefs([^[:alnum:]_.-]|$)' \
  && hit '(^|[[:space:]])(-a|--all|-o|--offset)'; then
  deny "wipefs in write mode erases filesystem signatures"
fi

# --- Partition table writers ----------------------------------
# Read-only inspection stays allowed: fdisk -l, sfdisk -l/-d,
# gdisk -l, sgdisk -p, parted -l/print, gpart show/status/list,
# lsblk, diskutil list.
if full && hit_without '(^|[^[:alnum:]_.-])fdisk([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])-l'; then
  deny "fdisk without -l opens the partition table for writing"
fi
# cfdisk has no read-only mode at all: it is the curses editor.
if full && hit '(^|[^[:alnum:]_.-])cfdisk([^[:alnum:]_.-]|$)'; then
  deny "cfdisk is an interactive partition editor with no \
read-only mode"
fi
if full && hit_without '(^|[^[:alnum:]_.-])sfdisk([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])(-l|--list|-d|--dump|-V|--verify)'; then
  deny "sfdisk in write mode modifies the partition table"
fi
if full && hit_without '(^|[^[:alnum:]_.-])c?gdisk([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])-l'; then
  deny "gdisk without -l opens the partition table for writing"
fi
# sgdisk and parted both take SEVERAL actions per invocation, so
# "allow when a read-only flag is present" cannot work: the read
# flag rides along with the write one (sgdisk -b backup.gpt -Z
# /dev/sda). Their write sets are closed and documented, so they
# are enumerated in full instead. Short flags below are the
# complete write set from sgdisk(8); the read-only ones (a D E f
# F i L O p P V v) are absent on purpose, and so is -b, which
# writes a backup FILE and not the disk.
if full && hit '(^|[^[:alnum:]_.-])sgdisk([^[:alnum:]_.-]|$)' \
  && hit '(^|[[:space:]])(-[BcCdegGhIjklmnNorRstTuUzZ]|--(byte-swap-name|change-name|recompute-chs|delete|move-second-header|mbrtogpt|randomize-guids|hybrid|align-end|move-main-table|move-backup-table|load-backup|gpttombr|new|largest-new|clear|transpose|replicate|sort|typecode|transform-bsd|partition-guid|disk-guid|zap|zap-all))'
then
  deny "sgdisk write options modify the partition table"
fi
if full && hit '(^|[^[:alnum:]_.-])parted([^[:alnum:]_.-]|$)' \
  && hit '((mklabel|mktable|mkpartfs|mkpart|rescue|resize)([[:space:]]|$)|(rm|set|toggle|name|move|resizepart)[[:space:]]+[0-9]|disk_(set|toggle)[[:space:]])'
then
  deny "parted write commands modify the partition table"
fi
# growpart rewrites the partition entry to enlarge it. Its dry
# run is the only read-only form, and the exemption is scoped
# the same way as every other one here.
if full && hit_without '(^|[^[:alnum:]_.-])growpart([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])(-N|--dry-run)([[:space:]]|$)'; then
  deny "growpart rewrites the partition table to resize a \
partition"
fi
# FreeBSD and macOS GUID partition table editor. show is the
# read-only verb and stays allowed.
if full && hit '(^|[^[:alnum:]_.-])gpt[[:space:]]+(create|destroy|add|remove|modify|migrate|recover|resize|restore|boot|label|set|unset)([^[:alnum:]_-]|$)'
then
  deny "gpt write verbs modify the partition table"
fi
# macOS: the tool people actually partition with. Verbs are
# case-insensitive, hence hit_i.
if hit_i '(^|[^[:alnum:]_.-])diskutil([^[:alnum:]_.-]|$)' \
  && hit_i '(erasedisk|erasevolume|eraseoptical|zerodisk|randomdisk|secureerase|partitiondisk|splitpartition|mergepartitions|resizevolume|reformat|deletecontainer|deletevolume|erasecontainer|destroycontainer|resizecontainer|appleraid[[:space:]]+(delete|create))'
then
  deny "diskutil erase and partition verbs destroy data or the \
partition map"
fi
if full && hit 'gpart[[:space:]]+(create|add|delete|destroy|modify|resize|bootcode|recover|set|undo|commit)'
then
  deny "gpart write verbs modify the partition table"
fi
# Windows, as WSL reaches it. Names are matched without regard to
# case, as Windows reads them. diskpart runs its verbs from a
# prompt or a script file, so no read-only form of it can be
# shown; Get-Disk, Get-Partition and Get-Volume inspect instead.
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_.-])diskpart(\.exe)?([^[:alnum:]_.-]|$)'; then
  deny "diskpart edits disks and partition tables, and none of \
its forms can be shown to be read-only - inspect with Get-Disk, \
Get-Partition or Get-Volume"
fi
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_-])(clear-disk|initialize-disk|set-disk|new-partition|remove-partition|resize-partition|set-partition|format-volume|new-volume|remove-virtualdisk|remove-storagepool)([^[:alnum:]_-]|$)'
then
  deny "this Storage cmdlet erases a disk or changes its \
partition table"
fi
# bcdedit only reads with /enum and /v, and bare or with /store
# alone it lists too. Every other option edits the boot
# configuration, so the exemption holds only while each argument
# up to the next ; & or | is one of those or no option at all:
# bcdedit /v /set ... still edits. A quote or backtick in front
# of an option is dropped before bcdedit sees it, so "/set" is
# still /set.
if [ -n "$WIN" ] \
  && hit_without '(^|[^[:alnum:]_.-])bcdedit([.]exe)?([^[:alnum:]_.-]|$)' \
  "^[^[:alnum:]]?bcdedit([.]exe)?([[:space:]]+[\"'\`]*(/(enum|v|store|[?])[\"'\`]*|[^/[:space:];&|\"'\`-][^[:space:];&|]*))*[[:space:]]*([;&|]|\$)" i
then
  deny "bcdedit beyond /enum and /v rewrites the boot \
configuration and can leave the machine unbootable"
fi
# mbr2gpt rewrites the partition table unless it only validates.
if [ -n "$WIN" ] \
  && hit_without '(^|[^[:alnum:]_.-])mbr2gpt(\.exe)?([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])[/-]validate' i; then
  deny "mbr2gpt without /validate converts the partition table"
fi
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_.-])format(\.com)?["'"'"']?[[:space:]]+["'"'"']?[a-z]:'; then
  deny "format erases the volume on that drive letter"
fi
# cipher /w overwrites all free space on the volume that holds
# its directory, so nothing deleted there can be recovered.
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_.-])cipher(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?["'\''`]*[/-]w(:|[[:space:]]|["'\''`]|$)'
then
  deny "cipher /w wipes the free space of a whole volume"
fi
# wsl --unregister (wslconfig /u) deletes a distribution together
# with the virtual disk that holds its whole filesystem.
if [ -n "$WIN" ] \
  && hit_i "${WSL}([^;&|]*[[:space:]])?(--unregister|/(u|unregister))([[:space:]]|\$)"
then
  deny "wsl --unregister deletes the distribution and its whole \
virtual disk"
fi
if full && hit '(^|[^[:alnum:]_-])dd([^[:alnum:]_-]|$)' \
  && hit 'of=["'\'']?/dev/'; then
  deny "dd onto a raw device overwrites disk content and \
partition table"
fi

# --- Raw-device wipers ----------------------------------------
# These leave the partition table intact and destroy everything
# it points at, which is the same effect by another route.
if full && hit '(^|[^[:alnum:]_.-])blkdiscard([^[:alnum:]_.-]|$)'; then
  deny "blkdiscard discards every block on the device"
fi
if full && hit '(^|[^[:alnum:]_.-])nvme[[:space:]]+(format|sanitize|write|delete-ns|create-ns|attach-ns|detach-ns|security-send|copy|dsm|zns)'
then
  deny "this nvme subcommand overwrites or destroys namespace \
data"
fi
if full && hit '(^|[^[:alnum:]_.-])hdparm([^[:alnum:]_.-]|$)' \
  && hit '(--security-(erase|erase-enhanced|set-pass|unlock|disable)|--trim-sector-ranges|--make-bad-sector|--write-sector|--dco-(restore|setmax)|--repair-sector)'
then
  deny "this hdparm option erases the drive or writes raw \
sectors"
fi
# badblocks -w is the destructive read-write test. -n and -sv
# are non-destructive and stay allowed.
if full && hit '(^|[^[:alnum:]_.-])badblocks([^[:alnum:]_.-]|$)' \
  && hit '(^|[[:space:]])-[[:alnum:]]*w'; then
  deny "badblocks -w overwrites the device while testing it"
fi
if full && hit '(^|[^[:alnum:]_.-])shred([^[:alnum:]_.-]|$)' \
  && hit "$DEV"; then
  deny "shred on a disk device overwrites the whole device"
fi

fi # the disk precheck, up to shred
