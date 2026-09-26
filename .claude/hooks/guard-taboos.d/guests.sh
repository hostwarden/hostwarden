# guard-taboos.d/guests.sh — stopping and deleting a guest.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh

# --- Guest stop and delete: ask, never silently allow ----------
# Stopping a container or VM powers that server off and deleting
# it destroys it (rules/system-containers.md), but managing guests
# on a host Hostwarden administers is legitimate work: the ask tier.
#
# Only the manager's own verb counts: a service stopped or a file
# deleted inside a guest through exec stays allowed, and so do
# snapshot, image, network and storage verbs, which carry a noun
# before theirs. The prefilter spares every command without a
# manager's name the greps.
#
# Beside the managers in GUESTMGRS, the forms of another shape:
# lxc-destroy; jail(8) with -r or -R among its
# options, which removes a running jail, -rc included (the restart
# is a stop first); and the rc scripts that stop or restart every
# jail of jail.conf, Bastille or iocage (service jail stop,
# onerestart and the rest, or /etc/rc.d/jail stop). lxc-stop has an exemption of its
# own below, and TrueNAS' API is read through MIDCLT, which carries
# its own leading boundary.
GUESTFORMS='lxc-destroy|jail[[:space:]]+(-[[:alpha:]]+[[:space:]]+([^-[:space:];&|][^[:space:];&|]*[[:space:]]+)?)*-[[:alpha:]]*[rR][[:alpha:]]*|(service[[:space:]]+|rc[.]d/)(jail|bastille|iocage)[[:space:]]+(one|fast|force|quiet)?(stop|restart)'
guest_ask() {
  ask_for "stopping or deleting a system container or VM" "powers \
off or destroys that server (rules/system-containers.md)" "Check the \
guest ID and the host before approving."
}
for gm in $GMWORDS midclt lxc-destroy jail; do
  case "$TEXT" in
  *"$gm"*)
    if full && hit_without "(^|[^[:alnum:]_.-])(${GMSTOP#|}|$GUESTFORMS)([^[:alnum:]_-]|\$)|${MIDCLT}(vm|virt[.]instance)[.](stop|delete)([^[:alnum:]_-]|\$)" \
      "$HELP"
    then
      guest_ask
    fi
    break ;;
  esac
done
case "$TEXT" in
*lxc-stop*)
  if full && hit_without '(^|[^[:alnum:]_.-])lxc-stop([^[:alnum:]_.-]|$)' \
    "(^|[[:space:]])(-r|--reboot)([[:space:]]|\$)|$HELP"
  then
    guest_ask
  fi
  ;;
esac
