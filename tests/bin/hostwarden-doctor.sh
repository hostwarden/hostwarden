#!/bin/sh
# tests/bin/hostwarden-doctor.sh — fixture matrix for the doctor's
# key check, lib/hostwarden-doctor/keys.sh. CI runs it through
# scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# ssh and ssh-add are stubs that print what a fixture gives them;
# ssh-keygen is the real one, run on keys made here, in a home of
# their own. Every check also holds the output free of key material.

# SC2034: keys.sh reads the variables set here. SC2088: a literal ~
# is what a row shows.
# shellcheck disable=SC2034,SC2088
cd "$(dirname "$0")/../.." || exit 2
ROOT=$(pwd -P)
# shellcheck source=../helpers.sh
. "$ROOT/tests/helpers.sh"
test_tmp doctor

command -v ssh-keygen >/dev/null 2>&1 || { echo "doctor: no ssh-keygen"; exit 2; }

HOME=$TMP/home
mkdir -p "$HOME/.ssh" "$TMP/bin"
K=$HOME/.ssh
ssh-keygen -q -t ed25519 -N '' -C fixture -f "$K/bare" </dev/null
ssh-keygen -q -t ed25519 -N fixture-pass -C fixture -f "$K/locked" \
  </dev/null
ssh-keygen -q -t ed25519 -N fixture-pass -C fixture -f "$K/hw" </dev/null
# A hardware key's public half; the private file stands in for the
# handle, which needs a token to make.
{ read -r _ b _ < "$K/hw.pub"; echo "sk-ssh-ed25519@openssh.com $b fixture"; } \
  > "$K/hw.tmp" && mv "$K/hw.tmp" "$K/hw.pub"
read -r _ BLOB _ < "$K/bare.pub"

# The stubs read what to do from files in TMP.
cat > "$TMP/bin/ssh" <<'EOF'
#!/bin/sh
[ ! -f "$FIX/sleep" ] || sleep "$(cat "$FIX/sleep")"
[ ! -f "$FIX/fail" ] || exit 255
cat "$FIX/g"
EOF
cat > "$TMP/bin/ssh-add" <<'EOF'
#!/bin/sh
[ -f "$FIX/agent" ] || exit 2
# Slow for every socket, or for the one slow-sock names.
if [ -f "$FIX/agent-sleep" ] && { [ ! -f "$FIX/slow-sock" ] ||
    [ "$SSH_AUTH_SOCK" = "$(cat "$FIX/slow-sock")" ]; }; then
  sleep "$(cat "$FIX/agent-sleep")"
fi
# The socket other-sock names lists other-agent instead.
A=$FIX/agent
[ ! -f "$FIX/other-sock" ] || [ "$SSH_AUTH_SOCK" != "$(cat "$FIX/other-sock")" ] \
  || A=$FIX/other-agent
# An agent with none says so on stdout, as ssh-add does.
[ -s "$A" ] || { echo "The agent has no identities."; exit 1; }
cat "$A"
EOF
chmod +x "$TMP/bin/ssh" "$TMP/bin/ssh-add"
PATH=$TMP/bin:$PATH
FIX=$TMP/fix
export FIX HOME

# What the doctor defines before it sources keys.sh.
INSTALL_DOCS=https://example.invalid/install
QUIET=''
has() { command -v "$1" >/dev/null 2>&1; }
row() { echo "  $1"; }
KEYM=''
miss() { KEYM="$KEYM
  $2: $3"; }
# DEV keeps the section from running on source; keys_report is
# called below.
DEV=1
# shellcheck source=../../lib/hostwarden-doctor/checks.sh
. "$ROOT/lib/hostwarden-doctor/checks.sh"
# shellcheck source=../../lib/hostwarden-doctor/keys.sh
. "$ROOT/lib/hostwarden-doctor/keys.sh"
DEV=''
# The checkout keys.sh reads memory/ from: one of its own.
ROOT=$TMP/root
mkdir -p "$ROOT/memory"

# run <identityfile lines...> — a fresh fixture, and keys_report's
# rows and lines in OUT.
run() {
  rm -rf "$FIX"
  mkdir -p "$FIX"
  : > "$FIX/g"
  for l in "$@"; do echo "$l" >> "$FIX/g"; done
}
report() {
  KEYM=''
  OUT=$(SSH_AUTH_SOCK='' keys_report; echo "$KEYM")
  case $OUT in
    *PRIVATE*|*"$BLOB"*) bad "$1: key material in the output" ;;
    *) ok ;;
  esac
}
has_line() {
  case $OUT in *"$2"*) ok ;; *) bad "$1: no '$2' in:"; echo "$OUT" ;; esac
}
no_line() {
  case $OUT in *"$2"*) bad "$1: '$2' in:"; echo "$OUT" ;; *) ok ;; esac
}

