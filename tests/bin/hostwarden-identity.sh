#!/bin/sh
# tests/bin/hostwarden-identity.sh — fixture matrix for
# bin/hostwarden-identity and lib/identity.sh: the lines memory/user.md
# takes, the authorized_keys line, and the agent check. Nothing reaches
# a server, and the agent is one of its own in a temporary directory.
# CI runs it through scripts/check.sh; an agent session leaves it to
# CI (.claude/rules/pull-requests.md → Checks).

cd "$(dirname "$0")/../.." || exit 2
REPO=$(pwd -P)
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp identity
TMP=$(cd "$TMP" && pwd -P)

OPS=$TMP/ops
mkdir -p "$OPS/bin" "$OPS/lib" "$OPS/memory" "$OPS/.git" "$TMP/home"
cp "$REPO/bin/hostwarden-identity" "$OPS/bin/"
cp "$REPO/lib/identity.sh" "$REPO/lib/mode.sh" "$OPS/lib/"
: > "$OPS/memory/.hostwarden-workspace"
HOME=$TMP/home
export HOME
AGENT_PID=''
trap '[ -z "$AGENT_PID" ] || kill "$AGENT_PID" 2>/dev/null; rm -rf "$TMP"' \
  EXIT INT TERM

ssh-keygen -q -t ed25519 -N '' -C hostwarden@alice-ws1 -f "$HOME/hw"
FP=$(ssh-keygen -E sha256 -lf "$HOME/hw.pub" | awk '{ print $2 }')
SOCK=$TMP/a.sock
md() {
  printf '# Preferences\n\nOperator: Alice\n\n# SSH Identity\n\n%s\n' "$1" \
    > "$OPS/memory/user.md"
}
run() { sh "$OPS/bin/hostwarden-identity" "$@" 2>&1; echo "rc=$?"; }

# --- nothing recorded ------------------------------------------
rm -f "$OPS/memory/user.md"
case $(run check) in *rc=3) ok ;; *) bad "check without an identity is not 3" ;; esac
md 'SSH identity: none'
case $(run check) in *rc=3) ok ;; *) bad "SSH identity: none is an identity" ;; esac

# --- the template records nothing --------------------------------
cp "$REPO/templates/memory/user.md.example" "$OPS/memory/user.md"
case $(run check) in *rc=3) ok ;; *) bad "the user template records an identity" ;; esac

# --- lines that do not parse -------------------------------------
for l in 'SSH identity: sometimes' \
  "SSH identity: own-agent
SSH identity key: ~/hw" \
  "SSH identity: own-agent
SSH identity key: ~/hw.pub" \
  "SSH identity: own-agent
SSH identity key: hw.pub
SSH identity agent: $SOCK" \
  "SSH identity: own-agent
SSH identity key: ~/hw.pub
SSH identity agent: $SOCK
SSH identity source: rbw hostwarden/key" \
  "SSH identity: manager
SSH identity key: ~/hw.pub
SSH identity agent: $SOCK
SSH identity source: file ~/hw" \
  "SSH identity: own-agent
SSH identity key: ~/h\$(id).pub
SSH identity agent: $SOCK" \
  "SSH identity: own-agent
SSH identity: manager" \
  'SSH identity key: ~/hw.pub'; do
  md "$l"
  case $(run check) in
    *rc=1) ok ;;
    *) bad "accepted: $l" ;;
  esac
done

# --- the authorized_keys line ------------------------------------
md "SSH identity: own-agent
SSH identity key: ~/hw.pub
SSH identity agent: $SOCK
SSH identity source: file ~/hw"
L=$(sh "$OPS/bin/hostwarden-identity" line web1.example.com 2>/dev/null)
case $L in
  "restrict,port-forwarding,pty ssh-ed25519 "*" hostwarden@alice-$(hostname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')") ok ;;
  *) bad "line: $L" ;;
esac
L=$(sh "$OPS/bin/hostwarden-identity" line web1 --from 192.0.2.0/24 \
  --until 20271231 2>/dev/null)
case $L in
  'restrict,port-forwarding,pty,from="192.0.2.0/24",expiry-time="20271231" ssh-ed25519 '*) ok ;;
  *) bad "line with options: $L" ;;
esac
bad_opt() {
  case $(run line web1 "$1" "$2") in
    *rc=1|*rc=2) ok ;;
    *) bad "line took $1 $2" ;;
  esac
}
bad_opt --from '192.0.2.1"'
bad_opt --until 2027-12-31
bad_opt --from 'a b'
case $(run line '-x') in *rc=1) ok ;; *) bad "line took a dash host" ;; esac

# --- the agent ---------------------------------------------------
case $(run check) in
  *'no agent answers'*rc=1) ok ;;
  *) bad "check without an agent: $(run check)" ;;
esac
# A key file without a passphrase is refused before anything loads.
case $(run load </dev/null) in *rc=1) ok ;; *) bad "load ran without a terminal" ;; esac
eval "$(ssh-agent -a "$SOCK" -s)" >/dev/null
AGENT_PID=$SSH_AGENT_PID
case $(run check) in
  *'does not hold'*rc=1) ok ;;
  *) bad "check with an empty agent: $(run check)" ;;
esac
SSH_AUTH_SOCK=$SOCK ssh-add -q "$HOME/hw" </dev/null 2>/dev/null
case $(run check) in
  *"$FP"*rc=0) ok ;;
  *) bad "check with the key loaded: $(run check)" ;;
