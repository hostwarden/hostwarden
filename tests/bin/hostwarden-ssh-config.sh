#!/bin/sh
# tests/bin/hostwarden-ssh-config.sh — fixture matrix for
# bin/hostwarden-ssh-config: which lines of memory/ssh_hosts pass,
# the Match block that tells bin/hostwarden-askpass its target, and
# no forwarding from the user's own file.
# CI runs it through scripts/check.sh; an agent session leaves it to
# CI (.claude/rules/pull-requests.md → Checks).

cd "$(dirname "$0")/../.." || exit 2
REPO=$(pwd -P)
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp ssh-config
TMP=$(cd "$TMP" && pwd -P)

OPS=$TMP/ops
mkdir -p "$OPS/bin" "$OPS/lib" "$OPS/memory" "$OPS/.git" "$TMP/home"
cp "$REPO/bin/hostwarden-ssh-config" "$OPS/bin/"
cp "$REPO/lib/ssh-agent.sh" "$REPO/lib/identity.sh" "$REPO/lib/mode.sh" "$OPS/lib/"
: > "$OPS/memory/.hostwarden-workspace"
git -C "$OPS/memory" init -q
HOME=$TMP/home
export HOME

# gen <ssh_hosts text> — writes the file, runs the script; its
# stderr, then `rc=<n>`.
gen() {
  printf '%s\n' "$1" > "$OPS/memory/ssh_hosts"
  rm -f "$OPS/memory/ssh_config"
  sh "$OPS/bin/hostwarden-ssh-config" 2>&1
  echo "rc=$?"
}
passes() {
  out=$(gen "$1")
  case $out in
    rc=0) grep -qF "$2" "$OPS/memory/ssh_config" && ok ||
      bad "not written: $2" ;;
    *) bad "refused: $1 ($out)" ;;
  esac
}
refused() {
  out=$(gen "$1")
  case $out in
    *rc=0) bad "passed: $1" ;;
    *) grep -q '^Host ' "$OPS/memory/ssh_config" &&
         bad "host blocks written despite: $1" || ok ;;
  esac
}

printf 'SSH agent socket: ~/agent with spaces.sock\n' > "$OPS/memory/user.md"
passes 'Host web1.example.com' "  IdentityAgent \"$HOME/agent with spaces.sock\""
printf 'SSH agent socket: SSH_AUTH_SOCK\n' > "$OPS/memory/user.md"
passes 'Host web1.example.com' '  IdentityAgent SSH_AUTH_SOCK'
printf 'SSH agent socket: $SSH_AUTH_SOCK\n' > "$OPS/memory/user.md"
passes 'Host web1.example.com' '  IdentityAgent SSH_AUTH_SOCK'
printf 'SSH agent socket: none\n' > "$OPS/memory/user.md"
passes 'Host web1.example.com' '  IdentityAgent "none"'
printf 'SSH agent socket: /one\nSSH agent socket: /two\n' > "$OPS/memory/user.md"
# A bad choice is reported, and the file is still written without it.
out=$(gen 'Host web1.example.com')
case $out in
  *'one nonempty SSH agent socket'*rc=0)
    grep -q '^Host web1.example.com' "$OPS/memory/ssh_config" &&
      ! grep -q 'IdentityAgent' "$OPS/memory/ssh_config" && ok ||
      bad 'duplicate agent selection: file wrong' ;;
  *) bad "duplicate agent selection: $out" ;;
esac
rm "$OPS/memory/user.md"

passes 'Host rtr1
  HostName 192.0.2.1
  BatchMode no
  PubkeyAuthentication no
  PreferredAuthentications keyboard-interactive
  NumberOfPasswordPrompts 1' '  PreferredAuthentications keyboard-interactive'
passes 'Host rtr1
  KexAlgorithms +diffie-hellman-group14-sha1,diffie-hellman-group1-sha1
  HostKeyAlgorithms +ssh-rsa
  Ciphers +aes128-cbc
  MACs +hmac-sha1' '  KexAlgorithms +diffie-hellman-group14-sha1,diffie-hellman-group1-sha1'
refused 'Host rtr1
  BatchMode no'
refused 'Host rtr1
  BatchMode no
  PubkeyAuthentication no
  NumberOfPasswordPrompts 1'
refused 'Host rtr1
  BatchMode no
Host rtr2
  PubkeyAuthentication no
  NumberOfPasswordPrompts 1
  PreferredAuthentications password'
refused 'Host rtr1
  BatchMode yes'