# A key file without a passphrase: a WARN row and a line for --quiet.
run 'identityfile ~/.ssh/bare' 'identityfile ~/.ssh/locked'
report bare
has_line bare 'WARN     ~/.ssh/bare, no passphrase'
has_line bare '~/.ssh/bare: no passphrase'
has_line bare 'file     ~/.ssh/locked, passphrase set'
no_line bare '~/.ssh/bare: a key neither'
has_line bare '~/.ssh/locked: a key neither agent-held nor hardware'

# A passphrase, no agent, no hardware: the hint, and no WARN.
run 'identityfile ~/.ssh/locked'
report locked
no_line locked WARN
has_line locked 'a key neither agent-held nor hardware'

# A hardware key: classified so, by its public half.
run 'identityfile ~/.ssh/hw' 'identityfile ~/.ssh/locked'
report hardware
has_line hardware 'hardware ~/.ssh/hw'
# A hardware key elsewhere does not make the locked file usable.
no_line hardware '~/.ssh/hw: a key neither'
has_line hardware '~/.ssh/locked: a key neither agent-held'

# %d and %u are filled in, a host's token is not checked, none and a
# .pub are skipped, a missing file and a repeated one are left out.
run 'identityfile %d/.ssh/bare' 'identityfile ~/.ssh/k_%h' \
  'identityfile none' 'identityfile ~/.ssh/bare.pub' \
  'identityfile ~/.ssh/missing' 'identityfile ~/.ssh/bare'
report tokens
has_line tokens 'WARN     ~/.ssh/bare, no passphrase'
has_line tokens 'unchecked ~/.ssh/k_%h'
no_line tokens 'bare.pub'
no_line tokens missing
n=$(printf '%s\n' "$OUT" | grep -c 'WARN ')
[ "$n" -eq 1 ] && ok || bad "tokens: $n WARN rows for one file"

# An agent, named by its socket, its identities counted.
# A real socket for the file-type check; the stub answers for it.
# Under /tmp: a socket path past about 104 bytes, as macOS's TMPDIR
# makes it, cannot be bound.
SD=$(mktemp -d /tmp/1password.XXXXXX) || exit 2
SOCK=$SD/a.sock
AGENT_PID=$(ssh-agent -a "$SOCK" | sed -n 's/^SSH_AGENT_PID=\([0-9]*\);.*/\1/p')
[ -S "$SOCK" ] || bad "agent: no socket"
run "identityagent $SOCK" 'identityfile ~/.ssh/locked'
printf '%s\n' '256 SHA256:aaaa alice@example.com (ED25519)' \
  '256 SHA256:bbbb alice@example.com (ED25519-SK)' > "$FIX/agent"
report agent
has_line agent 'agent    1Password, 2 keys, 1 hardware'
no_line agent 'SHA256:'
# Keys of its own are not the locked file's.
has_line agent '~/.ssh/locked: a key neither agent-held'
# The locked file's own key in the agent, matched by fingerprint:
# from the public half beside it, and, without one, from the key
# file of OpenSSH's format, whose public half is in the clear.
read -r _ FP _ <<EOF
$(ssh-keygen -l -f "$K/locked.pub")
EOF
cp "$K/locked" "$K/nopub"
run "identityagent $SOCK" 'identityfile ~/.ssh/locked' \
  'identityfile ~/.ssh/nopub'
echo "256 $FP alice@example.com (ED25519)" > "$FIX/agent"
report held
has_line held 'file     ~/.ssh/locked, passphrase set, in an agent'
has_line held 'file     ~/.ssh/nopub, passphrase set, in an agent'
no_line held 'neither agent-held'
no_line held "$FP"
rm -f "$K/nopub"
# A host's own block in ~/.ssh/config: its key file, and its agent,
# asked once.
SD2=$(mktemp -d /tmp/bitwarden.XXXXXX) || exit 2
SOCK2=$SD2/a.sock
AGENT2_PID=$(ssh-agent -a "$SOCK2" | sed -n 's/^SSH_AGENT_PID=\([0-9]*\);.*/\1/p')
# Only the blocks of hosts Hostwarden knows count: a Git forge's key
# is none of its business.
mkdir -p "$ROOT/memory/machines/web1.example.com" \
  "$ROOT/memory/machines/db1.example.com"
