#!/bin/sh
# tests/bin/hostwarden-password.sh — fixture matrix for
# bin/hostwarden-password, bin/hostwarden-askpass and
# lib/passwords.sh (rules/ssh-passwords.md). CI runs it through
# scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# Everything runs in an operations checkout of its own under TMP,
# with the file store, and with stand-ins for ssh -G, op, rbw and
# bws on PATH. The helper is run under a copy of sh named ssh, the
# name it checks its parent for; that shell's arguments stand in
# for an ssh command line.

cd "$(dirname "$0")/../.." || exit 2
REPO=$(pwd -P)
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp password
TMP=$(cd "$TMP" && pwd -P)

OPS=$TMP/ops
mkdir -p "$OPS/bin" "$OPS/lib" "$OPS/memory" "$OPS/.git" "$TMP/home" \
  "$TMP/fake" "$TMP/sshbin"
cp "$REPO/bin/hostwarden-password" "$REPO/bin/hostwarden-askpass" "$OPS/bin/"
cp "$REPO/lib/passwords.sh" "$REPO/lib/mode.sh" "$OPS/lib/"
: > "$OPS/memory/.hostwarden-workspace"
: > "$OPS/memory/ssh_config"
printf '# SSH Users\n\nDefault: alice\n' > "$OPS/memory/user.md"
HOME=$TMP/home
HOSTWARDEN_PASSWORD_STORE='file'
export HOME HOSTWARDEN_PASSWORD_STORE
unset XDG_DATA_HOME XDG_CONFIG_HOME OP_SERVICE_ACCOUNT_TOKEN BWS_ACCESS_TOKEN

# --- stand-ins ----------------------------------------------------
# ssh -G, for the two fixture hosts, and the login by the method
# none, which names what each offers: rtr1 no key, rtr2 keys too.
cat > "$TMP/fake/ssh" <<'EOF'
#!/bin/sh
u='' p=''
for a; do [ "$p" = -l ] && u=$a; p=$a; last=$a; done
case " $* " in
  *PreferredAuthentications=none*)
    # rtr3 sits behind a jump host that refuses; rtr4 offers only
    # gssapi.
    case $* in
      *" rtr1 true") h=192.0.2.1 m=keyboard-interactive,password ;;
      *" rtr2 true") h=192.0.2.2 m=publickey,password ;;
      *" rtr3 true") h=jump.example.com m=password ;;
      *" rtr4 true") h=192.0.2.4 m=gssapi-with-mic ;;
      *) exit 255 ;;
    esac
    echo "$u@$h: Permission denied ($m)." >&2
    exit 255 ;;
  *" -G "*) ;;
  *) exit 255 ;;
esac
u='' p=''
for a; do [ "$p" = -l ] && u=$a; p=$a; last=$a; done
case $last in rtr1) h=192.0.2.1 ;; rtr2) h=192.0.2.2 ;; rtr3) h=192.0.2.3 ;;
  rtr4) h=192.0.2.4 ;; *) h=$last ;; esac
printf 'user %s\nhostname %s\nport 22\n' "$u" "$h"
EOF
# op read [--no-newline] <reference>, which says which token it saw,
# and op vault list, which prints TMP/op-vaults.
printf '%s' '[{"id":"v1","name":"V"}]' > "$TMP/op-vaults"
cat > "$TMP/fake/op" <<EOF
#!/bin/sh
if [ "\$1 \$2" = "vault list" ]; then cat "$TMP/op-vaults"; exit; fi
[ "\$1" = read ] || exit 1
for a; do ref=\$a; done
printf '%s' "\${OP_SERVICE_ACCOUNT_TOKEN:-}" > "$TMP/op-token"
case \$ref in
  op://V/rtr1/hostwarden) printf 'alice@192.0.2.1:22' ;;
  op://V/rtr1/password) printf 'op-secret' ;;
  op://V/bank/password) printf 'bank-secret' ;;
  op://V/other/hostwarden) printf 'alice@192.0.2.2:22' ;;
  op://V/other/password) printf 'other-secret' ;;
  op://V/slow/*) sleep 60 ;;
  *) echo "no such item" >&2; exit 1 ;;
