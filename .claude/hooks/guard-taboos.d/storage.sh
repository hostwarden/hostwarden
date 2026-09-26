# guard-taboos.d/storage.sh — storage repair, destroy and change,
# and a write onto a device. Sourced by guard-taboos.sh, in the
# order its GUARD_MODULES lists, into the one shell every module
# shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the modules after it

# --- Storage: repair denied, changes asked ---------------------
# rules/storage.md sorts storage commands into three tiers. Its
# repair-and-destroy tier is denied here: a repair tool decides on
# its own what is damaged and drops it, a ZFS rewind discards the
# last transactions, and the rest remove a volume, an array, a pool
# or the metadata that finds them. On a NAS a stock tool also does
# not know the vendor's records. Its change tier goes to the ask
# tier, and its read tier passes.
#
# Each dry run and LVM's test mode are exempt per invocation, as
# every read-only form here is, and so is HELP; a lookup never
# reaches a rule (below). One case arm per tool family, and for
# zpool, zfs and midclt only on the verbs that write, so a read such
# as zpool status or zfs list runs no grep.
stor_deny() {
  GUARD_ROUTE="A repair or a destroy is a step for the user: name the \
command and what it can destroy, and the user runs it at a console \
(rules/storage.md - When Storage Is Failing)."
  deny "$1"
}
stor_ask() {
  ask_for "this storage change" "can lose data or cannot be undone \
(rules/storage.md)" "Check the device, the state of the array or \
pool, and the backup before approving."
}
# A short-option cluster holding n: e2fsck -fn, xfs_repair -n,
# zpool import -Fn, zfs destroy -rn.
STORDRY='(^|[[:space:]])-[[:alnum:]]*n[[:alnum:]]*([[:space:]]|$)'
LVMTEST='(^|[[:space:]])(-t|--test)([[:space:]]|$)'
# btrfs takes global options before its command (--format and
# --log with a value of their own), and any unique
# prefix of a command: btrfs c is check, btrfs resc is rescue,
# btrfs dev del is device delete.
BTRFS='(^|[^[:alnum:]_.-])btrfs([[:space:]]+(--format|--log)[[:space:]]+[^[:space:]]+|[[:space:]]+-[^[:space:]]+)*[[:space:]]+'
MDADM='(^|[^[:alnum:]_.-])mdadm([[:space:]][^;&|]*)?[[:space:]]'
ZPOOL='(^|[^[:alnum:]_.-])zpool[[:space:]]+'
# A manual or a lookup only names a tool: man fsck, man zpool
# destroy, tldr btrfs rescue, which e2fsck, command -v lvremove.
# For the rules of this section each lookup, from its word to the
# next ; & or |, is blanked out of the segments, so no rule sees
# the tool it names while the command after it is still judged.
# The word must start a command, at the start of a line, after
# ; & | ( ` or a quote, or as the command an unquoted ssh runs:
# btrfs --log info rescue is no lookup. An ssh option that takes a
# value (LOOKSSH lists them) only counts with its value, so
# ssh -l man host is no lookup either. The segments are restored
# after the section. A sed that fails or prints nothing leaves them
# whole, which only blocks more.
LOOKSSH='ssh([[:space:]]+(-[[:alnum:]]*[BbcDEeFIiJLlmOoPpQRSWw][[:space:]]+[^[:space:]]+|-[[:alnum:]]*[46AaCfGgKkMNnqsTtVvXxYy]))*[[:space:]]+[^-[:space:];&|][^[:space:];&|]*[[:space:]]+'
LOOKUP='(^[[:space:]]*|[;&|(`"'"'"'][[:space:]]*)('"$LOOKSSH"')?(man|info|whatis|apropos|tldr|which|whereis|type|command[[:space:]]+-[vV])([[:space:]]+[^[:space:];&|]+)+'
SEGS_STOR=$SEGS
case "$TEXT" in
*man*|*info*|*whatis*|*apropos*|*tldr*|*which*|*whereis*|*type*)
  if LOOKLESS=$(printf '%s\n' "$SEGS" | sed -E "s/${LOOKUP}/\1:/g") \
    && [ -n "$LOOKLESS" ]; then
    SEGS=$LOOKLESS
  fi
  ;;