esac
[ -z "$(run check --quiet | grep -v '^rc=0$')" ] && ok ||
  bad "check --quiet printed something while all is well"

# --- the certificate (rules/ssh-ca.md → Hostwarden's Own Certificate)
ssh-keygen -q -t ed25519 -N '' -C ca -f "$TMP/ca"
ssh-keygen -q -t ed25519 -N '' -C other -f "$TMP/o"
# cert <validity> [<public key>] — signed by the test CA, written
# where memory/user.md records the certificate.
cert() {
  cp "${2:-$HOME/hw.pub}" "$TMP/s.pub"
  ssh-keygen -q -s "$TMP/ca" -I hostwarden@alice -n root -V "$1" \
    "$TMP/s.pub" && cp "$TMP/s-cert.pub" "$HOME/hw-cert.pub"
}
mdc() {
  md "SSH identity: own-agent
SSH identity key: ~/hw.pub
SSH identity agent: $SOCK
SSH identity source: file ~/hw
SSH identity certificate: ~/hw-cert.pub${1:+
SSH identity renew: $1}"
}
mdc 'ca-renew hw'
case $(run check) in
  *'is missing; the user runs: ca-renew hw'*rc=4) ok ;;
  *) bad "check with the certificate missing: $(run check)" ;;
esac
cert +9h
case $(run check) in
  *'certificate hostwarden@alice, valid to '*' left'*rc=0) ok ;;
  *) bad "check with a valid certificate: $(run check)" ;;
esac
[ -z "$(run check --quiet | grep -v '^rc=0$')" ] && ok ||
  bad "check --quiet printed something for a valid certificate"
cert +90m
case $(run check --quiet) in
  *'ends at '*'the user runs: ca-renew hw'*rc=0) ok ;;
  *) bad "check --quiet under two hours left: $(run check --quiet)" ;;
esac
cert -3h:-1h
case $(run check --quiet) in
  *'expired at '*'ca-renew hw'*rc=4) ok ;;
  *) bad "check with an expired certificate: $(run check --quiet)" ;;
esac
cert +2h:+4h
case $(run check --quiet) in
  *'valid only from '*rc=4) ok ;;
  *) bad "check with a certificate not valid yet: $(run check --quiet)" ;;
esac
cert always:forever
case $(run check --quiet) in
  *'valid without end'*rc=0) ok ;;
  *) bad "check --quiet with a certificate without end: $(run check --quiet)" ;;
esac
cert +30h
case $(run check --quiet) in
  *'more than a working day'*rc=0) ok ;;
  *) bad "check --quiet with a certificate of 30 hours: $(run check --quiet)" ;;
esac
cert always:+52w
case $(run check --quiet) in
  *'valid without start'*rc=0) ok ;;
  *) bad "check --quiet with a certificate without start: $(run check --quiet)" ;;
esac
cert +9h "$TMP/o.pub"
case $(run check --quiet) in
  *"certifies "*", not $FP"*rc=4) ok ;;
  *) bad "check with another key's certificate: $(run check --quiet)" ;;
esac
cp "$HOME/hw.pub" "$HOME/hw-cert.pub"
case $(run check --quiet) in
  *'no user certificate'*rc=4) ok ;;
  *) bad "check with a plain key as the certificate: $(run check --quiet)" ;;
esac
mdc ''
cert -3h:-1h
case $(run check --quiet) in
  *'renews it with their CA'*rc=4) ok ;;
  *) bad "check without a renew line: $(run check --quiet)" ;;
esac
# An agent whose lifetime ended does not hide the certificate's end.
SSH_AUTH_SOCK=$SOCK ssh-add -D >/dev/null 2>&1
case $(run check --quiet) in
  *'expired at '*'does not hold'*rc=1) ok ;;
  *) bad "check with an empty agent and an expired certificate: $(run check --quiet)" ;;
esac
SSH_AUTH_SOCK=$SOCK ssh-add -q "$HOME/hw" </dev/null 2>/dev/null
for l in "SSH identity: own-agent
SSH identity key: ~/hw.pub
SSH identity agent: $SOCK
SSH identity certificate: ~/hw.pub" \
  "SSH identity: own-agent
SSH identity key: ~/hw.pub
SSH identity agent: $SOCK
SSH identity renew: ca-renew hw" \
  'SSH identity certificate: ~/hw-cert.pub'; do
  md "$l"
  case $(run check) in
    *rc=1) ok ;;
    *) bad "accepted: $l" ;;
  esac
done
md "SSH identity: manager
SSH identity key: ~/hw.pub
SSH identity agent: $SOCK"
case $(run agent) in *'nothing to do'*rc=0) ok ;; *) bad "agent for a manager" ;; esac
case $(run check) in *rc=0) ok ;; *) bad "check through a manager's agent" ;; esac

# The agent subcommand starts one on a free socket, and replaces a
# socket nobody answers on.
kill "$AGENT_PID" 2>/dev/null
AGENT_PID=''
SOCK2=$TMP/run/b.sock
md "SSH identity: own-agent
SSH identity key: ~/hw.pub
SSH identity agent: $SOCK2"
case $(run agent) in *rc=0) ok ;; *) bad "agent did not start" ;; esac
SSH_AUTH_SOCK=$SOCK2 ssh-add -l >/dev/null 2>&1
[ $? -ne 2 ] && ok || bad "nothing answers on the new socket"
case $(run agent) in *rc=0) ok ;; *) bad "agent with one running" ;; esac
pkill -f "ssh-agent -a $SOCK2" 2>/dev/null

finish "identity tests"
