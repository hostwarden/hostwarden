# Alpine, for the Hostwarden baseline template. Sourced by
# common.sh, never run. Alpine has no mechanism for automatic
# security updates and no journal to make persistent
# (rules/os/alpine.md), so the template has neither; the baseline
# measurement reports the first as a gap.
# shellcheck shell=sh disable=SC2034,SC2154

INIT=openrc

fam_upgrade() {
  apk update
  apk upgrade
}

fam_install() {
  apk update
  apk add "$@"
}

fam_user_add() {
  adduser -D -s /bin/sh -G wheel "$1"
  # A plain sshd refuses a locked account ("!") even for a key;
  # "*" is no password at all, which is what the baseline asks for.
  sed -i "s/^$1:!:/$1:*:/" /etc/shadow
}

fam_settings() {
  if [ -n "${TIMEZONE:-}" ]; then
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  fi
    # The stock /etc/nftables.nft drops incoming traffic except
  # loopback, replies and ICMP and includes /etc/nftables.d/*.nft;
  # SSH is added to that same chain, since a second table's accept
  # would not override the first one's drop (rules/os/alpine.md →
  # Firewall).
  install -d -m 0755 /etc/nftables.d
  cat > /etc/nftables.d/50-hostwarden.nft <<'CONF'
table inet filter {
  chain input {
    tcp dport 22 accept
  }
}
CONF
  rc-update add nftables boot
  rc-update add sshd default
}

fam_firewall_first_boot() {
  :
}

fam_clean() {
  rm -rf /var/cache/apk/*
}
