# lib/hostwarden-heinzel-takeover/known-hosts.sh — the host keys the
# old checkout trusted. Sourced by bin/hostwarden-heinzel-takeover,
# in the order its PARTS lists, into the one shell every part
# shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it


# Host keys the old checkout trusted. An override can
# point ssh at memory/known_hosts (UserKnownHostsFile);
# without the file, every login under it fails, or it
# trusts whatever key the next connection is shown.
# Only the records come across — host keys, and
# @cert-authority and @revoked lines, the last so that
# a key revoked there stays revoked here — cut after the
# key: a comment, on its own line or after a key, can
# hold anything, a password included, and this file is
# shared. A record counts only when its key type is one
# ssh knows and its key starts with that same type,
# encoded: every key does, and a note that merely looks
# like a record ("x ssh-password secret") does not. A
# file holding a private key is not copied at all
# (rules/secrets.md). grep and sed, because they read
# the file without running anything it contains.
KH_SRC="$OLD/memory/known_hosts"
KH_DST="memory/known_hosts"
# <type, a dot escaped> <base64 of its length and
# name, in whole 3-byte groups>: the plain key types,
# then their host certificates (ssh-keyscan -c).
KH_TYPES="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5
ssh-rsa AAAAB3NzaC1y
ssh-dss AAAAB3NzaC1k
ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAy
ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAz
ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1
sk-ssh-ed25519@openssh\.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29t
sk-ecdsa-sha2-nistp256@openssh\.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5j
ssh-ed25519-cert-v01@openssh\.com AAAAIHNzaC1lZDI1NTE5LWNlcnQtdjAxQG9wZW5zc2guY29t
ssh-rsa-cert-v01@openssh\.com AAAAHHNzaC1yc2EtY2VydC12MDFAb3BlbnNzaC5j
ssh-dss-cert-v01@openssh\.com AAAAHHNzaC1kc3MtY2VydC12MDFAb3BlbnNzaC5j
ecdsa-sha2-nistp256-cert-v01@openssh\.com AAAAKGVjZHNhLXNoYTItbmlzdHAyNTYtY2VydC12MDFAb3BlbnNzaC5j
ecdsa-sha2-nistp384-cert-v01@openssh\.com AAAAKGVjZHNhLXNoYTItbmlzdHAzODQtY2VydC12MDFAb3BlbnNzaC5j
ecdsa-sha2-nistp521-cert-v01@openssh\.com AAAAKGVjZHNhLXNoYTItbmlzdHA1MjEtY2VydC12MDFAb3BlbnNzaC5j
sk-ssh-ed25519-cert-v01@openssh\.com AAAAI3NrLXNzaC1lZDI1NTE5LWNlcnQtdjAxQG9wZW5zc2guY29t
sk-ecdsa-sha2-nistp256-cert-v01@openssh\.com AAAAK3NrLWVjZHNhLXNoYTItbmlzdHAyNTYtY2VydC12MDFAb3BlbnNzaC5j"
KH_ALT=''
for KH_T in $KH_TYPES; do
  KH_ALT="$KH_ALT${KH_ALT:+|}${KH_T%% *}[[:space:]]+${KH_T#* }"
done
KH_REC="($KH_ALT)[A-Za-z0-9+/]*={0,2}([[:space:]]|\$)"
KH_KEEP="^@(cert-authority|revoked)[[:space:]]+[^[:space:]]+[[:space:]]+$KH_REC|^[^@#[:space:]][^[:space:]]*[[:space:]]+$KH_REC"
KH_CUT='s/^((@[^[:space:]]+[[:space:]]+)?[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+).*/\1/'
if [ -e "$KH_SRC" ] || [ -L "$KH_SRC" ]; then
  # The records, read once; empty when there is
  # nothing to copy.
  KH_PUB=''
  if [ ! -f "$KH_SRC" ]; then
    echo "skipped memory/known_hosts — not a readable file in the old checkout" >&2
  elif grep -q 'PRIVATE KEY' "$KH_SRC"; then
    echo "skipped memory/known_hosts — it holds a private key; left in the old checkout" >&2
  else
    KH_PUB=$(grep -E "$KH_KEEP" "$KH_SRC" | sed -E "$KH_CUT" || :)
    [ -n "$KH_PUB" ] || echo "skipped memory/known_hosts — no host key line in it" >&2
  fi
  if [ -z "$KH_PUB" ]; then
    :
  elif [ ! -L "$KH_DST" ] \
      && printf '%s\n' "$KH_PUB" | cmp -s - "$KH_DST" 2>/dev/null; then
    NOTHING_LEFT=yes
  elif occupied "$KH_SRC" "$KH_DST" && [ -z "$FORCE" ]; then
    SHARED_PENDING="$SHARED_PENDING known_hosts"
  else
    KH_OUT=$(( $(grep -c '' "$KH_SRC") - $(printf '%s\n' "$KH_PUB" | grep -c '') ))
    KH_NOTE=''
    [ "$KH_OUT" -le 0 ] || KH_NOTE=" (host keys only, $KH_OUT lines left out)"
    plan "known_hosts$KH_NOTE"
    if [ -z "$LIST" ]; then
      rm -rf "$KH_DST"
      printf '%s\n' "$KH_PUB" > "$KH_DST"
    fi
  fi
fi