esac
EOF
# rbw unlocked | get [--field F] <name> <user> | config show, for
# the profile hw alone; locked while TMP/rbw-locked exists.
cat > "$TMP/fake/rbw" <<EOF
#!/bin/sh
[ "\${RBW_PROFILE:-}" = hw ] || exit 1
case \$1 in
  config) echo '{"email": "hostwarden@example.org"}' ;;
  unlocked) [ ! -f "$TMP/rbw-locked" ] ;;
  get)
    shift
    if [ "\$1" = --field ]; then echo 'alice@192.0.2.1:22'; exit 0; fi
    echo 'rbw-secret' ;;
  *) exit 1 ;;
esac
EOF
# bws secret get <id> --output json
cat > "$TMP/fake/bws" <<EOF
#!/bin/sh
[ -n "\${BWS_ACCESS_TOKEN:-}" ] || exit 1
case \$3 in
  11111111-1111-1111-1111-111111111111)
    echo '{"key":"alice@192.0.2.1:22","value":"bws-secret"}' ;;
  33333333-3333-3333-3333-333333333333)
    # The key is read, the value then fails.
    if [ -f "$TMP/bws-once" ]; then rm -f "$TMP/bws-once"; exit 1; fi
    : > "$TMP/bws-once"
    echo '{"key":"alice@192.0.2.1:22"}' ;;
  *) echo '{"key":"somewhere-else","value":"x"}' ;;
esac
EOF
# security find-generic-password, for a keychain that holds nothing:
# 44 is "no such item"; 36 while TMP/sec-down exists, a locked one.
cat > "$TMP/fake/security" <<EOF
#!/bin/sh
[ ! -f "$TMP/sec-down" ] || exit 36
exit 44
EOF
chmod +x "$TMP/fake/"*
PATH=$TMP/fake:$PATH
export PATH
cp /bin/sh "$TMP/sshbin/ssh"
SSHSH=$TMP/sshbin/ssh
AP=$OPS/bin/hostwarden-askpass
PWD_CMD=$OPS/bin/hostwarden-password

# lib <shell code> — runs it with lib/passwords.sh sourced.
lib() { PW_ROOT=$OPS sh -c '. "$PW_ROOT/lib/passwords.sh"; '"$1"; }

# ask <prompt> <ssh arguments…> — the helper under a stand-in ssh
# whose command line carries the arguments, after the note that
# memory/ssh_config's Match exec writes for alice@rtr1. Its stdout
# and stderr, then `rc=<n>`.
ask() {
  pr=$1
  shift
  "$SSHSH" -c '"$1" --note rtr1 alice 192.0.2.1 22
    "$1" "$2" 2>&1; rc=$?; echo "rc=$rc"; exit 0' ssh "$AP" "$pr" "$@"
}
F="-F $OPS/memory/ssh_config"

has() { case $1 in *"$2"*) ok ;; *) bad "$3: $1" ;; esac; }
lacks() { case $1 in *"$2"*) bad "$3: $1" ;; *) ok ;; esac; }

# --- the source lines in memory/user.md ---------------------------
lib 'pw_record alice@rtr1 "local file"
  pw_record bob@rtr1 "1password op://V/rtr1/password"
  pw_record alice@rtr1 "local keychain"'
want=$(printf '# SSH Users\n\nDefault: alice\n\n# SSH Passwords\n\n%s\n%s' \
  '- alice@rtr1: local keychain' '- bob@rtr1: 1password op://V/rtr1/password')
[ "$(cat "$OPS/memory/user.md")" = "$want" ] && ok ||
  bad "pw_record wrote: $(cat "$OPS/memory/user.md")"
[ "$(lib 'pw_source BOB RTR1')" = "1password op://V/rtr1/password" ] && ok ||
  bad "pw_source is not case-blind on the login"
lib 'pw_source carol rtr1' >/dev/null && bad "pw_source found carol" || ok
lib 'pw_unrecord bob@rtr1; pw_unrecord alice@rtr1'
grep -q '^- ' "$OPS/memory/user.md" && bad "pw_unrecord left a line" || ok

for s in 'local' 'local file' 'local keychain' \
  '1password op://V/I/f' '1password op://Vault One/I/S/f' 'rbw hw/My Router' \
  'bws 0123abcd-0123-0123-0123-0123456789ab'; do
  lib "pw_valid_source '$s'" && ok || bad "valid source refused: $s"
done
for s in 'local foo' 'local secret-service' 'rbw My Router' '1password op://V/I' '1password op://V/I/f?attribute=otp' \
  'rbw a;b' 'rbw $(id)' 'bws 42' 'pass show x' ''; do
  lib "pw_valid_source '$s'" && bad "invalid source taken: $s" || ok
