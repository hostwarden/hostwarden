# The RHEL family (RHEL, Rocky, Alma, CentOS), for the
# Hostwarden baseline template. Sourced by common.sh, never run.
# shellcheck shell=sh disable=SC2034,SC2154

INIT=systemd

fam_upgrade() {
  dnf -y upgrade
}

fam_install() {
  dnf -y install "$@"
}

fam_user_add() {
  useradd -m -s /bin/bash -G wheel "$1"
  passwd -l "$1"
}

fam_settings() {
  # A main file with no Include (RHEL 8) never reads the login
  # drop-in; refuse the template now, not at every container's boot.
  if ! grep -qi '^Include' /etc/ssh/sshd_config; then
    echo "sshd_config has no Include: release too old" >&2
    return 1
  fi

  cat > /etc/dnf/automatic.conf <<'CONF'
[commands]
upgrade_type = security
apply_updates = yes
CONF
    # Fedora's dnf5 names its timer and configuration differently and
  # is not built (references/proxmox-template.md).
  if [ ! -e /usr/lib/systemd/system/dnf-automatic-install.timer ]; then
    echo "no dnf-automatic-install.timer: not a dnf4 system" >&2
    return 1
  fi
  systemctl enable dnf-automatic-install.timer

    systemctl enable sshd
  install -d -m 0755 /etc/systemd/journald.conf.d

  cat > /etc/systemd/journald.conf.d/50-hostwarden.conf <<'CONF'
[Journal]
Storage=persistent
CONF
  if [ -n "${TIMEZONE:-}" ]; then
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  fi
  # SSH in the permanent configuration before firewalld ever starts
  # (rules/firewalld.md → Starting firewalld).
  firewall-offline-cmd --query-service=ssh ||
    firewall-offline-cmd --add-service=ssh
  systemctl enable firewalld
}

fam_firewall_first_boot() {
  :
}

fam_clean() {
  dnf clean all
}