cp "$K/bare" "$K/forge"
cp "$K/bare" "$K/alias"
cp "$K/bare" "$K/everyone"
printf '%s\n' 'Host web1.example.com' '  IdentityFile ~/.ssh/bare' \
  "  IdentityAgent \"$SOCK2\"" 'Host db1.*' \
  "  IdentityAgent $SOCK2" 'Host git.example.org' \
  '  IdentityFile ~/.ssh/forge' 'Host web' '  IdentityFile ~/.ssh/alias' \
  '  HostName web1.example.com' 'Match host git.example.org,git.example.net' \
  '  IdentityFile ~/.ssh/forge' 'Match exec "true"' \
  '  IdentityFile ~/.ssh/forge' 'Match all' \
  '  IdentityFile ~/.ssh/everyone' > "$HOME/.ssh/config"
run "identityagent $SOCK" 'identityfile ~/.ssh/locked'
: > "$FIX/agent"
report host-block
has_line host-block 'WARN     ~/.ssh/bare, no passphrase'
has_line host-block "agent    Bitwarden, 0 keys, a host's own"
# An alias whose HostName is a known host, before its HostName line.
has_line host-block 'WARN     ~/.ssh/alias, no passphrase'
has_line host-block 'WARN     ~/.ssh/everyone, no passphrase'
no_line host-block forge
n=$(printf '%s\n' "$OUT" | grep -c "a host's own")
[ "$n" -eq 1 ] && ok || bad "host-block: $n rows for one agent"
# A host's agent that does not answer leaves the default agent's row
# alone, and the hint out, since it may hold the locked file.
echo "$SOCK2" > "$FIX/slow-sock"
echo 4 > "$FIX/agent-sleep"
KEYS_LIMIT=1
report host-slow
KEYS_LIMIT=5
has_line host-slow 'agent    1Password, 0 keys, 0 hardware'
has_line host-slow "agent    Bitwarden, no answer within 1 seconds, a host's own"
no_line host-slow 'neither agent-held'
rm -f "$FIX/slow-sock" "$FIX/agent-sleep"
# A locked file counts as held only by the agent its own login uses:
# the default agent holding it does not help a host whose block names
# another, nor does a block that says IdentityAgent none.
read -r _ FP _ <<EOF
$(ssh-keygen -l -f "$K/locked.pub")
EOF
printf '%s\n' 'Host web1.example.com' '  IdentityFile ~/.ssh/locked' \
  "  IdentityAgent $SOCK2" > "$HOME/.ssh/config"
run "identityagent $SOCK"
echo "256 $FP alice@example.com (ED25519)" > "$FIX/agent"
echo "$SOCK2" > "$FIX/other-sock"
: > "$FIX/other-agent"
report host-agent
has_line host-agent '~/.ssh/locked: a key neither agent-held'
no_line host-agent 'passphrase set, in an agent'
# Held by the host's own agent: no hint.
: > "$FIX/agent"
echo "256 $FP alice@example.com (ED25519)" > "$FIX/other-agent"
report host-agent-held
has_line host-agent-held 'file     ~/.ssh/locked, passphrase set, in an agent'
no_line host-agent-held 'neither agent-held'
rm -f "$FIX/other-sock"
# An agent the doctor does not ask — a path with a variable or a
# token — leaves the locked file unmatched: no hint, no "held".
for a in '$HOME/agent.sock' '%d/agent.sock'; do
  printf '%s\n' 'Host web1.example.com' '  IdentityFile ~/.ssh/locked' \
    "  IdentityAgent $a" > "$HOME/.ssh/config"
  : > "$FIX/agent"
  report agent-unasked
  has_line agent-unasked 'passphrase set, agent not asked'
  no_line agent-unasked 'neither agent-held'
done
# IdentityAgent none: no agent, so no agent holds it.
printf '%s\n' 'Host web1.example.com' '  IdentityFile ~/.ssh/locked' \
  '  IdentityAgent none' > "$HOME/.ssh/config"
echo "256 $FP alice@example.com (ED25519)" > "$FIX/agent"
report agent-none-block
has_line agent-none-block '~/.ssh/locked: a key neither agent-held'
# A negated pattern takes a known host out of a block: none of the
# known hosts is left, so the block's key is not judged.
printf '%s\n' 'Host *.example.com !web1.example.com !db1.example.com' \
  '  IdentityFile ~/.ssh/forge' 'Match host *,!web1.example.com,!db1.*' \
  '  IdentityFile ~/.ssh/forge' > "$HOME/.ssh/config"