done
[ "$(lib 'pw_target alice RTR1.Example.com 2222')" = \
  "alice@rtr1.example.com:2222" ] && ok || bad "pw_target"

# --- the file store's key is created once -------------------------
# Two first runs at once each generate a key; the second must find
# the first's, never replace it.
KEY0=$HOME/.config/hostwarden/password-key
rm -f "$KEY0"
for _ in 1 2 3 4 5 6; do lib 'pw_file_key' & done
wait
[ -s "$KEY0" ] && ok || bad "no key after concurrent first runs"
SUM0=$(cksum < "$KEY0")
for _ in 1 2 3 4; do lib 'pw_file_key' & done
wait
[ "$(cksum < "$KEY0")" = "$SUM0" ] && ok || bad "a second run replaced the key"
ls "$KEY0".* >/dev/null 2>&1 && bad "a temporary key was left behind" || ok
rm -f "$KEY0"

# --- the file store -----------------------------------------------
lib 'printf "%s" "p w!" | pw_local_put file ssh alice@192.0.2.1:22'
[ "$(lib 'pw_local_get file ssh alice@192.0.2.1:22')" = "p w!" ] && ok ||
  bad "the file store did not give back what it stored"
KEYF=$HOME/.config/hostwarden/password-key
[ "$(ls -l "$KEYF" | cut -c1-10)" = "-rw-------" ] && ok ||
  bad "the store's key is not 0600"
if grep -rq 'p w!' "$HOME/.local/share/hostwarden"; then
  bad "the file store holds the password in clear"
else
  ok
fi
lib 'pw_local_has file ssh alice@192.0.2.2:22' &&
  bad "the file store has a target it never stored" || ok

# --- only where no key logs in ---------------------------------------
out=$(sh "$PWD_CMD" check alice@rtr2 2>&1)
has "$out" "offers key logins" "check did not refuse a host that takes keys"
out=$(sh "$PWD_CMD" link alice@rtr2 '1password op://V/other/password' 2>&1)
has "$out" "offers key logins" "link took a host that takes keys"
grep -q 'rtr2' "$OPS/memory/user.md" && bad "a key host got a source line" || ok
out=$(sh "$PWD_CMD" set alice@rtr2 </dev/null 2>&1)
has "$out" "offers key logins" "set took a host that takes keys"
out=$(sh "$PWD_CMD" check alice@rtr3 2>&1)
has "$out" "named no login methods" "a jump host's refusal was read as the target's"
out=$(sh "$PWD_CMD" check alice@rtr4 2>&1)
has "$out" "offers no password login" "a host without a password method passed"
# rtr1's answer, which every helper test below needs.
sh "$PWD_CMD" check alice@rtr1 >/dev/null 2>&1
METHODS=$(find "$HOME/.cache/hostwarden" -name 'methods-*' -type f -exec \
  grep -l keyboard-interactive {} + | head -n 1)
[ -n "$METHODS" ] && ok || bad "check recorded no answer for rtr1"

# --- hostwarden-askpass -------------------------------------------
out=$("$AP" "alice@192.0.2.1's password: " 2>&1)
lacks "$out" "p w!" "run directly, the helper printed the password"
has "$out" "answers ssh only" "run directly, the helper did not refuse"

out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
has "$out" "p w!" "the helper did not answer a password prompt"
has "$out" "rc=0" "the helper did not answer a password prompt"
out=$(ask "(alice@192.0.2.1) Password:" $F alice@rtr1 'grep -i include x | awk -F: 1')
has "$out" "rc=0" "the helper refused keyboard-interactive, or a remote command"
for pr in "Enter passphrase for key '/home/alice/.ssh/id_ed25519': " \
  "Are you sure you want to continue connecting (yes/no)? " \
  "(alice@192.0.2.1) Verification code:" "(alice@192.0.2.1) New password:"; do
  out=$(ask "$pr" $F alice@rtr1)
  lacks "$out" "p w!" "the helper answered: $pr"
done
out=$(ask "alice@192.0.2.1's password: " alice@rtr1)
lacks "$out" "p w!" "the helper answered an ssh without memory/ssh_config"
for o in "-o StrictHostKeyChecking=no" "-oUserKnownHostsFile=/dev/null" \
  "-o ProxyCommand=nc" "-o KnownHostsCommand=/bin/true"; do
  out=$(ask "alice@192.0.2.1's password: " $F $o alice@rtr1)
  lacks "$out" "p w!" "the helper answered with $o"