esac
# macOS: diskutil's repair verbs run fsck_apfs or fsck_hfs, or
# rewrite the partition map (repairDisk); verifyVolume and
# verifyDisk only read. Windows: chkdsk only reads without a fixing
# switch, and Repair-Volume only with -Scan; Get-Help and
# Get-Command in front of it only look it up, as diskutil help does
# for a verb. Like the diskutil and Windows rules above, these apply
# in every scope.
case "$TEXT" in
*[Dd][Ii][Ss][Kk][Uu][Tt][Ii][Ll]*)
  if hit_i '(^|[^[:alnum:]_.-])diskutil([^[:alnum:]_.-]|$)' \
    && hit_without '(^|[^[:alnum:]_.-])(help[[:space:]]+)?repair(volume|disk)([^[:alnum:]_.-]|$)' \
      '^[^[:alnum:]]?help[[:space:]]' i; then
    stor_deny "diskutil repairVolume and repairDisk repair a volume or \
rewrite the partition map"
  fi ;;
esac
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_.-])chkdsk(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?["'\''`]*/(f|r|x|b|spotfix|offlinescanandfix|forceofflinefix)(:|[[:space:]]|["'\''`]|$)'
then
  stor_deny "chkdsk with a fixing switch repairs the volume"
fi
if [ -n "$WIN" ] \
  && hit_without '(^|[^[:alnum:]_-])((get-help|get-command|gcm|help)[[:space:]]+(-name[[:space:]]+)?)?repair-volume([^[:alnum:]_-]|$)' \
    '^[^[:alnum:]]?(get-help|get-command|gcm|help)[[:space:]]|(^|[[:space:]])-scan([[:space:]]|$)' i; then
  stor_deny "Repair-Volume beyond -Scan repairs the volume"
fi
if full; then
  case "$TEXT" in
  *fsck*|*xfs_repair*|*ntfsfix*)
    # fsck, fsck.ext4, fsck_ffs, e2fsck, dosfsck, xfs_repair and
    # ntfsfix, which repairs NTFS and resets its journal. -N is
    # util-linux fsck's own dry run, --no-action ntfsfix's long one,
    # -n everyone's.
    if hit_without "(^|[^[:alnum:]_.-])(fsck([.][[:alnum:]]+|_[[:alnum:]]+)?|e2fsck|dosfsck|xfs_repair|ntfsfix)([^[:alnum:]_.-]|\$)" \
      "$STORDRY|(^|[[:space:]])(-N|--no-action)([[:space:]]|\$)|$HELP"; then
      stor_deny "a file system check without -n repairs, and a repair \
decides on its own what to throw away"
    fi
    ;;
  esac
  case "$TEXT" in
  *btrfs*)
    # btrfs check only reads unless one of these asks it to write.
    if hit "(${BTRFS}c(h(e(c(k)?)?)?)?|(^|[^[:alnum:]_.-])btrfsck)([[:space:]][^;&|]*)?[[:space:]]--(repair|init-csum-tree|init-extent-tree|clear-space-cache|clear-ino-cache)"
    then
      stor_deny "btrfs check with a write option repairs the file \
system"
    fi
    if hit_without "${BTRFS}resc(u(e)?)?([[:space:]]|\$)" "$HELP"; then
      stor_deny "btrfs rescue rewrites the file system's metadata"
    fi
    # subvolume delete removes a subvolume and everything in it. A
    # snapshot looks the same on the command line, so it is denied
    # like zfs destroy of a dataset; snapper and timeshift prune
    # their own snapshots.
    if hit_without "${BTRFS}su(b(v(o(l(u(m(e)?)?)?)?)?)?)?[[:space:]]+d(e(l(e(t(e)?)?)?)?)?([[:space:]]|\$)" \
      "$HELP"; then
      stor_deny "btrfs subvolume delete removes a subvolume and all \
the data in it"
    fi
    # A scrub rewrites damaged blocks from a verified copy: asked,
    # as zpool scrub is; status and cancel read or stop.
    if hit "${BTRFS}(d(e(v(i(c(e)?)?)?)?)?[[:space:]]+(a(d(d)?)?|rem(o(v(e)?)?)?|d(e(l(e(t(e)?)?)?)?)?)|rep(l(a(c(e)?)?)?)?[[:space:]]+star(t)?|sc(r(u(b)?)?)?[[:space:]]+(star(t)?|r(e(s(u(m(e)?)?)?)?)?))([[:space:]]|\$)"
    then
      stor_ask
    fi
    # A balance rewrites every chunk it selects: all of them without
    # a filter, where a bare -d, -m or -s selects a whole type, with
    # the hidden btrfs balance --full-balance <path>, and with the
    # deprecated btrfs balance <path> older releases still take;
    # resume goes on with whatever was paused, and convert= changes
    # the profile. A filter such as -dusage=50 moves only the chunks
    # it names, and status, pause and cancel read or stop. balance
    # also still runs under filesystem. A word after balance that is
    # no subcommand, or no prefix of one, is that path, and options
    # right after balance are the deprecated form with filters.
    FSWORD='f(i(l(e(s(y(s(t(e(m)?)?)?)?)?)?)?)?)?[[:space:]]+'
    BTRFSFS="${BTRFS}${FSWORD}"
    BAL="${BTRFS}(${FSWORD})?b(a(l(a(n(c(e)?)?)?)?)?)?[[:space:]]+"
    # BAL without its leading anchor, for an exemption that starts
    # where the match does.
    BALW=${BAL#"(^|[^[:alnum:]_.-])"}
    BALSUB='(s(t(a(r(t)?|t(u(s)?)?)?)?)?|p(a(u(s(e)?)?)?)?|c(a(n(c(e(l)?)?)?)?)?|r(e(s(u(m(e)?)?)?)?)?)([[:space:]]|$)'
    if hit_without "${BAL}(--full-balance|r(e(s(u(m(e)?)?)?)?)?)([[:space:]]|\$)|${BAL}[^;&|]*convert=|${BAL}([^;&|]*[[:space:]])?(-[dms]|--full-balance)([[:space:]]|\$)" \
        "$HELP" \
      || hit_without "${BAL}(star(t)?([[:space:]]|\$)|-)" \
        "(^|[[:space:]])-[dms][^[:space:];&|]|$HELP" \
      || hit_without "${BAL}[^-[:space:];&|]" \
        "^[^[:alnum:]]?${BALW}${BALSUB}|$HELP"
    then
      stor_ask
    fi
    # filesystem resize takes a size like lvresize: one starting
    # with - or a digit, after an optional devid:, can shrink; +
    # and max grow, 2:max included.
    if hit_without "${BTRFSFS}r(e(s(i(z(e)?)?)?)?)?([[:space:]]+-[^[:space:]]+)*[[:space:]]+([0-9]+:)?(-[0-9]|[0-9]+([^:0-9]|\$))" \
      "$HELP"
    then
      stor_deny "btrfs filesystem resize without a + size or max can \
shrink the file system"
    fi
    if hit_without "${BTRFSFS}r(e(s(i(z(e)?)?)?)?)?([[:space:]]|\$)" "$HELP"
    then
      stor_ask
    fi
    ;;
  esac
  case "$TEXT" in
  *debugfs*)
    if hit '(^|[^[:alnum:]_.-])debugfs([[:space:]][^;&|]*)?[[:space:]]-[[:alnum:]]*w'
    then
      stor_deny "debugfs -w writes file system metadata directly"
    fi
    ;;
  esac
  case "$TEXT" in
  *sync_action*)
    # md's repair and resync rewrite every mismatch from one copy of
    # their own choosing, with no checksum to say which is right;
    # check only counts them, idle and frozen stop. A redirect or
    # tee is how the word reaches the file.
    if hit '(^|[^[:alnum:]_-])(repair|resync)([^[:alnum:]_-][^;&|]*)?>[[:space:]]*[^[:space:];&|]*sync_action' \
      || { hit '(^|[^[:alnum:]_.-])(tee|sponge)[[:space:]]([^;&|]*[[:space:]])?[^[:space:];&|]*sync_action' \
           && hit '(^|[^[:alnum:]_-])(repair|resync)([^[:alnum:]_-]|$)'; }
    then
      stor_deny "a repair or resync through sync_action rewrites the \
array from a copy md picks"
    fi
    ;;
  esac
  case "$TEXT" in
  *mdadm*)
    # Creating, building, growing or rewriting an array's superblock,
    # an assemble forced past its own checks, and the repair and
    # resync actions, which rewrite every mismatch from a copy md
    # picks. A cluster counts: mdadm -Cv is --create. --detail,
    # --examine, --query and --action=check read; the manage verbs
    # are asked.
    if hit "${MDADM}(-[[:alpha:]]*[CBG][[:alpha:]]*|--(create|build|grow|zero-superblock|update)|--action([[:space:]]+|=)(repair|resync))([[:space:]=]|\$)"
    then
      stor_deny "this mdadm mode creates, grows or rewrites an array's \
metadata or data"
    fi
    if hit "${MDADM}((--assemble|-[[:alpha:]]*A[[:alpha:]]*)([[:space:]][^;&|]*)?[[:space:]](--force|-f)|(--force|-f)([[:space:]][^;&|]*)?[[:space:]](--assemble|-[[:alpha:]]*A[[:alpha:]]*)|-[[:alpha:]]*(A[[:alpha:]]*f|f[[:alpha:]]*A)[[:alpha:]]*)([[:space:]]|\$)"
    then
      stor_deny "a forced mdadm assemble overrides the array's own \
consistency checks"
    fi
    if hit_without "${MDADM}(-[arfS]|--(add|re-add|add-spare|remove|fail|set-faulty|replace|stop))([[:space:]=]|\$)" \
      "$HELP"; then
      stor_ask
    fi
    ;;
  esac
  case "$TEXT" in
  *pvcreate*|*pvremove*|*vgremove*|*lvremove*|*lvreduce*|*vgcfgrestore*|*pvck*|*vgck*)
    # Labelling a device, removing a PV, VG or LV, shrinking an LV,
    # restoring old metadata over the current one, and the checkers'
    # own repair modes. Each tool also runs as lvm <tool>.
    if hit_without "(^|[^[:alnum:]_.-])(pvcreate|pvremove|vgremove|lvremove|lvreduce|vgcfgrestore)([^[:alnum:]_.-]|\$)" \
      "$LVMTEST|$HELP"; then
      stor_deny "this LVM command destroys a volume or the metadata \
that finds it"
    fi
    if hit '(^|[^[:alnum:]_.-])(pvck|vgck)([[:space:]][^;&|]*)?[[:space:]]--(repair|updatemetadata)([[:space:]=]|$)'
    then
      stor_deny "pvck and vgck with a repair option rewrite LVM \
metadata"
    fi
    ;;
  esac
  case "$TEXT" in
  *lvcreate*|*lvextend*|*lvresize*|*lvconvert*|*vgcreate*|*vgextend*|*vgreduce*|*pvmove*|*pvresize*)
    # lvresize shrinks with a negative size, and with an absolute one
    # below the current size, which the command line cannot show.
    # Only a size starting with + is known to grow; lvextend refuses
    # to shrink whatever it is given. The size may close a cluster:
    # lvresize -rL 10G.
    if hit_without '(^|[^[:alnum:]_.-])lvresize([[:space:]][^;&|]*)?[[:space:]](-[[:alpha:]]*[Ll]|--size|--extents)([[:space:]]+|=)?[^+=[:space:]]' \
      "$LVMTEST|$HELP"; then
      stor_deny "lvresize without a + size can shrink the volume like \
lvreduce - grow with lvextend or a size starting with +"
    fi
    # lvconvert --repair rebuilds a RAID or mirror LV and runs
    # thin_repair on a thin pool's metadata: a repair, not a change.
    if hit_without '(^|[^[:alnum:]_.-])lvconvert([[:space:]][^;&|]*)?[[:space:]]--repair([[:space:]=]|$)' \
      "$LVMTEST|$HELP"; then
      stor_deny "lvconvert --repair repairs a RAID, mirror or thin pool \
volume"
    fi
    if hit_without "(^|[^[:alnum:]_.-])(lvcreate|lvextend|lvresize|lvconvert|vgcreate|vgextend|vgreduce|pvmove|pvresize)([^[:alnum:]_.-]|\$)" \
      "$LVMTEST|$HELP"; then
      stor_ask
    fi
    ;;
  esac
  case "$TEXT" in
  *lvchange*|*vgchange*)
    # -an, --activate n and their lvmlockd forms (en, sn, ln)
    # deactivate: the block device goes away under whatever mounts
    # or uses it. Activating and the other attributes are left.
    if hit_without '(^|[^[:alnum:]_.-])(lv|vg)change([[:space:]][^;&|]*)?[[:space:]](-[[:alpha:]]*a|--activate)([[:space:]]+|=)?[els]?n([[:space:]]|$)' \
      "$LVMTEST|$HELP"; then
      stor_ask
    fi
    ;;
  esac
  case "$TEXT" in
  *resize2fs*|*xfs_growfs*)
    # resize2fs takes no relative size, so any size given can
    # shrink the file system, as can -M; without one it grows to
    # the device. xfs_growfs -D sets the data section to a size,
    # smaller included; its other forms grow. resize2fs -P and
    # xfs_growfs -n only print. A size is a second operand after
    # the device: the value of -d, -S or -z is none, and neither is
    # a redirect such as 2>&1 or a comment.
    case "$TEXT" in
    *resize2fs*)
      R2OPT='([[:space:]]+(-[[:alnum:]]*[dSz][[:space:]]+[^[:space:];&|]+|-[^[:space:];&|]*[^dSz[:space:];&|]))*'
      R2ARG='[[:space:]]+[^-#<>[:space:];&|][^<>[:space:];&|]*'
      if hit_without "(^|[^[:alnum:]_.-])resize2fs(${R2OPT}${R2ARG}${R2OPT}${R2ARG}([[:space:];&|]|\$)|([[:space:]][^;&|]*)?[[:space:]]-[[:alnum:]]*M)" \
        "$HELP"; then
        stor_deny "resize2fs with a size or -M can shrink the file system \
- grow it with no size, after the volume under it"
      fi
      ;;
    esac
    case "$TEXT" in
    *xfs_growfs*)
      if hit_without '(^|[^[:alnum:]_.-])xfs_growfs([[:space:]][^;&|]*)?[[:space:]]-[[:alpha:]]*D' \
        "$STORDRY|$HELP"; then
        stor_deny "xfs_growfs -D sets the data section to a size, which \
can shrink it - grow it with -d"
      fi
      ;;
    esac
    if hit_without "(^|[^[:alnum:]_.-])(resize2fs|xfs_growfs)([^[:alnum:]_.-]|\$)" \
      "(^|[[:space:]])-[[:alnum:]]*P|$STORDRY|(^|[[:space:]])-V([[:space:]]|\$)|$HELP"; then
      stor_ask
    fi
    ;;
  esac
  case "$TEXT" in
  *zinject*)
    if hit_without "(^|[^[:alnum:]_.-])zinject([^[:alnum:]_.-]|\$)" \
      "$HELP"; then
      stor_deny "zinject injects faults into a live pool"
    fi
    ;;
  esac
  case "$TEXT" in
  *zpool*)
    # create formats its disks like mkfs; destroy and labelclear
    # remove a pool; -F, -X and -T rewind one, which import takes on
    # every release and clear up to OpenZFS 2.1, and so does import
    # --rewind-to-checkpoint; import -m drops a missing log device
    # with its transactions. upgrade asks only with a pool or -a:
    # bare, or with -v, it lists. import asks the same way: bare, or
    # with only options (-d dir), it lists what could be imported;
    # with a pool or -a it imports. export unmounts every dataset.
    case "$TEXT" in
    *create*|*destroy*|*labelclear*)
      if hit_without "${ZPOOL}(create|destroy|labelclear)([^[:alnum:]_-]|\$)" \
        "$STORDRY|$HELP"; then
        stor_deny "zpool create, destroy and labelclear erase the pool \
on their disks"
      fi
      ;;
    esac
    case "$TEXT" in
    *import*|*clear*)
      if hit_without "${ZPOOL}(import|clear)([[:space:]][^;&|]*)?[[:space:]](-[[:alnum:]]*[FXTm]|--rewind-to-checkpoint)" \
        "$STORDRY"; then
        stor_deny "a ZFS rewind discards the pool's last transactions \
for good"
      fi
      ;;
    esac
    case "$TEXT" in
    *scrub*)
      if hit_without "${ZPOOL}scrub([^[:alnum:]_-]|\$)" \
        "(^|[[:space:]])-[[:alnum:]]*[sp]([[:space:]]|\$)|$HELP"; then
        stor_ask
      fi
      ;;
    esac
    case "$TEXT" in
    *attach*|*detach*|*replace*|*offline*|*online*|*add*|*remove*|*split*|*upgrade*|*export*)
      if hit_without "${ZPOOL}((attach|detach|replace|offline|online|add|remove|split|export)([^[:alnum:]_-]|\$)|upgrade([[:space:]]+-[[:alnum:]]+)*[[:space:]]+(-a|[^-[:space:];&|]))" \
        "$STORDRY|$HELP"; then
        stor_ask
      fi
      ;;
    esac
    case "$TEXT" in
    *import*)
      # An option ending in c, d, o or R takes a value (-d dir,
      # -o prop, -c cachefile, -R root), which is not a pool name.
      if hit_without "${ZPOOL}import([[:space:]]+-[[:alnum:]]*[cdoR][[:space:]]+[^[:space:]]+|[[:space:]]+-[[:alnum:]]*[^cdoR[:space:];&|])*[[:space:]]+([^-[:space:];&|]|-[[:alnum:]]*a([[:space:]]|\$))" \
        "$STORDRY|$HELP"; then
        stor_ask
      fi
      ;;
    esac
    ;;
  esac
  case "$TEXT" in
  *zfs*)
    # destroy of a dataset or volume is its data, and so is -R on a
    # snapshot, destroy or rollback: it takes every dependent clone
    # with it, a dataset of its own and possibly outside the target's
    # tree. A snapshot or bookmark (@, #) otherwise, a rollback and
    # a receive change only what came after, and are asked.
    case "$TEXT" in
    *destroy*|*rollback*)
      if hit_without '(^|[^[:alnum:]_.-])zfs[[:space:]]+(destroy|rollback)([[:space:]]+-[[:alnum:]]+)*[[:space:]]+-[[:alnum:]]*R' \
        "$STORDRY|$HELP"; then
        stor_deny "zfs destroy or rollback with -R destroys every clone \
that depends on the snapshot"
      fi
      ;;
    esac
    case "$TEXT" in
    *destroy*)
      if hit_without "(^|[^[:alnum:]_.-])zfs[[:space:]]+destroy([[:space:]]+-[[:alnum:]]+)*[[:space:]]+[\"']?[^-@#[:space:];&|\"'][^@#[:space:];&|\"']*[\"']?([[:space:];&|]|\$)" \
        "$STORDRY|$HELP"; then
        stor_deny "zfs destroy of a dataset or volume deletes its data \
and every snapshot of it"
      fi
      ;;
    esac
    case "$TEXT" in
    *destroy*|*rollback*|*recv*|*receive*)
      if hit_without '(^|[^[:alnum:]_.-])zfs[[:space:]]+(destroy|rollback|receive|recv)([^[:alnum:]_-]|$)' \
        "$STORDRY|$HELP"; then
        stor_ask
      fi
      ;;
    esac
    ;;
  esac
  case "$TEXT" in
  *disk.wipe*|*pool.create*)
    if hit "${MIDCLT}(disk[.]wipe|pool[.]create)([^[:alnum:]_.-]|\$)"
    then
      stor_deny "TrueNAS disk.wipe and pool.create erase whole disks"
    fi
    ;;
  *pool.export*|*pool.dataset.delete*)
    # pool.dataset.delete is zfs destroy of a dataset, and pool.export
    # with destroy in its argument is zpool destroy: both denied like
    # the commands they stand for. A plain export only unmounts, and
    # is asked like zpool export.
    if hit "${MIDCLT}pool[.]dataset[.]delete([^[:alnum:]_.-]|\$)"
    then
      stor_deny "TrueNAS pool.dataset.delete deletes a dataset like zfs \
destroy"
    fi
    if hit "${MIDCLT}pool[.]export([^[:alnum:]_.-][^;&|]*)?destroy"
    then
      stor_deny "TrueNAS pool.export with destroy erases the pool like \
zpool destroy"
    fi
    if hit "${MIDCLT}pool[.]export([^[:alnum:]_.-]|\$)"
    then
      stor_ask
    fi
    ;;
  esac
fi
SEGS=$SEGS_STOR

# The disk precheck again, for the rule that needs writes_to.
if [ -n "$DISK" ]; then
# A redirect, tee, cp or download onto a disk device does what
# dd of= does. /dev/null, /dev/stderr and /dev/disk/by-id are
# unaffected.
if full && { hit ">[[:space:]]*[\"']?$DEV" \
  || { hit "$DEV" && writes_to "${DEV}[[:alnum:]]*"; }; }
then
  deny "writing onto a raw disk device overwrites its content \
and partition table"
fi
fi # the disk precheck