refused 'Host rtr1
  PubkeyAuthentication yes'
refused 'Host rtr1
  NumberOfPasswordPrompts 3'
refused 'Host rtr1
  PreferredAuthentications publickey'
refused 'Host rtr1
  PreferredAuthentications keyboard-interactive,password'
refused 'Host rtr1
  KexAlgorithms diffie-hellman-group1-sha1'
refused 'Host rtr1
  Ciphers -aes128-cbc'
refused 'Host rtr1
  HostKeyAlgorithms ^ssh-rsa'
refused 'Host rtr1
  MACs +hmac-sha1,$(id)'
refused 'Host rtr1
  StrictHostKeyChecking no'

# An exclusion in one block does not reach into the note of another.
gen 'Host a !db1
  BatchMode no
  PubkeyAuthentication no
  NumberOfPasswordPrompts 1
  PreferredAuthentications password
Host db1
  BatchMode no
  PubkeyAuthentication no
  NumberOfPasswordPrompts 1
  PreferredAuthentications password' >/dev/null
grep -q '^Match originalhost a,db1 exec' "$OPS/memory/ssh_config" && ok ||
  bad "an exclusion was carried into the Match: $(grep '^Match' "$OPS/memory/ssh_config")"

# The note block: only for the hosts with BatchMode no, last, after
# the standard options and the user's own files, naming this
# checkout's helper.
gen 'Host db1
  HostName 192.0.2.30' >/dev/null
grep -q '^Match originalhost' "$OPS/memory/ssh_config" &&
  bad "a Match block without a password host" || ok
gen 'Host db1
  HostName 192.0.2.30
Host rtr1 rtr1.example.com
  BatchMode no
  PubkeyAuthentication no
  NumberOfPasswordPrompts 1
  PreferredAuthentications password' >/dev/null
M=$(grep -n '^Match originalhost' "$OPS/memory/ssh_config" | cut -d: -f1)
A=$(grep -n '^Match all' "$OPS/memory/ssh_config" | cut -d: -f1)
H=$(grep -n '^Host rtr1' "$OPS/memory/ssh_config" | cut -d: -f1)
if [ -n "$M" ] && [ -n "$A" ] && [ -n "$H" ] && [ "$H" -lt "$A" ] &&
  [ "$A" -lt "$M" ]; then
  ok
else
  bad "the Match block is missing or out of place"
fi
grep -qF "Match originalhost rtr1,rtr1.example.com exec \"exec '$OPS/bin/hostwarden-askpass' --note %n %r %h %p\"" \
  "$OPS/memory/ssh_config" && ok || bad "the Match block names another helper"
ssh -F "$OPS/memory/ssh_config" -G alice@rtr1 >/dev/null 2>&1 && ok ||
  bad "ssh rejects the written file"
# A HostName and Port that only the user's own file sets reach the
# note: the stub takes the place of the helper and writes what it got.
mkdir -p "$HOME/.ssh"
printf 'Host rtr1\n  HostName 192.0.2.1\n  Port 2222\n' > "$HOME/.ssh/config"
mkdir -p "$OPS/bin"
printf '#!/bin/sh\necho "$*" > "%s/note"\nexit 1\n' "$TMP" > "$OPS/bin/hostwarden-askpass"
chmod +x "$OPS/bin/hostwarden-askpass"
ssh -F "$OPS/memory/ssh_config" -G alice@rtr1 >/dev/null 2>&1
[ "$(cat "$TMP/note" 2>/dev/null)" = "--note rtr1 alice 192.0.2.1 2222" ] && ok ||
  bad "the note got: $(cat "$TMP/note" 2>/dev/null)"

# No agent, X11 or port forwarding, whatever the user's own file says:
# the standard options come first, and ssh keeps the first value.
printf 'Host *\n  ForwardAgent yes\n  ForwardX11 yes\n  LocalForward 127.0.0.1:9100 127.0.0.1:80\n  RemoteForward 127.0.0.1:9200 127.0.0.1:80\n' > "$HOME/.ssh/config"
ssh -F "$OPS/memory/ssh_config" -G alice@db1 > "$TMP/g" 2>&1
grep -q '^forwardagent no$' "$TMP/g" && ok ||
  bad "the user's ForwardAgent yes wins"
grep -q '^forwardx11 no$' "$TMP/g" && ok ||
  bad "the user's ForwardX11 yes wins"
grep -qE '^(local|remote)forward ' "$TMP/g" &&
  bad "a forwarding of the user's file is kept" || ok
