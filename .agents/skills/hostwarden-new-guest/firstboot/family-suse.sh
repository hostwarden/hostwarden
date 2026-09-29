# openSUSE and SLES, for the Hostwarden baseline template. Sourced
# by common.sh, never run.
# shellcheck shell=sh disable=SC2034,SC2154

INIT=systemd

fam_upgrade() {
  zypper --non-interactive refresh
  zypper --non-interactive update
}

fam_install() {
  zypper --non-interactive refresh
  zypper --non-interactive install "$@"
}

fam_user_add() {
  useradd -m -s /bin/bash "$1"
  passwd -l "$1"
}

fam_settings() {
  # Security patches only, daily (rules/os/suse.md → Automatic
  # Security Updates); the units are shipped beside this file.
  install -m 0644 "$dir/hostwarden-security-patch.service" \
    "$dir/hostwarden-security-patch.timer" /etc/systemd/system/
  systemctl enable hostwarden-security-patch.timer
    systemctl enable sshd
  install -d -m 0755 /etc/systemd/journald.conf.d

  cat > /etc/systemd/journald.conf.d/50-hostwarden.conf <<'CONF'
[Journal]
Storage=persistent
CONF
  if [ -n "${TIMEZONE:-}" ]; then
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  fi
  firewall-offline-cmd --query-service=ssh ||
    firewall-offline-cmd --add-service=ssh
  systemctl enable firewalld
}

fam_firewall_first_boot() {
  :
}

fam_clean() {
  zypper --non-interactive clean --all
}