done

# A host or user name that holds a word of the refused prompts is
# still a password prompt, and so is one without a colon.
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
out=$(ask "admin@encoder1.example.com's password: " $F alice@rtr1)
has "$out" "p w!" "a host named encoder1 read as a one-time code"
out=$(ask "(otp-admin@192.0.2.1) Enter password" $F alice@rtr1)
has "$out" "p w!" "a keyboard-interactive prompt without a colon, or a user named otp-"
# A refusal ends the ssh process: the stand-in never prints rc=.
out=$(ask "Enter passphrase for key 'k': " $F alice@rtr1)
lacks "$out" "rc=" "a refusal left the ssh process running"
# -F through a symbolic link to the checkout counts.
ln -s "$OPS" "$TMP/link"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
out=$(ask "alice@192.0.2.1's password: " -F "$TMP/link/memory/ssh_config" alice@rtr1)
has "$out" "p w!" "-F through a link to the checkout was refused"
# ...and one whose path holds a space.
ln -s "$OPS" "$TMP/li nk"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
out=$(ask "alice@192.0.2.1's password: " -F "$TMP/li nk/memory/ssh_config" alice@rtr1)
has "$out" "p w!" "-F with a space in the checkout's path was refused"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*

# No answer, or one that names publickey: no password.
mv "$METHODS" "$METHODS.keep"
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
lacks "$out" "p w!" "the helper answered without knowing the host takes no key"
has "$out" "bin/hostwarden-password check" "the refusal did not name check"
echo publickey,password > "$METHODS"
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
lacks "$out" "p w!" "the helper answered a host that offers keys"
mv "$METHODS.keep" "$METHODS"
# A refusal before the password is read does not count: three of
# them leave the next login its answer.
mv "$KEYF" "$KEYF.keep"
for _ in 1 2 3; do ask "alice@192.0.2.1's password: " $F alice@rtr1 >/dev/null; done
mv "$KEYF.keep" "$KEYF"
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
has "$out" "p w!" "refusals counted toward the three"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*

