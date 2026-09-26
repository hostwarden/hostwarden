#!/bin/sh
# tests/hooks/coordination.sh — dev-only fixture matrix for
# bin/hostwarden-impact's announce/wait/ack/done/status and for
# .claude/hooks/presence.sh and impact.sh. CI runs it through
# scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# Everything runs in a throwaway operations checkout under a temp
# directory, a fixture memory of one hypervisor and one guest, and
# a stand-in for ssh that answers only -G.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp coordination

has() { grep -qxF -- "$2" "$1" && ok || { bad "$3"; echo "--- got"; cat "$1"; }; }
hasi() { grep -qF -- "$2" "$1" && ok || { bad "$3"; echo "--- got"; cat "$1"; }; }
lacks() { grep -qF -- "$2" "$1" && bad "$3" || ok; }

export HOME="$TMP/home"
mkdir -p "$HOME"

# --- the checkout -----------------------------------------------
R="$TMP/repo"
mkdir -p "$R/bin" "$R/lib" "$R/.claude/hooks"
cp "$REPO/bin/hostwarden-impact" "$REPO/bin/hostwarden-ssh-config" "$R/bin/"
cp -R "$REPO/lib/hostwarden-impact" "$R/lib/"
cp "$REPO/lib/mode.sh" "$REPO/lib/hops.sh" "$REPO/lib/coord-tokenize.sh" \
  "$REPO/lib/coord-lib.sh" "$REPO/lib/json.sh" "$REPO/lib/resolve.sh" \
  "$R/lib/"
cp "$REPO/.claude/hooks/presence.sh" "$REPO/.claude/hooks/impact.sh" \
  "$REPO/.claude/hooks/check-session.sh" "$R/.claude/hooks/"
git -C "$R" init --quiet
M="$R/memory"
mkdir -p "$M/machines"
: >"$M/.hostwarden-workspace"
: >"$M/ssh_config"
cat >"$M/user.md" <<'EOF'
# SSH Users
Default: alice
EOF

server() {
  mkdir -p "$M/machines/$1"
  printf '# %s\n%s\n- Last connected: 2026-09-20\n' "$1" "$2" \
    >"$M/machines/$1/memory.md"
}
server pve1.example.com '- IP: 192.0.2.1
- Role: hypervisor'
cat >"$M/machines/pve1.example.com/guests.md" <<'EOF'
# Guests on pve1.example.com

- Inventoried: 2026-01-02

- 101 web1 (VM): running, autostart. 192.0.2.21.
  → web1.example.com
EOF
server web1.example.com '- IP: 192.0.2.21
- Role: web server
- Runs on: pve1.example.com (VM 101)'

G="$TMP/sshg"
mkdir -p "$G" "$TMP/bin"
cat >"$TMP/bin/ssh" <<EOF
#!/bin/sh
# -G answers from \$G; any other call is one of announce's or done's
# calls to a radius host in a team: logged with its input, and
# answered the way the host's call-<dest> file says (UNREACHABLE,
# NOREG), else as a host that took both.
u='' p='' g='' d='' rest=''
while [ \$# -gt 0 ]; do
  case \$1 in
    -G) g=1 ;;
    -F|-o) shift ;;
    -l) u=\$2; shift ;;
    -p) p=\$2; shift ;;
    -*) ;;
    *) if [ -z "\$d" ]; then d=\$1; else rest="\$rest \$1"; fi ;;
  esac
  shift
done
if [ -z "\$g" ]; then
  c="$G/call-\$d"
  [ -f "\$c" ] && grep -qx UNREACHABLE "\$c" && exit 255
  in=\$(cat)
  printf '== %s@%s%s\n%s\n' "\$u" "\$d" "\$rest" "\$in" >>"$TMP/sshcalls"
  case \$in in *'mkdir "\$N"'*)
    [ -f "\$c" ] && grep -qx NOREG "\$c" || echo registered ;;
  esac
  case \$in in *logger*|*log_tool*) echo logged ;; esac
  exit 0
fi
f="$G/\$u@\$d"; [ -f "\$f" ] || f="$G/\$d"
[ -f "\$f" ] && grep -qx FAIL "\$f" && exit 255
echo "user \${u:-alice}"
echo "port \${p:-22}"
[ -f "\$f" ] && cat "\$f"
[ -f "\$f" ] && grep -q '^hostname ' "\$f" || echo "hostname \$d"
exit 0
EOF
chmod +x "$TMP/bin/ssh"
# A dig stand-in for the blacklist/read-only resolver-outage
# disambiguation (lib/resolve.sh's hostwarden_resolve_ok):
# one header line per query it is asked (the real dig's own shape,
# one per record type), NOERROR for every name but the ones a test
# below names, so the rest of this file's hosts still clear on a
# clean, deterministic miss regardless of whether this machine can
# reach the internet.
cat >"$TMP/bin/dig" <<'EOF'
#!/bin/sh
case " $* " in *' +short '*) exit 0 ;; esac
args=
for a; do
  case $a in
    +*) ;;
    *) args="$args $a" ;;
  esac
done
set -- $args
while [ $# -ge 2 ]; do
  n=$1
  case $n in
    unreachable-*.example.com)
      echo ';; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 0' ;;
    *) echo ';; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 0' ;;
  esac
  shift 2
done
EOF
chmod +x "$TMP/bin/dig"
# No routing domain here: this runner's own systemd-resolved never
# decides which path the check takes.
printf '#!/bin/sh\nexit 1\n' >"$TMP/bin/resolvectl"
chmod +x "$TMP/bin/resolvectl"
export PATH="$TMP/bin:$PATH"

run() { sh "$R/bin/hostwarden-impact" "$@"; }

# hook <event> <session> <tool> <command> [bg] — runs the given
# hook script against a JSON input built the way Claude Code's
# does, and leaves its stdout in $TMP/hookout.
hook() {
  hs=$1 he=$2 hsid=$3 htool=$4 hcmd=$5 hbg=${6:-false}
  hcmd_j=$(printf '%s' "$hcmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hook_event_name":"%s","session_id":"%s","tool_name":"%s","tool_input":{"command":"%s","run_in_background":%s},"cwd":"%s"}' \
    "$he" "$hsid" "$htool" "$hcmd_j" "$hbg" "$R" \
    | (cd "$R" && sh "$R/.claude/hooks/$hs") >"$TMP/hookout" 2>"$TMP/hookerr"
  echo "$?"
}

# shellcheck disable=SC2034 # read by the parts
HAVE_JQ=0
# shellcheck disable=SC2034 # read by the parts
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# A time well past HOSTWARDEN_COORD_RUN_STALE_MIN (coord-lib.sh, 360
# minutes), used to backdate a presence run marker past it in more
# than one test below.
# shellcheck disable=SC2034 # read by the parts
PAST=$(date -d '-400 minutes' +%Y%m%d%H%M 2>/dev/null \
  || date -v-400M +%Y%m%d%H%M 2>/dev/null)

# The rest lives in tests/hooks/coordination/, one file per stage,
# sourced in this order into this shell: each reads what the ones
# before it set.
PARTS='announce hooks hooks-jq teams coordinator'
for part in $PARTS; do
  [ -f "$REPO/tests/hooks/coordination/$part.sh" ] || {
    echo "${0##*/}: tests/hooks/coordination/$part.sh is missing" >&2
    exit 1
  }
done
for part in $PARTS; do
  # shellcheck source=/dev/null
  . "$REPO/tests/hooks/coordination/$part.sh"
done

finish coordination
