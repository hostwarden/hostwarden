#!/bin/sh
# The rest of the first boot of a container made from the Hostwarden
# baseline template: firewall, first upgrade, the baseline version.
# Run by the first-boot upgrade unit; never run by hand.
set -eu

# Without the login in place this unit must not go on to disable it.
[ -e /var/lib/hostwarden/login.done ] || exit 1
# shellcheck source=/dev/null
. /usr/local/lib/hostwarden/firstboot/common.sh
export LC_ALL=C

fam_firewall_first_boot
fam_upgrade

printf '%s\n' "$BASELINE" > /etc/hostwarden-baseline
install -d -m 0755 /var/lib/hostwarden
if [ -e /run/reboot-required ]; then
  : > /var/lib/hostwarden/reboot-required
fi

: > /var/lib/hostwarden/upgrade.done
units_disable
