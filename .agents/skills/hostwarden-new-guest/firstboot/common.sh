# Shared by build.sh, login.sh and upgrade.sh of the Hostwarden
# baseline template: the rendered settings, the family's functions
# and the init system's way of running the two first-boot units.
# Sourced, never run.
# shellcheck shell=sh

dir=/usr/local/lib/hostwarden/firstboot
# shellcheck source=/dev/null
. "$dir/build.conf"
# shellcheck source=/dev/null
. "$dir/family-$FAMILY.sh"

units='hostwarden-firstboot-login hostwarden-firstboot-upgrade'

case $INIT in
systemd)
  units_enable() {
    install -m 0644 "$dir/hostwarden-firstboot-login.service" \
      "$dir/hostwarden-firstboot-upgrade.service" /etc/systemd/system/
    systemctl enable hostwarden-firstboot-login.service \
      hostwarden-firstboot-upgrade.service
  }
  units_disable() {
    systemctl disable hostwarden-firstboot-login.service \
      hostwarden-firstboot-upgrade.service
  }
  ;;
openrc)
  units_enable() {
    for u in $units; do
      install -m 0755 "$dir/$u.openrc" "/etc/init.d/$u"
      rc-update add "$u" default
    done
    # sshd does not start unless the login unit succeeded.
    printf 'rc_sshd_need="hostwarden-firstboot-login"\n' >> /etc/rc.conf
  }
  units_disable() {
    for u in $units; do
      rc-update del "$u" default
    done
  }
  ;;
esac