rm -f "$HOME/.ssh/config"

# --- Hostwarden's own SSH identity (rules/ssh-identity.md) ------
ssh-keygen -q -t ed25519 -N '' -C hostwarden@alice-ws1 -f "$TMP/home/hw"
FP=$(ssh-keygen -E sha256 -lf "$TMP/home/hw.pub" | awk '{ print $2 }')
ssh-keygen -q -t ed25519 -N '' -C other -f "$TMP/home/other"
OTHER=$(ssh-keygen -E sha256 -lf "$TMP/home/other.pub" | awk '{ print $2 }')
idmd() {
  printf '# SSH Identity\n\nSSH identity: %s\nSSH identity key: %s\nSSH identity agent: ~/.cache/hostwarden/agent.sock\nSSH agent socket: /signing.sock\n' \
    "$1" "${2:-~/hw.pub}" > "$OPS/memory/user.md"
}
mkdir -p "$OPS/memory/machines/web1" "$OPS/memory/machines/db1" \
  "$OPS/memory/machines/app1"
printf '# web1\n- IP: 192.0.2.10\n- Reached as: root@web1.example.com\n- Hostwarden key: %s (hostwarden@alice-ws1, 2026-10-21)\n' \
  "$FP" > "$OPS/memory/machines/web1/memory.md"
printf '# db1\n- IP: 192.0.2.11\n' > "$OPS/memory/machines/db1/memory.md"
printf '# app1\n- Hostwarden key: %s (someone else)\n' "$OTHER" \
  > "$OPS/memory/machines/app1/memory.md"
HB='Host w1 web1
  HostName 192.0.2.10
Host db1
  Port 2222'

idmd own-agent
out=$(gen "$HB")
case $out in rc=0) ok ;; *) bad "an identity broke the file: $out" ;; esac
grep -qx 'Match originalhost 192.0.2.10,w1,web1,web1.example.com' \
  "$OPS/memory/ssh_config" && ok ||
  bad "identity hosts: $(grep '^Match originalhost' "$OPS/memory/ssh_config")"
grep -qF "  IdentityAgent \"$HOME/.cache/hostwarden/agent.sock\"" "$OPS/memory/ssh_config" &&
  grep -qx '  IdentitiesOnly yes' "$OPS/memory/ssh_config" &&
  grep -qF "  IdentityFile \"$HOME/hw.pub\"" "$OPS/memory/ssh_config" && ok ||
  bad "the identity lines are missing"
grep -q CertificateFile "$OPS/memory/ssh_config" &&
  bad "a CertificateFile line without a recorded certificate" || ok
# A recorded certificate is named by CertificateFile, since beside
# IdentitiesOnly ssh offers no certificate the agent holds, and only
# to a host whose line says certificate: one that has the key in its
# authorized_keys would refuse the certificate first.
printf 'SSH identity certificate: ~/hw-cert.pub\n' >> "$OPS/memory/user.md"
gen "$HB" >/dev/null
G=$(ssh -F "$OPS/memory/ssh_config" -G root@web1.example.com 2>/dev/null)
printf '%s\n' "$G" | grep -qx 'identitiesonly yes' &&
  ! printf '%s\n' "$G" | grep -q '^certificatefile ' && ok ||
  bad "a host with the key's line got the certificate"
cp "$OPS/memory/machines/web1/memory.md" "$TMP/web1.md"
sed 's/(hostwarden@alice-ws1, /&certificate, /' "$TMP/web1.md" \
  > "$OPS/memory/machines/web1/memory.md"
gen "$HB" >/dev/null
grep -qF "  CertificateFile \"$HOME/hw-cert.pub\"" "$OPS/memory/ssh_config" &&
  ok || bad "the certificate line is missing"
ssh -F "$OPS/memory/ssh_config" -G root@web1.example.com 2>/dev/null |
  grep -qx "certificatefile $HOME/hw-cert.pub" && ok ||
  bad "ssh -G web1 does not pick the certificate"
ssh -F "$OPS/memory/ssh_config" -G root@db1 2>/dev/null |
  grep -q '^certificatefile ' && bad "a host without the key got the certificate" || ok
# Without a recorded certificate, a host that takes it alone keeps
# today's keys, and the message names it.
idmd own-agent
out=$(gen "$HB")
case $out in
  *"keep"*"today's keys: "*web1*rc=0) ok ;;
  *) bad "no warning for a certificate host without a certificate: $out" ;;
