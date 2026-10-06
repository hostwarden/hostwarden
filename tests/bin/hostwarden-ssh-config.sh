#!/bin/sh
# tests/bin/hostwarden-ssh-config.sh — fixture matrix for
# bin/hostwarden-ssh-config: which lines of memory/ssh_hosts pass,
# and the Match block that tells bin/hostwarden-askpass its target.
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
cp "$REPO/lib/ssh-agent.sh" "$REPO/lib/mode.sh" "$OPS/lib/"
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
out=$(gen 'Host web1.example.com')
case $out in *rc=0) bad 'duplicate agent selection accepted' ;; *) ok ;; esac
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
rm -f "$HOME/.ssh/config"

finish "ssh-config tests"
