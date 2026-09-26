# guard-taboos.d/first-boot.sh — the writes only a guest's first boot may make.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh

# --- a guest that has never run --------------------------------
# AGENTS.md -> Critical Safety Rules lets the first-boot
# configuration of a guest that has never started set sshd's login
# options and keys, whatever form that configuration takes, and
# hostwarden-new-guest writes it. Nothing here can prove that a
# root filesystem or an image belongs to such a guest, so the two
# shapes a manager owns are put to the user with the path in front
# of them, and everything else stays denied.
#
#   - the root filesystem of a container under its manager's own
#     directory: /var/lib/lxc/<name>/rootfs, /var/lib/machines/
#     <name>, an Incus or LXD container in its storage pool. A
#     path under one of those is not the running system's /etc.
#     The root must sit right in front of the guarded path, so
#     rootfs/../../etc/ssh is the host's and stays denied. For
#     keys that means host keys at rootfs/etc/ssh; a user's
#     authorized_keys further down stays denied.
#   - a disk image a libguestfs tool opened with -a or --add, as
#     the only command on the line. libguestfs refuses a disk
#     another process has open, so that is a file rather than a
#     server. A -d or --domain names a libvirt guest that may be
#     running and does not count, and neither does a line with a
#     second command or a redirect beside the tool: those spell
#     the host's /etc/ssh exactly as the image's is spelled.
#
# /mnt and /media are deliberately absent: a bind mount of the
# live system is spelled exactly the same way, and what the guard
# cannot tell apart it must not decide.
#
# Asking, not allowing, for the same reason the guest rules ask:
# the everyday mistake here is a path that looks like a guest and
# is the host. Where no prompt can reach a human the answer is
# deny, and the user runs it themselves.
#
# The ask is registered where it is found and decided at the end of
# this file, never on the spot: decide exits, and every rule after
# the sshd and key rules has to see the rest of the line first. A
# first-boot write followed by any taboo is that taboo's deny.
GUESTROOT='(/var/lib/lxc/[^/[:space:]]+/rootfs|/var/lib/machines/[^/[:space:]]+|/var/lib/(incus|lxd)/storage-pools/[^/[:space:]]+/containers/[^/[:space:]]+/rootfs)'
IMAGETOOL='(virt-customize|virt-copy-in|virt-edit|virt-sysprep|guestfish|guestmount)'

FB_NL='
'

first_boot_only() {
  # first_boot_only <path pattern> -- true when the command works
  # on an image through libguestfs, or when EVERY occurrence of
  # that pattern sits under a guest root. One unqualified /etc/ssh
  # beside a qualified one is enough to fail: a command that
  # touches both is a command that touches the host.
  if hit "(^|[^[:alnum:]_.-])$IMAGETOOL([^[:alnum:]_.-]|\$)"; then
    # One invocation and nothing beside it. A second command or a
    # redirect names paths the image tool never sees, spelled the
    # same as the ones it does.
    case $CMD in
    *';'* | *'&'* | *'|'* | *'>'* | *'`'* | *'$('*) return 1 ;;
    esac
    case $CMD in
    *"$FB_NL"*) return 1 ;;
    esac
    # A domain may be running, whatever else the line carries.
    hit '(^|[[:space:]])(-d|--domain)([[:space:]]|=)' && return 1
    # Every invocation must name an image with -a, scoped to the
    # invocation rather than to the whole string.
    hit_without "(^|[^[:alnum:]_.-])$IMAGETOOL([^[:alnum:]_.-]|\$)" \
      '(^|[[:space:]])(-a|--add)([[:space:]]|=)' || return 0
  fi
  FB_ALL=$(segments | grep -oE "$1" | grep -c .)
  FB_UNDER=$(segments | grep -oE "$GUESTROOT$1" | grep -c .)
  [ "$FB_ALL" -gt 0 ] && [ "$FB_ALL" -eq "$FB_UNDER" ]
}

image_write_targets() {
  # image_write_targets -- the command line with each LOCAL:REMOTE of
  # virt-customize's --copy-in and --upload replaced by the paths the
  # image is written at: REMOTE, and REMOTE/<LOCAL's last name>, where
  # --copy-in lands it. LOCAL is only read, so copying the host's own
  # sshd_config into an image as a reference is a read of it, while
  # ssh:/etc still lands as the image's /etc/ssh. Quotes around either
  # side go too, since the shell drops them. A LOCAL that holds a
  # colon, a space or a quote inside it is left in place and still
  # counts, which errs on asking.
  printf '%s' "$CMD" \
    | sed -E "s#(--(copy-in|upload)([[:space:]]+|=))[\"']*([^:[:space:]\"']*/)?([^/:[:space:]\"']+)/*[\"']*:[\"']*([^[:space:]\"']*)[\"']*#\\1:\\6 :\\6/\\5#g"
}

image_sshd_write() {
  # image_sshd_write -- true when a --copy-in or --upload writes the
  # image's sshd config, or anything in a directory sshd or dropbear
  # keeps it or its keys in, whatever the file is called: /etc/ssh
  # under any prefix (FreeBSD's /usr/local/etc/ssh), QNAP's
  # /etc/config/ssh, dropbear's /etc/dropbear, OPNsense's /conf/sshd
  # and Windows' ProgramData/ssh. The directories dropbear's config
  # file shares with everything else (/etc/config, /etc/conf.d,
  # /etc/default) count only when the line names dropbear.
  IWT=$(image_write_targets)
  printf '%s' "$IWT" | grep -Eq "$SSHD" && return 0
  printf '%s' "$IWT" \
    | grep -Eq ":[^[:space:]\"']*/(etc/(ssh|dropbear|config/ssh)|conf/sshd|$WINSSHDIR)([/[:space:]\"']|\$)" \
    && return 0
  printf '%s' "$IWT" \
    | grep -Eq ":/etc/(config|conf\\.d|default)([/[:space:]\"']|\$)" \
    && printf '%s' "$CMD" | grep -q dropbear
}

first_boot_ask() {
  # first_boot_ask <what> -- the ask tier (ask_for below) for a
  # write that only a guest's first boot may make.
  ask_for "$1" "for a guest that has not started yet. Only the \
first-boot configuration of a guest that never ran may set sshd's \
login options and keys (AGENTS.md - Critical Safety Rules)" "Check \
that the path is the guest's and not this host's before approving."
}
