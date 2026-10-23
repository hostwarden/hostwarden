# openSUSE and SLES, for the Hostwarden baseline template. Sourced
# by common.sh, never run.
# shellcheck shell=sh disable=SC2034,SC2154

INIT=systemd

# zypper answers 102 (reboot needed), 103 (zypper itself updated) and
# 106 (a repository skipped) after a run that worked; any other
# non-zero status is a failure.
zy() {
  rc=0
  zypper --non-interactive "$@" || rc=$?
  case $rc in
  0 | 102 | 103 | 106) return 0 ;;
  *) return "$rc" ;;
  esac
}

fam_upgrade() {
  zy refresh
  zy update
}

fam_install() {
  zy refresh
  zy install "$@"
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
  zy clean --all
}
