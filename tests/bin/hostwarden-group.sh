#!/bin/sh
# tests/bin/hostwarden-group.sh — fixture matrix for
# bin/hostwarden-group. CI runs it through scripts/check.sh; an agent
# session leaves it to CI (.claude/rules/pull-requests.md → Checks).
#
# Runs under every awk this machine has of the four the script has
# to work with — BWK awk, gawk, mawk and busybox — each put first on
# PATH in turn, since the script calls awk by name.

cd "$(dirname "$0")/../.." || exit 2
ROOT=$(pwd -P)
GROUP="$ROOT/bin/hostwarden-group"
# shellcheck source=../helpers.sh
. "$ROOT/tests/helpers.sh"
test_tmp group

# host <name> — stdin is what a host printed in a round.
host() { cat > "$TMP/in/$1"; }
# ended <status> <name> — the exit line the round appends to its file.
ended() { printf '\nexit %s\n' "$1" >> "$TMP/in/$2"; }

# want <name> [<suffix>] — stdin is the output wanted for $TMP/in.
want() {
  cat > "$TMP/want"
  sh "$GROUP" "$TMP/in" ${2:+"$2"} > "$TMP/got" 2> "$TMP/err"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "$AWKNAME: $1 (exit $rc)"
    sed 's/^/    /' "$TMP/err"
  elif ! cmp -s "$TMP/want" "$TMP/got"; then
    bad "$AWKNAME: $1"
    diff "$TMP/want" "$TMP/got" | sed 's/^/    /'
  else
    ok
  fi
  rm -rf "$TMP/in"; mkdir "$TMP/in"
}

matrix() {
  rm -rf "$TMP/in"; mkdir "$TMP/in"

  printf '6.12.38\n' | host web1.example.com; ended 0 web1.example.com
  printf '6.12.38\n' | host web2.example.com; ended 0 web2.example.com
  printf '6.1.0\n' | host db1.example.com; ended 0 db1.example.com
  want "one answer, no marker, largest group first" <<'EOF'
web1.example.com, web2.example.com:
  6.12.38
db1.example.com:
  6.1.0
EOF

  printf '###sshd###\npermitrootlogin no\n###fw###\nufw active\n' |
    host web1.example.com.2
  ended 0 web1.example.com.2
  printf '###sshd###\npermitrootlogin no\n###fw###\nufw active\n' |
    host web2.example.com.2
  ended 0 web2.example.com.2
  printf '###sshd###\npermitrootlogin yes\n' | host db1.example.com.2
  ended 255 db1.example.com.2
  : | host db2.example.com.2; ended 0 db2.example.com.2
  printf '###sshd###\npart\n' | host db3.example.com.2
  : | host db4.example.com.2
  printf 'first round\n' | host web1.example.com.1
  want "sections, missing, no output, unfinished, a failed exit" .2 <<'EOF'
== sshd
web1.example.com, web2.example.com:
  permitrootlogin no
db1.example.com:
  permitrootlogin yes
db3.example.com:
  part
== fw
web1.example.com, web2.example.com:
  ufw active
db1.example.com, db3.example.com:
  (missing)
no output: db2.example.com
unfinished: db3.example.com, db4.example.com
exit 255: db1.example.com
EOF

  printf 'banner\n###a###\n\n###b###\nx\n' | host web1.example.com
  ended 0 web1.example.com
  printf 'banner\n###a###\n###b###\nx\n' | host web2.example.com
  ended 0 web2.example.com
  want "text before a marker, an empty section, a blank line" <<'EOF'
== (no marker)
web1.example.com, web2.example.com:
  banner
== a
web1.example.com:

web2.example.com:
  (empty)
== b
web1.example.com, web2.example.com:
  x
EOF

  printf 'no newline' | host web1.example.com; ended 3 web1.example.com
  printf 'no newline\n' | host web2.example.com; ended 0 web2.example.com
  printf 'ends blank\n\n' | host web3.example.com; ended 0 web3.example.com
  want "output without a last newline, output ending in a blank line" <<'EOF'
web1.example.com, web2.example.com:
  no newline
web3.example.com:
  ends blank

exit 3: web1.example.com
EOF

  printf 'Linux\n' | host web1.example.com.1; ended 0 web1.example.com.1
  printf 'Authorized use only\n' | host web1.example.com.1.err
  printf 'Linux\n' | host web2.example.com.1; ended 0 web2.example.com.1
  printf 'Authorized use only\n' | host web2.example.com.1.err
  printf 'Linux\n' | host db1.example.com.1; ended 0 db1.example.com.1
  : | host db1.example.com.1.err
  : | host db2.example.com.1; ended 255 db2.example.com.1
  printf 'ssh: connect to host db2 port 22: timed out\n' |
    host db2.example.com.1.err
  printf 'not this round\n' | host db1.example.com.1a.err
  want "stderr apart, only the hosts that wrote any" .1 <<'EOF'
== (no marker)
db1.example.com, web1.example.com, web2.example.com:
  Linux
== (stderr)
web1.example.com, web2.example.com:
  Authorized use only
db2.example.com:
  ssh: connect to host db2 port 22: timed out
no output: db2.example.com
exit 255: db2.example.com
EOF

  printf 'x\n' | host web1.example.com; ended 0 web1.example.com
  printf 'banner\n' | host web1.example.com.err
  want "no suffix: the stderr file is no host of its own" <<'EOF'
== (no marker)
web1.example.com:
  x
== (stderr)
web1.example.com:
  banner
EOF

  printf 'exit 0 is data\nnot last\n' | host web1.example.com
  ended 0 web1.example.com
  want "exit only as the last line" <<'EOF'
web1.example.com:
  exit 0 is data
  not last
EOF

  mkdir -p "$TMP/in"
  if sh "$GROUP" "$TMP/in" .9 > /dev/null 2>&1; then
    bad "$AWKNAME: no matching file exits 0"
  else
    ok
  fi
  if sh "$GROUP" > /dev/null 2>&1; then
    bad "$AWKNAME: no directory exits 0"
  else
    ok
  fi
}

mkdir "$TMP/bin"
PATH="$TMP/bin:$PATH"
export PATH
for AWKNAME in awk gawk mawk busybox; do
  rm -f "$TMP/bin/awk"
  p=$(command -v "$AWKNAME" 2> /dev/null) || continue
  if [ "$AWKNAME" = busybox ]; then
    printf '#!/bin/sh\nexec %s awk "$@"\n' "$p" > "$TMP/bin/awk"
    chmod +x "$TMP/bin/awk"
  else
    ln -sf "$p" "$TMP/bin/awk"
  fi
  matrix
done

finish "group matrix"