cp "$K/bare" "$K/forge"
run
report negated
no_line negated forge
rm -f "$HOME/.ssh/config" "$K/forge" "$K/alias" "$K/everyone"
rm -rf "$ROOT/memory/machines"
[ -z "$AGENT2_PID" ] || kill "$AGENT2_PID"
rm -rf "$SD2"
# An agent that answers with none.
run "identityagent $SOCK" 'identityfile ~/.ssh/locked'
: > "$FIX/agent"
report agent-empty
has_line agent-empty 'agent    1Password, 0 keys'
has_line agent-empty 'neither agent-held'
# IdentityAgent none.
run 'identityagent none' 'identityfile ~/.ssh/locked'
report agent-none
has_line agent-none 'agent    none answers'
# An agent that does not answer in time, waiting to be unlocked: said
# so, and no hint that no agent holds the key.
run "identityagent $SOCK" 'identityfile ~/.ssh/locked'
: > "$FIX/agent"
echo 4 > "$FIX/agent-sleep"
KEYS_LIMIT=1
report agent-slow
KEYS_LIMIT=5
has_line agent-slow 'agent    1Password, no answer within 1 seconds'
no_line agent-slow 'neither agent-held'
# The agent's socket reaches ssh-add alone, in every shell: an
# assignment in front of a function outlasts it in bash's POSIX mode.
run "identityagent $SOCK" 'identityfile ~/.ssh/locked'
: > "$FIX/agent"
SSH_AUTH_SOCK=/nonexistent/outer.sock
ssh_keys '' x
[ "$SSH_AUTH_SOCK" = /nonexistent/outer.sock ] && ok \
  || bad "agent: SSH_AUTH_SOCK left at $SSH_AUTH_SOCK"
unset SSH_AUTH_SOCK
[ -z "$AGENT_PID" ] || kill "$AGENT_PID"
rm -rf "$SD"

# A file ssh-keygen cannot read as a key: neither locked nor bare.
echo 'not a key' > "$K/junk"
run 'identityfile ~/.ssh/junk'
report unread
has_line unread 'unread   ~/.ssh/junk, not a key ssh-keygen reads'
no_line unread 'passphrase set'
no_line unread WARN

# The operations host's fleet key: no finding, by its default name
# and by the Fleet key line of memory/user.md.
cp "$K/bare" "$K/id_fleet_read"
run 'identityfile ~/.ssh/id_fleet_read'
report fleet
has_line fleet 'fleet    ~/.ssh/id_fleet_read, no passphrase, the fleet key'
no_line fleet WARN
echo 'Fleet key: ~/.ssh/bare' > "$ROOT/memory/user.md"
run 'identityfile ~/.ssh/bare' 'identityfile ~/.ssh/id_fleet_read'
report fleet-line
has_line fleet-line 'fleet    ~/.ssh/bare, no passphrase, the fleet key'
has_line fleet-line 'WARN     ~/.ssh/id_fleet_read, no passphrase'
rm -f "$ROOT/memory/user.md"

for s in "$TMP/x/ssh-a1/agent.123" \
  "$TMP/Library/Containers/com.bitwarden.desktop/ssh-agent.sock" \
  "$TMP/.gnupg/S.gpg-agent.ssh" "$TMP/other.sock"; do
  case $(keys_agent_name "$s") in
    ssh-agent|Bitwarden|gpg-agent|"an agent") ok ;;
    *) bad "agent name for $s: $(keys_agent_name "$s")" ;;
  esac
done

# ssh -G past the limit: killed, the check skipped with one line
# naming the limit, well before ssh would have answered.
run 'identityfile ~/.ssh/bare'
echo 4 > "$FIX/sleep"
KEYS_LIMIT=1
t0=$(date +%s)
report timeout
t1=$(date +%s)
has_line timeout 'took longer than 1 seconds'
no_line timeout WARN
[ $((t1 - t0)) -lt 4 ] && ok || bad "timeout: took $((t1 - t0)) seconds"
KEYS_LIMIT=5

# ssh -G failing: skipped, said so.
run 'identityfile ~/.ssh/bare'
: > "$FIX/fail"
report failed
has_line failed 'ssh -G failed'
no_line failed WARN

finish doctor