esac
ssh -F "$OPS/memory/ssh_config" -G root@web1.example.com 2>/dev/null |
  grep -qx "identityagent $HOME/.cache/hostwarden/agent.sock" &&
  bad "a certificate host got the plain key without a certificate" || ok
cp "$TMP/web1.md" "$OPS/memory/machines/web1/memory.md"
idmd own-agent
gen "$HB" >/dev/null
M=$(grep -n '^Match originalhost' "$OPS/memory/ssh_config" | cut -d: -f1)
A=$(grep -n '^Match all' "$OPS/memory/ssh_config" | cut -d: -f1)
[ -n "$M" ] && [ -n "$A" ] && [ "$M" -lt "$A" ] && ok ||
  bad "the identity block does not stand before Match all"
# The saved signing agent stays for every other host.
grep -qF '  IdentityAgent "/signing.sock"' "$OPS/memory/ssh_config" && ok ||
  bad "the SSH agent socket line went missing"
G=$(ssh -F "$OPS/memory/ssh_config" -G root@web1.example.com 2>/dev/null)
printf '%s\n' "$G" | grep -qx "identityagent $HOME/.cache/hostwarden/agent.sock" &&
  printf '%s\n' "$G" | grep -qx 'identitiesonly yes' && ok ||
  bad "ssh -G web1 does not pick the identity"
G=$(ssh -F "$OPS/memory/ssh_config" -G root@db1 2>/dev/null)
printf '%s\n' "$G" | grep -qx 'identityagent /signing.sock' && ok ||
  bad "a host without the key got the identity"

# A shared-settings block with no HostName adds no other name; a block
# whose HostName is a recorded name makes an alias of every name it
# gives; a recorded name whose block points elsewhere is dropped; a
# DNS alias of the host counts.
gen 'Host web1 dbx
  Port 2222' >/dev/null
grep -qx 'Match originalhost 192.0.2.10,web1,web1.example.com' "$OPS/memory/ssh_config" &&
  ok || bad "a shared block named another host: $(grep '^Match originalhost' "$OPS/memory/ssh_config")"
gen 'Host web1-short
  HostName WEB1.example.com' >/dev/null
grep -qx 'Match originalhost 192.0.2.10,web1,web1-short,web1.example.com' "$OPS/memory/ssh_config" &&
  ok || bad "an alias by HostName: $(grep '^Match originalhost' "$OPS/memory/ssh_config")"
gen 'Host web1
  HostName 198.51.100.9' >/dev/null
grep -qx 'Match originalhost 192.0.2.10,web1.example.com' "$OPS/memory/ssh_config" &&
  ok || bad "a name pointed elsewhere stayed: $(grep '^Match originalhost' "$OPS/memory/ssh_config")"
printf -- '- DNS alias: old-web\n' >> "$OPS/memory/machines/web1/memory.md"
gen 'Host db1
  Port 2222' >/dev/null
grep -qx 'Match originalhost 192.0.2.10,old-web,web1,web1.example.com' "$OPS/memory/ssh_config" &&
  ok || bad "a DNS alias: $(grep '^Match originalhost' "$OPS/memory/ssh_config")"

idmd none
gen "$HB" >/dev/null
grep -q 'IdentitiesOnly' "$OPS/memory/ssh_config" &&
  bad "SSH identity: none wrote identity lines" || ok
rm -f "$OPS/memory/user.md"
gen "$HB" >/dev/null
grep -q 'IdentitiesOnly' "$OPS/memory/ssh_config" &&
  bad "no identity wrote identity lines" || ok

# A line that does not parse or a missing key writes no block, says so,
# and keeps the host blocks.
for v in 'own-agent ~/nosuch.pub' 'own-agent ~/hw' 'own-agent hw.pub' 'sometimes'; do
  set -- $v
  idmd "$1" "${2:-~/hw.pub}"
  out=$(gen "$HB")
  case $out in
    *rc=0) bad "passed: $v" ;;
    *) { ! grep -q 'IdentitiesOnly' "$OPS/memory/ssh_config" &&
         grep -q '^Host db1' "$OPS/memory/ssh_config"; } && ok ||
         bad "wrong file after: $v" ;;
  esac
done
printf 'SSH identity: own-agent\nSSH identity: manager\n' > "$OPS/memory/user.md"
out=$(gen "$HB")
case $out in *rc=0) bad "two SSH identity lines passed" ;; *) ok ;; esac
rm -f "$OPS/memory/user.md"

finish "ssh-config tests"
