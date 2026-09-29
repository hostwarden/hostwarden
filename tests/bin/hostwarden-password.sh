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
cp -R "$REPO/lib/passwords" "$OPS/lib/"
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
[ -f "$FAKE_SSH_OLD" ] && [ "$1" = -V ] && { echo "OpenSSH_8.2p1" >&2; exit 0; }
[ "$1" = -V ] && { echo "OpenSSH_9.8p1" >&2; exit 0; }
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
# shellcheck disable=SC2034 # read by the parts
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
# shellcheck disable=SC2034 # read by the parts
F="-F $OPS/memory/ssh_config"

has() { case $1 in *"$2"*) ok ;; *) bad "$3: $1" ;; esac; }
lacks() { case $1 in *"$2"*) bad "$3: $1" ;; *) ok ;; esac; }

# The rest lives in tests/bin/hostwarden-password/, one file per stage,
# sourced in this order into this shell: each reads what the ones
# before it set.
PARTS='store askpass command'
for part in $PARTS; do
  [ -f "$REPO/tests/bin/hostwarden-password/$part.sh" ] || {
    echo "${0##*/}: tests/bin/hostwarden-password/$part.sh is missing" >&2
    exit 1
  }
done
for part in $PARTS; do
  # shellcheck source=/dev/null
  . "$REPO/tests/bin/hostwarden-password/$part.sh"
done

finish "password tests"
