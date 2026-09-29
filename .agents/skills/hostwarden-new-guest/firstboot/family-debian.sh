# Debian and Ubuntu, for the Hostwarden baseline template. Sourced
# by common.sh, never run.
# shellcheck shell=sh disable=SC2034,SC2154

INIT=systemd
export DEBIAN_FRONTEND=noninteractive

fam_upgrade() {
  apt-get update -q
  apt-get -y -q upgrade
}

fam_install() {
  apt-get update -q
  apt-get -y -q install "$@"
}

fam_user_add() {
  useradd -m -s /bin/bash -G sudo "$1"
  passwd -l "$1"
}

fam_settings() {
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF
  cat > /etc/apt/apt.conf.d/51hostwarden <<'CONF'
Unattended-Upgrade::Mail "root";
CONF
    systemctl enable ssh
  install -d -m 0755 /etc/systemd/journald.conf.d

  cat > /etc/systemd/journald.conf.d/50-hostwarden.conf <<'CONF'
[Journal]
Storage=persistent
CONF
  if [ -n "${TIMEZONE:-}" ]; then
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    printf '%s\n' "$TIMEZONE" > /etc/timezone
  fi
}

# The firewall is enabled on the first boot, where iptables answers.
fam_firewall_first_boot() {
  ufw allow OpenSSH
  ufw --force enable
}

fam_clean() {
  apt-get clean
  rm -rf /var/lib/apt/lists/*
}