# The cleanup takes old notes, never an answer about login methods.
OLDM=${METHODS%/*}/methods-0
: > "$OLDM"
touch -t 200001010000 "$OLDM"
ask "alice@192.0.2.1's password: " $F alice@rtr1 >/dev/null
[ -f "$OLDM" ] && ok || bad "the cleanup removed an answer about login methods"
rm -f "$OLDM" "$HOME"/.cache/hostwarden/*/askpass/count-*

# A note whose start time is not the process's is stale.
PIDNOTE=$("$SSHSH" -c 'echo $$; "$1" --note rtr1 alice 192.0.2.1 22
  sleep 0' ssh "$AP")
NOTEF=$(find "$HOME/.cache/hostwarden" -name "$PIDNOTE" -type f | head -1)
[ -n "$NOTEF" ] && ok || bad "the note was not written"
[ "$(sed -n 2,5p "$NOTEF" | tr '\n' ' ')" = "rtr1 alice 192.0.2.1 22 " ] &&
  ok || bad "the note holds: $(cat "$NOTEF")"

# Three answers a quarter hour, per target: the tests above gave
# two. Clear the count and give three, then the fourth is refused.
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
for _ in 1 2 3; do ask "alice@192.0.2.1's password: " $F alice@rtr1 >/dev/null; done
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
lacks "$out" "p w!" "the helper answered a fourth time"
has "$out" "15 minutes" "the fourth refusal did not say why"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*

# Password managers: only an entry that names the target.
askm() {
  lib "pw_record alice@rtr1 '$1'"
  rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
  ask "alice@192.0.2.1's password: " $F alice@rtr1
}
# 1Password only through a service account's token.
out=$(askm '1password op://V/rtr1/password')
lacks "$out" "op-secret" "1Password: a password without a service account token"
has "$out" "service account" "1Password: the missing token was not named"
lib 'printf %s tok-1p | pw_local_put file token 1password'
out=$(askm '1password op://V/rtr1/password')
has "$out" "op-secret" "1Password: a bound entry gave nothing"
out=$(askm '1password op://V/bank/password')
lacks "$out" "bank-secret" "1Password: an entry without the field gave its password"
out=$(askm '1password op://V/other/password')
lacks "$out" "other-secret" "1Password: an entry for another target gave its password"
askm '1password op://V/rtr1/password' >/dev/null
[ "$(cat "$TMP/op-token")" = tok-1p ] && ok ||
  bad "1Password: the stored token did not reach op's environment"
: > "$TMP/rbw-locked"
out=$(askm 'rbw hw/Router')
lacks "$out" "rbw-secret" "rbw: a locked vault gave a password"
has "$out" "rbw unlock" "rbw: a locked vault was not named"
rm -f "$TMP/rbw-locked"
out=$(askm 'rbw hw/Router')
has "$out" "rbw-secret" "rbw: a bound entry gave nothing"
out=$(askm 'rbw mine/Router')
lacks "$out" "rbw-secret" "rbw: a profile other than the one named answered"
if command -v jq >/dev/null 2>&1; then
  out=$(askm 'bws 11111111-1111-1111-1111-111111111111')
  lacks "$out" "bws-secret" "bws: a password without a stored token"
  lib 'printf %s tok-bws | pw_local_put file token bws'
  out=$(askm 'bws 11111111-1111-1111-1111-111111111111')
  has "$out" "bws-secret" "bws: a bound secret gave nothing"
  out=$(askm 'bws 22222222-2222-2222-2222-222222222222')
  lacks "$out" "rc=0" "bws: a secret named otherwise was answered"
  out=$(askm 'bws 33333333-3333-3333-3333-333333333333')
  lacks "$out" "rc=0" "bws: a failed read was answered, empty"
else
  bad "jq is missing, which the bws cases need"
fi
lib 'pw_unrecord alice@rtr1'

# Logins at once cannot pass the third answer together: six at the
# same moment for one target get three passwords.
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
for i in 1 2 3 4 5 6; do
  ask "alice@192.0.2.1's password: " $F alice@rtr1 > "$TMP/par.$i" &
done
wait
GOT=$(cat "$TMP"/par.* | grep -c 'p w!')
[ "$GOT" -eq 3 ] && ok || bad "six logins at once got $GOT passwords, not 3"
rm -f "$TMP"/par.* "$HOME"/.cache/hostwarden/*/askpass/count-*
# A lock a dead process left behind is taken over after two minutes.
CNT=$(ls -d "$HOME"/.cache/hostwarden/*/askpass 2>/dev/null | head -n 1)
CF=$(printf %s 'alice@192.0.2.1:22' | cksum | cut -d' ' -f1)
mkdir "$CNT/count-$CF.lock"
touch -t 200001010000 "$CNT/count-$CF.lock"
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
has "$out" "p w!" "a stale lock was not taken over"
[ -d "$CNT/count-$CF.lock" ] && bad "the lock was not released" || ok
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*

# The limit ends the CLI itself, not only the shell around it.
T0=$(date +%s)
lib 'pw_limit 2 pw_op read op://V/slow/hostwarden' >/dev/null 2>&1
[ $(($(date +%s) - T0)) -lt 20 ] && ok || bad "pw_limit left op running"

# A source line the Markdown wrap broke is read back whole, and
# replaced whole.
printf '%s\n' '# SSH Passwords' '' \
  '- alice@rtr1: 1password' '  op://V/rtr1/password' '- bob@rtr1: local' \
  > "$OPS/memory/user.md"
[ "$(lib 'pw_source alice rtr1')" = "1password op://V/rtr1/password" ] && ok ||
  bad "a wrapped source line was read in part: $(lib 'pw_source alice rtr1')"
lib 'pw_record alice@rtr1 "local file"'
grep -q 'op://' "$OPS/memory/user.md" && bad "pw_record left the wrapped rest" || ok
grep -qx -- '- bob@rtr1: local' "$OPS/memory/user.md" && ok ||
  bad "pw_record took the next login with it"
printf '# SSH Users\n\nDefault: alice\n' > "$OPS/memory/user.md"

# --- hostwarden-password ------------------------------------------
out=$(sh "$PWD_CMD" set alice@rtr1 </dev/null 2>&1)
has "$out" "needs a terminal" "set ran without a terminal"
out=$(sh "$PWD_CMD" token 1password </dev/null 2>&1)
has "$out" "needs a terminal" "token ran without a terminal"
out=$(sh "$PWD_CMD" check alice@rtr1 2>&1)
has "$out" "(alice@192.0.2.1:22): in the file store" "check without a line"
sh "$PWD_CMD" check alice@rtr2 >/dev/null 2>&1 &&
  bad "check found a password for rtr2" || ok
out=$(sh "$PWD_CMD" link alice@rtr1 'rbw a;b' 2>&1)
has "$out" "not a source" "link took an invalid source"
out=$(sh "$PWD_CMD" link alice@rtr1 '1password op://V/bank/password' 2>&1)
has "$out" "must hold alice@192.0.2.1:22" "link took an unbound entry"
grep -q 'bank' "$OPS/memory/user.md" && bad "link recorded an unbound entry" || ok
# Only through an identity that sees Hostwarden's entries alone.
printf '%s' '[{"id":"v1","name":"V"},{"id":"v2","name":"Private"}]' \
  > "$TMP/op-vaults"
out=$(sh "$PWD_CMD" link alice@rtr1 '1password op://V/rtr1/password' 2>&1)
has "$out" "sees 2 vaults" "link took a service account that sees two vaults"
printf '%s' '[{"id":"v2","name":"Other"}]' > "$TMP/op-vaults"
out=$(sh "$PWD_CMD" link alice@rtr1 '1password op://V/rtr1/password' 2>&1)
has "$out" "another vault" "link took a reference to a vault the account cannot see"
printf '%s' '[{"id":"v1","name":"V"}]' > "$TMP/op-vaults"
out=$(sh "$PWD_CMD" link alice@rtr1 'rbw mine/Router' 2>&1)
has "$out" "not set up" "link took an rbw profile that is not set up"
out=$(sh "$PWD_CMD" link alice@rtr1 'rbw hw/Router' 2>&1)
grep -qx -- '- alice@rtr1: rbw hw/Router' "$OPS/memory/user.md" && ok ||
  bad "link did not record a set-up rbw profile: $out"
out=$(sh "$PWD_CMD" link alice@rtr1 '1password op://V/rtr1/password' 2>&1)
lacks "$out" "op-secret" "link printed the password"
grep -qx -- '- alice@rtr1: 1password op://V/rtr1/password' \
  "$OPS/memory/user.md" && ok || bad "link recorded no line"
out=$(sh "$PWD_CMD" check alice@rtr1 2>&1)
has "$out" "entry names the target" "check of a linked entry"
lacks "$out" "op-secret" "check printed the password"
sh "$PWD_CMD" remove alice@rtr1 >/dev/null 2>&1
grep -q '^- alice@rtr1' "$OPS/memory/user.md" && bad "remove kept the line" || ok
lib 'pw_record alice@rtr1 "local file"'
sh "$PWD_CMD" remove alice@rtr1 >/dev/null 2>&1
lib 'pw_local_has file ssh alice@192.0.2.1:22' &&
  bad "remove kept the stored password" || ok
# A password stored before a link goes too, from whichever local
# store holds it, or it would answer again once the line is gone.
lib 'printf %s old | pw_local_put file ssh alice@192.0.2.1:22
  pw_record alice@rtr1 "1password op://V/rtr1/password"'
HOSTWARDEN_PASSWORD_STORE=keychain sh "$PWD_CMD" remove alice@rtr1 \
  >/dev/null 2>&1
lib 'pw_local_has file ssh alice@192.0.2.1:22' &&
  bad "remove kept a password stored before the link" || ok
# A store that cannot be asked is not an empty one: nothing is
# forgotten and the line stays.
lib 'printf %s old | pw_local_put file ssh alice@192.0.2.1:22
  pw_record alice@rtr1 "local file"'
: > "$TMP/sec-down"
out=$(HOSTWARDEN_PASSWORD_STORE=keychain sh "$PWD_CMD" remove alice@rtr1 2>&1)
has "$out" "could not be checked" "remove called an unreachable keychain empty"
grep -q '^- alice@rtr1' "$OPS/memory/user.md" && ok ||
  bad "remove dropped the line although the keychain could not be checked"
lib 'pw_local_has file ssh alice@192.0.2.1:22' && ok ||
  bad "remove deleted the file store's password before it was sure"
rm -f "$TMP/sec-down"
HOSTWARDEN_PASSWORD_STORE=keychain sh "$PWD_CMD" remove alice@rtr1 \
  >/dev/null 2>&1
lib 'pw_local_has file ssh alice@192.0.2.1:22' &&
  bad "remove kept the password once the keychain answered" || ok
out=$(sh "$REPO/bin/hostwarden-password" check alice@rtr1 2>&1)
has "$out" "only an operations checkout" "ran outside an operations checkout"

finish "password tests"
