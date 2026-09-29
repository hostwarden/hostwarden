#!/bin/sh
# Builds the Hostwarden baseline template inside its build
# container (references/proxmox-template.md). Bakes in everything
# but the login and the first upgrade, and enables the two units
# that make those on the first boot of a container made from the
# archive. It starts nothing: the units run there, never here.
set -eu

# shellcheck source=/dev/null
. /usr/local/lib/hostwarden/firstboot/common.sh
export LC_ALL=C

fam_upgrade
# $PACKAGES is a list of words on purpose.
# shellcheck disable=SC2086
fam_install $PACKAGES

if [ "$SSH_USER" != root ] && ! id "$SSH_USER" >/dev/null 2>&1; then
  fam_user_add "$SSH_USER"
  install -d -m 0755 /etc/sudoers.d
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$SSH_USER" \
    > "/etc/sudoers.d/90-hostwarden-$SSH_USER"
  chmod 0440 "/etc/sudoers.d/90-hostwarden-$SSH_USER"
fi

fam_settings
units_enable
fam_clean
