#!/bin/sh
# The login of a container made from the Hostwarden baseline
# template, placed on its first boot, before sshd first starts.
# Run by the first-boot login unit; never run by hand.
set -eu

# shellcheck source=/dev/null
. /usr/local/lib/hostwarden/firstboot/common.sh
# shellcheck disable=SC2154 # dir comes from common.sh

install -D -m 0644 "$dir/login.conf" \
  /etc/ssh/sshd_config.d/10-hostwarden.conf

home=$(getent passwd "$SSH_USER" | cut -d: -f6)
group=$(id -gn "$SSH_USER")
install -d -m 0700 -o "$SSH_USER" -g "$group" "$home/.ssh"
# Added to what is there, so a key `pct create --ssh-public-keys`
# gave root stays.
keys=$home/.ssh/authorized_keys
touch "$keys"
chown "$SSH_USER:$group" "$keys"
chmod 0600 "$keys"
while IFS= read -r key || [ -n "$key" ]; do
  [ -n "$key" ] || continue
  grep -qxF -- "$key" "$keys" || printf '%s\n' "$key" >> "$keys"
done < "$dir/admin-keys"

# The service that follows starts sshd on what was just written; if
# that does not parse, this unit fails and sshd never starts. The
# directory sshd wants exists only once sshd's own unit has made it.
install -d -m 0755 /run/sshd
sshd -t
# A drop-in sshd does not read (a main file with no Include, as on
# RHEL 8) parses fine and does nothing: judge what sshd will use.
eff=$(sshd -T)
printf '%s\n' "$eff" | grep -qix 'passwordauthentication no'
printf '%s\n' "$eff" | grep -qEix 'permitrootlogin (prohibit-password|without-password|no)'


install -d -m 0755 /var/lib/hostwarden
: > /var/lib/hostwarden/login.done
