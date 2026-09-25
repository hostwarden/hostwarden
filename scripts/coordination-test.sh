#!/bin/sh
# coordination-test.sh — dev-only fixture matrix for
# bin/hostwarden-impact's announce/wait/ack/done/status and for
# .claude/hooks/presence.sh and impact.sh. CI runs it through
# scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# Everything runs in a throwaway operations checkout under a temp
# directory, a fixture memory of one hypervisor and one guest, and
# a stand-in for ssh that answers only -G.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-coordination-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
has() { grep -qxF -- "$2" "$1" && ok || { bad "$3"; echo "--- got"; cat "$1"; }; }
hasi() { grep -qF -- "$2" "$1" && ok || { bad "$3"; echo "--- got"; cat "$1"; }; }
lacks() { grep -qF -- "$2" "$1" && bad "$3" || ok; }

export HOME="$TMP/home"
mkdir -p "$HOME"

# --- the checkout -----------------------------------------------
R="$TMP/repo"
mkdir -p "$R/bin" "$R/.claude/hooks"
cp "$REPO/bin/hostwarden-impact" "$REPO/bin/hostwarden-ssh-config" "$R/bin/"
cp "$REPO/.claude/hooks/mode.sh" "$REPO/.claude/hooks/hops.sh" \
  "$REPO/.claude/hooks/coord-lib.sh" "$REPO/.claude/hooks/json.sh" \
  "$REPO/.claude/hooks/resolve.sh" \
  "$REPO/.claude/hooks/presence.sh" "$REPO/.claude/hooks/impact.sh" \
  "$REPO/.claude/hooks/check-session.sh" "$R/.claude/hooks/"
git -C "$R" init --quiet
M="$R/memory"
mkdir -p "$M/servers"
: >"$M/.hostwarden-workspace"
: >"$M/ssh_config"
cat >"$M/user.md" <<'EOF'
# SSH Users
Default: alice
EOF

server() {
  mkdir -p "$M/servers/$1"
  printf '# %s\n%s\n- Last connected: 2026-09-20\n' "$1" "$2" \
    >"$M/servers/$1/memory.md"
}
server pve1.example.com '- IP: 192.0.2.1
- Role: hypervisor'
cat >"$M/servers/pve1.example.com/guests.md" <<'EOF'
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

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# A time well past HOSTWARDEN_COORD_RUN_STALE_MIN (coord-lib.sh, 360
# minutes), used to backdate a presence run marker past it in more
# than one test below.
PAST=$(date -d '-400 minutes' +%Y%m%d%H%M 2>/dev/null \
  || date -v-400M +%Y%m%d%H%M 2>/dev/null)

# ================================================================
echo "== announce, wait, ack, done, status"

run announce pve1.example.com reboot >"$TMP/out"
ID=$(head -n1 "$TMP/out")
[ -n "$ID" ] && ok || bad "announce prints an id"
has "$TMP/out" "no live session on the radius; proceeding" \
  "announce: nothing affected" || sed -n '2,$p' "$TMP/out"
run 'done' "$ID"

# The cache directory this checkout used, found rather than
# recomputed: cksum's input is an implementation detail of
# hostwarden_cache_dir (mode.sh), not of this fixture.
CACHE=$(find "$HOME/.cache/hostwarden" -maxdepth 1 -type d -name 'ws-*' | head -n1)
[ -n "$CACHE" ] && ok || bad "announce: made a cache directory"
PRES="$CACHE/presence"
run status pve1.example.com >"$TMP/out"
exits=$?
[ "$exits" = 1 ] && ok || bad "status after done: no active impact"

# FreeBSD's network restart (rules/os/freebsd.md: service netif
# restart && service routing restart) takes the whole radius, the
# same as reboot, network and firewall.
run radius pve1.example.com restart:netif >"$TMP/out"
hasi "$TMP/out" "web1.example.com guest pve1.example.com" \
  "radius: restart:netif takes the whole radius"
run radius pve1.example.com restart:routing >"$TMP/out"
hasi "$TMP/out" "web1.example.com guest pve1.example.com" \
  "radius: restart:routing takes the whole radius"

# A DNS-alias symlink (rules/dns-aliases.md) resolves without the
# index or a connection, so a session that touches web1 by its
# alias before any radius has run is still seen under its canonical
# name.
ln -s web1.example.com "$M/servers/web1"
hook presence.sh PreToolUse sessalias Bash \
  'ssh -F memory/ssh_config root@web1 uptime' >/dev/null
[ -n "$(find "$PRES" -maxdepth 1 -name 'sessalias+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: a DNS-alias symlink resolves to its canonical host"
rm -rf "$PRES/sessalias+web1.example.com+"*
rm "$M/servers/web1"

# Another session's presence: a run entry on the guest.
mkdir -p "$PRES"
mkdir -p "$PRES/other1+web1.example.com+run"
: >"$PRES/other1+web1.example.com+run/1"
mkdir -p "$PRES/other1+web1.example.com+$(date +%s)"
run announce pve1.example.com reboot >"$TMP/out"
ID=$(head -n1 "$TMP/out")
hasi "$TMP/out" "other1 web1.example.com run" \
  "announce: an affected session, running"

if [ "$HAVE_JQ" = 1 ]; then
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  wex=$?
  [ "$wex" = 1 ] && ok || bad "wait: a live run entry is not safe"
  hasi "$TMP/out" "not all safe" "wait: reports not safe"

  rm -rf "$PRES/other1+web1.example.com+run"
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  [ $? = 0 ] && ok || bad "wait: safe once the run entry is gone"
  has "$TMP/out" "all safe" "wait: prints all safe"

  run status pve1.example.com >"$TMP/out"
  [ $? = 0 ] && ok || bad "status: an active impact covers pve1"
  hasi "$TMP/out" "pve1.example.com reboot by" "status: names the impact"
  hasi "$TMP/out" "pve1.example.com origin -" "status: the origin relation"

  run status web1.example.com >"$TMP/out"
  [ $? = 0 ] && ok || bad "status: covers a guest too"
  hasi "$TMP/out" "web1.example.com guest pve1.example.com" \
    "status: the guest relation"

  # A writer: unsafe until it acks safe.
  rm -rf "$PRES/other1+web1.example.com+"*
  mkdir -p "$PRES/other2+web1.example.com+writer"
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  [ $? = 1 ] && ok || bad "wait: an un-acked writer is not safe"
  hasi "$TMP/out" "no answer" "wait: an un-acked writer has no answer"

  run ack "$ID" busy still-mid-change >"$TMP/out"
  HOSTWARDEN_SESSION=other2 run ack "$ID" busy still-mid-change
  unset HOSTWARDEN_SESSION
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  [ $? = 1 ] && ok || bad "wait: a writer that acked busy is not safe"
  hasi "$TMP/out" "busy" "wait: reports busy"

  HOSTWARDEN_SESSION=other2 run ack "$ID" safe done-now
  unset HOSTWARDEN_SESSION
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  [ $? = 0 ] && ok || bad "wait: a writer that acked safe is safe"

  run 'done' "$ID"
  run status pve1.example.com
  [ $? = 1 ] && ok || bad "status: done ends the impact"
else
  echo "  (jq missing — wait/ack/status against a live impact skipped)"
fi

# A run entry orphaned by a crashed or denied Bash call (its Post
# never fires) is not read as live once its marker is older than
# presence.sh's own sweep window for a run entry, six hours: a
# reader never waits for the next sweep to see that.
mkdir -p "$PRES/otherstale+web1.example.com+run"
: >"$PRES/otherstale+web1.example.com+run/1"
touch -t "$PAST" "$PRES/otherstale+web1.example.com+run/1" 2>/dev/null
run announce pve1.example.com reboot >"$TMP/out"
lacks "$TMP/out" "otherstale web1.example.com run" \
  "announce: a run marker past presence.sh's sweep window is not live"
run 'done' "$(head -n1 "$TMP/out")" >/dev/null 2>&1
rm -rf "$PRES/otherstale+web1.example.com+run"

# --- status and maintenance windows ------------------------------
# rules/maintenance-windows.md → What other sessions do with it:
# status also reports a Downtime: window that covers the current
# time. No jq needed — window_status reads memory alone. The
# window spans the whole calendar day (00:00-23:59) rather than an
# hour around "now", so the test never flakes by crossing midnight
# — a Downtime: line's single date cannot express that, the same
# limit the plan format itself has.
drop_downtime() { sed -i.bak '/^- Downtime:/d' "$M/servers/pve1.example.com/memory.md"; }

TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)
WTZ=$(readlink /etc/localtime 2>/dev/null | sed 's#.*/zoneinfo/##')
: "${WTZ:=UTC}"
mkdir -p "$M/plans"

printf -- '- Downtime: %s 00:00-23:59 (plan now-window)\n' "$TODAY" \
  >>"$M/servers/pve1.example.com/memory.md"
printf -- '# now window\n- Window: %s 00:00-23:59 %s\n' "$TODAY" "$WTZ" \
  >"$M/plans/now-window.md"
run status pve1.example.com >"$TMP/out"
[ $? = 0 ] && ok || bad "status: a Downtime window covering now is active"
hasi "$TMP/out" "is inside its planned window" "status: names the window"
hasi "$TMP/out" "plan now-window" "status: names the plan"
drop_downtime
rm "$M/plans/now-window.md"

printf -- '- Downtime: %s 00:00-23:59 (plan gone-window)\n' "$TODAY" \
  >>"$M/servers/pve1.example.com/memory.md"
run status pve1.example.com >"$TMP/out"
[ $? = 1 ] && ok || bad "status: a window whose plan file is missing is left out"
drop_downtime

printf -- '- Downtime: %s 00:00-23:59 (plan past-window)\n' "$YESTERDAY" \
  >>"$M/servers/pve1.example.com/memory.md"
printf -- '# past window\n- Window: %s 00:00-23:59 %s\n' "$YESTERDAY" "$WTZ" \
  >"$M/plans/past-window.md"
run status pve1.example.com >"$TMP/out"
[ $? = 1 ] && ok || bad "status: a window that has already passed is not active"
drop_downtime
rm -f "$M/plans/past-window.md" "$M/servers/pve1.example.com/memory.md.bak"

# --- only in an operations checkout -----------------------------
rm "$M/.hostwarden-workspace"
run announce pve1.example.com reboot >/dev/null 2>&1
[ $? = 1 ] && ok || bad "announce: refuses outside an operations checkout"
: >"$M/.hostwarden-workspace"

echo "== presence.sh"

hook presence.sh PreToolUse sess1 Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ -d "$PRES" ] && [ -n "$(find "$PRES" -maxdepth 1 -name 'sess1+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: Pre makes a run entry for a foreground command"
[ -n "$(find "$PRES" -maxdepth 1 -name 'sess1+web1.example.com+[0-9]*' 2>/dev/null)" ] \
  && ok || bad "presence: Pre also touches the host"

hook presence.sh PostToolUse sess1 Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ -z "$(find "$PRES" -maxdepth 1 -name 'sess1+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: Post removes the run entry"

# -B bind_interface takes a value too; a parser missing it would
# read "eth0" as the destination instead of web1.example.com.
hook presence.sh PreToolUse sessb Bash \
  'ssh -B eth0 -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ -n "$(find "$PRES" -maxdepth 1 -name 'sessb+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: -B bind_interface is read as taking a value"
rm -rf "$PRES/sessb+web1.example.com+run" 2>/dev/null

hook presence.sh PreToolUse sess2 Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' true >/dev/null
[ -z "$(find "$PRES" -maxdepth 1 -name 'sess2+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: run_in_background never makes a run entry"

# Two concurrent foreground calls to the same host, same session —
# the same command text, even — each hold their own marker in the
# run entry: the first call's Post must not remove the second's
# while it is still in flight.
hook presence.sh PreToolUse sessc Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
hook presence.sh PreToolUse sessc Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
MARKS=$(find "$PRES/sessc+web1.example.com+run" -mindepth 1 -maxdepth 1 | wc -l)
[ "$MARKS" -eq 2 ] && ok \
  || bad "presence: two concurrent identical calls get two markers"
hook presence.sh PostToolUse sessc Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ -d "$PRES/sessc+web1.example.com+run" ] \
  && [ -n "$(find "$PRES/sessc+web1.example.com+run" -mindepth 1 -maxdepth 1 2>/dev/null)" ] \
  && ok || bad "presence: the second call's marker survives the first's Post"
hook presence.sh PostToolUse sessc Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ ! -e "$PRES/sessc+web1.example.com+run" ] \
  && ok || bad "presence: the run entry is gone once both calls end"

# Post removes the oldest marker, not an arbitrary one: a call that
# has held its marker open the longest is always the one trimmed
# first, so it can never strand only a stale marker behind while
# removing a fresher call's own — which would read as not live
# under hostwarden_coord_affected's age check (coord-lib.sh) while
# the fresher call is still genuinely running.
mkdir -p "$PRES/sessd+web1.example.com+run"
: >"$PRES/sessd+web1.example.com+run/old"
touch -t "$PAST" "$PRES/sessd+web1.example.com+run/old" 2>/dev/null
: >"$PRES/sessd+web1.example.com+run/new"
hook presence.sh PostToolUse sessd Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ ! -e "$PRES/sessd+web1.example.com+run/old" ] \
  && [ -e "$PRES/sessd+web1.example.com+run/new" ] \
  && ok || bad "presence: Post removes the oldest marker, keeping the newest"
rm -rf "$PRES/sessd+web1.example.com+run" 2>/dev/null

hook presence.sh PostToolUse sess3 Bash \
  'D=/tmp/hostwarden; ssh -F memory/ssh_config root@web1.example.com "mkdir -p \$D"' \
  >/dev/null
[ -n "$(find "$PRES" -maxdepth 1 -name 'sess3+web1.example.com+writer' 2>/dev/null)" ] \
  && ok || bad "presence: a register-shaped command sets a writer entry"

hook presence.sh PostToolUse sess3 Bash \
  'ssh -F memory/ssh_config root@web1.example.com "rmdir /tmp/hostwarden/x"' \
  >/dev/null
[ -z "$(find "$PRES" -maxdepth 1 -name 'sess3+web1.example.com+writer' 2>/dev/null)" ] \
  && ok || bad "presence: a deregister-shaped command clears it"

rm -rf "$PRES"

if [ "$HAVE_JQ" = 1 ]; then
  echo "== impact.sh: origin"

  mkdir -p "$PRES/other3+web1.example.com+run"; : >"$PRES/other3+web1.example.com+run/1"

  # A mention of "reboot" is not an invocation of it.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "last reboot"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: last reboot is never denied"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com reboot' >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: an origin session gets denied with a live guest"
  hasi "$TMP/hookout" 'pve1.example.com reboot' "impact.sh: names the step"

  # A sudo or doas prefix is stripped before reading the command
  # word: AGENTS.md -> Remote mode makes sudo the default way a
  # non-root login runs anything, so these are the common case.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "sudo reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: sudo reboot over ssh is still confirmed"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "sudo systemctl reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: sudo systemctl reboot over ssh is still confirmed"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "doas reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: doas reboot over ssh is still confirmed"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "doas shutdown -r now"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: doas shutdown -r over ssh is still confirmed"

  # -h host (LDAP sudoers) and -D directory (sudo 1.9+) also take a
  # value: man sudo.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "sudo -h ldaphost reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: sudo -h ldaphost reboot over ssh is still confirmed"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "sudo -D /root reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: sudo -D /root reboot over ssh is still confirmed"

  HOSTWARDEN_SESSION=mine run announce pve1.example.com reboot >"$TMP/out"
  unset HOSTWARDEN_SESSION
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com reboot' >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: passes once this session announced it"
  rm -rf "$PRES/other3+web1.example.com+run"
  HOSTWARDEN_SESSION=mine run 'done' "$(head -n1 "$TMP/out")"
  unset HOSTWARDEN_SESSION

  # A read-only audit command never denies, even with a live
  # session on the radius: the firewall/network patterns match a
  # write or reload verb, never the bare tool name.
  mkdir -p "$PRES/other3+web1.example.com+run"; : >"$PRES/other3+web1.example.com+run/1"
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "ufw status verbose"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a read-only firewall audit is never denied"
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "firewall-cmd --list-all"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: firewall-cmd --list-all is never denied"
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "nft list ruleset"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: nft list ruleset is never denied"

  # -P takes a value too (the same table hops.sh reads); a parser
  # missing it would read "tag" as the destination instead of pve1.
  hook impact.sh PreToolUse mine Bash \
    'ssh -P tag -F memory/ssh_config root@pve1.example.com reboot' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: -P tag is read as taking a value"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: -P tag still names pve1.example.com, not tag"

  # A second ssh call in the same command is checked too, not only
  # the first.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@lone.example.com uptime; ssh -F memory/ssh_config root@pve1.example.com reboot' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a second ssh call in the command is checked"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: the second call's own destination is named"

  # A harmless call's own destination is never charged with another
  # call's disruption kind: web1 has a live session (other3) and
  # would be wrongly denied as a reboot target under a single,
  # command-wide kind — its own segment is only "uptime".
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@web1.example.com uptime; ssh -F memory/ssh_config root@pve1.example.com reboot' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: still denies for the segment that is actually a reboot"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: names pve1, not web1, as the reboot target"
  lacks "$TMP/hookout" 'web1.example.com reboot' \
    "impact.sh: web1's own harmless segment is never named as a reboot"

  # A ; or && the remote command's own quotes hold is not a local
  # separator: splitting there would leave the actual disruptive
  # verb in a piece with no destination of its own, so it would
  # never be checked against any host's radius.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "true && reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a && inside the remote command's own quotes is not a separator"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: names pve1.example.com for the quoted && case"

  hook impact.sh PreToolUse mine Bash \
    "ssh -F memory/ssh_config root@pve1.example.com 'uptime; reboot'" \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a ; inside the remote command's own quotes is not a separator"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: names pve1.example.com for the quoted ; case"

  # A backslash-escaped quote of the kind already open must not
  # flip the scanner's open-quote state: that would read the rest
  # of the command, a second ssh call's own destination included,
  # as still quoted and drop it from the destinations found at all.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@lone.example.com "safe \" text" ; ssh -F memory/ssh_config root@pve1.example.com reboot' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a second call survives an escaped quote earlier in the command"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: names pve1.example.com after the escaped-quote segment"

  # A run entry orphaned by a crashed or denied Bash call (its Post
  # never fires) is not read as live once its marker is older than
  # presence.sh's own sweep window for a run entry, six hours: a
  # reader never waits for the next sweep to see that. other3's
  # marker still exists on disk; it just no longer holds off pve1's
  # reboot.
  touch -t "$PAST" "$PRES/other3+web1.example.com+run/1" 2>/dev/null
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com reboot' >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a run marker past the sweep window no longer denies"

  # An announced kind only covers a later step of the same, or an
  # equally broad, kind (rules/coordination.md -> Blast radius):
  # restart:<unit> has a narrower radius than reboot, network or
  # firewall, so an earlier restart:nginx must not silently cover a
  # later reboot on the same host.
  mkdir -p "$PRES/other6+pve1.example.com+run"
  : >"$PRES/other6+pve1.example.com+run/1"
  HOSTWARDEN_SESSION=mine run announce pve1.example.com restart:nginx \
    >"$TMP/out"
  unset HOSTWARDEN_SESSION
  RID=$(head -n1 "$TMP/out")
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com reboot' >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a restart:nginx announcement does not cover a later reboot"
  HOSTWARDEN_SESSION=mine run 'done' "$RID"
  unset HOSTWARDEN_SESSION

  # An announcement of a kind that already takes the whole radius
  # (network, firewall, reboot, or a restart of a unit on the SSH,
  # firewall or network path) covers any other such kind: each
  # one's radius is the same "the host is entirely out" superset.
  HOSTWARDEN_SESSION=mine run announce pve1.example.com network \
    >"$TMP/out"
  unset HOSTWARDEN_SESSION
  RID=$(head -n1 "$TMP/out")
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "nft -f /etc/nftables.conf"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a network announcement covers a later firewall change too"
  HOSTWARDEN_SESSION=mine run 'done' "$RID"
  unset HOSTWARDEN_SESSION
  rm -rf "$PRES/other6+pve1.example.com+run"

  rm -rf "$PRES/other3+web1.example.com+run"

  echo "== impact.sh: receiver"

  HOSTWARDEN_SESSION=origin1 run announce pve1.example.com reboot >"$TMP/out"
  unset HOSTWARDEN_SESSION
  RID=$(head -n1 "$TMP/out")
  hook impact.sh PreToolUse other4 Bash \
    'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a receiver is refused once"
  hasi "$TMP/hookout" 'pve1.example.com reboot by origin1' \
    "impact.sh: the notice names the origin"
  hook impact.sh PreToolUse other4 Bash \
    'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: the retry goes through"
  HOSTWARDEN_SESSION=origin1 run 'done' "$RID"
  unset HOSTWARDEN_SESSION

  # An impact more than 30 minutes past its own window never denies
  # a receiver: it is as stale as a register entry that old.
  STALEDIR="$CACHE/impact/staleid+pve1.example.com+reboot+$(($(date +%s) - 3000))+origin2"
  mkdir -p "$STALEDIR/radius"
  : > "$STALEDIR/radius/web1.example.com+guest+pve1.example.com"
  hook impact.sh PreToolUse other5 Bash \
    'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a stale impact never refuses a receiver"
  rm -rf "$STALEDIR"
else
  echo "  (jq missing — impact.sh skipped)"
fi

# ================================================================
echo "== teams: impact entries on the radius hosts"

# Both hosts have their key in memory/known_hosts, so both may be
# reached (rules/coordination.md → Teams).
ssh-keygen -q -t ed25519 -N '' -f "$TMP/hostkey" >/dev/null 2>&1
KEY=$(cut -d' ' -f1,2 "$TMP/hostkey.pub")
printf 'pve1.example.com %s\nweb1.example.com %s\n' "$KEY" "$KEY" \
  >"$M/known_hosts"
rm -rf "$PRES"
: >"$TMP/sshcalls"

# Solo: one active person, one inactive — nothing goes to a host.
printf -- '- alice\n- bob (inactive since 2026-09-01)\n- ops1 (operations host)\n' \
  >"$M/operators.md"
run announce pve1.example.com reboot >"$TMP/out"
TID=$(head -n1 "$TMP/out")
lacks "$TMP/out" "team:" "announce: an inactive handle makes no team"
[ -s "$TMP/sshcalls" ] && bad "announce: solo wrote to a host" || ok
run 'done' "$TID"

# A team: two active people.
printf -- '- alice\n- bob\n' >"$M/operators.md"
printf 'Operator: alice\n' >>"$M/user.md"
run announce pve1.example.com reboot >"$TMP/out"
TID=$(head -n1 "$TMP/out")
hasi "$TMP/out" "team: register entry and journal line on 2 of 2 hosts" \
  "announce: a team tells both radius hosts"
hasi "$TMP/sshcalls" "== alice@pve1.example.com" "announce: calls the origin"
hasi "$TMP/sshcalls" "== alice@web1.example.com" "announce: calls the guest"
hasi "$TMP/sshcalls" "N=\"$TID+" "announce: the register entry carries the id"
hasi "$TMP/sshcalls" "+impact-reboot-pve1.example.com\"" \
  "announce: the register entry names the step"
hasi "$TMP/sshcalls" "[alice as \$(id -un)] impact $TID: reboot of pve1.example.com until" \
  "announce: the journal line's form"
TDIR=$(find "$CACHE/impact" -maxdepth 1 -name "$TID+*" | head -n1)
[ -e "$TDIR/remote/web1.example.com" ] && ok \
  || bad "announce: records the hosts that got an entry"
: >"$TMP/sshcalls"
run 'done' "$TID"
hasi "$TMP/sshcalls" "rmdir /tmp/hostwarden/$TID+*" \
  "done: removes the register entries it made"

# A host blacklisted after the announce gets no cleanup call.
run announce pve1.example.com reboot >"$TMP/out"
TID=$(head -n1 "$TMP/out")
printf -- '- web1.example.com\n' >"$M/blacklist.md"
: >"$TMP/sshcalls"
run 'done' "$TID" >"$TMP/out"
hasi "$TMP/out" "entry left: web1.example.com (blacklisted now" \
  "done: a host blacklisted since is left alone"
lacks "$TMP/sshcalls" "== alice@web1.example.com" \
  "done: no cleanup call to a blacklisted host"
rm -f "$M/blacklist.md"

# A read-only guest gets the journal line alone, an unreachable
# origin is named, and neither holds the step.
printf -- '- web1.example.com\n' >"$M/readonly.md"
echo UNREACHABLE >"$G/call-pve1.example.com"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
rc=$?
TID=$(head -n1 "$TMP/out")
[ "$rc" = 0 ] && ok || bad "announce: a host not reached does not fail it"
hasi "$TMP/out" "journal only: web1.example.com (read-only)" \
  "announce: a read-only host gets the journal line only"
hasi "$TMP/out" "no entry: pve1.example.com (not reached)" \
  "announce: a host not reached is named"
lacks "$TMP/sshcalls" 'mkdir "$N"' \
  "announce: no register entry on a read-only host"
run 'done' "$TID"
rm -f "$M/readonly.md" "$G/call-pve1.example.com"

# The journal line goes where the host's OS file writes one: QNAP's
# log_tool, none where memory records that logger does not land.
printf -- '- Appliance: QTS 5.2.1\n' >>"$M/servers/web1.example.com/memory.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/sshcalls" "/sbin/log_tool -t0" "announce: QNAP's journal line goes through log_tool"
run 'done' "$(head -n1 "$TMP/out")"
sed -i.bak '/^- Appliance: QTS/d' "$M/servers/web1.example.com/memory.md"
printf -- '- Journal: not written\n' >>"$M/servers/web1.example.com/memory.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "register only: web1.example.com (memory says its journal is not written)" \
  "announce: no journal line where memory says it does not land"
run 'done' "$(head -n1 "$TMP/out")"
printf -- '- web1.example.com\n' >"$M/readonly.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "no entry: web1.example.com (read-only, and memory says its journal is not written)" \
  "announce: a read-only host with nothing to write is named as such"
lacks "$TMP/sshcalls" "== alice@web1.example.com" \
  "announce: a host with nothing to write gets no call"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/readonly.md"
sed -i.bak '/^- Journal: not written/d' "$M/servers/web1.example.com/memory.md"
rm -f "$M/servers/web1.example.com/memory.md.bak"

# The read-only list's * makes every host read-only, and a host
# blacklisted by a DNS alias that resolves nowhere is not called.
printf -- '- *\n' >"$M/readonly.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "journal only: pve1.example.com (read-only)" \
  "announce: readonly.md's * covers every host"
lacks "$TMP/sshcalls" 'mkdir "$N"' "announce: no register entry under readonly.md's *"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/readonly.md"
ln -s web1.example.com "$M/servers/web1-old"
printf -- '- web1-old\n' >"$M/blacklist.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "no entry: web1.example.com (blacklisted" \
  "announce: a host blacklisted by its DNS alias is left out"
lacks "$TMP/sshcalls" "== alice@web1.example.com" \
  "announce: a host blacklisted by its DNS alias is not called"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/blacklist.md" "$M/servers/web1-old"
printf -- '- web1.example.com' >"$M/blacklist.md"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "no entry: web1.example.com (blacklisted" \
  "announce: a blacklist's last line without a newline still counts"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/blacklist.md"

# A host without a key in memory/known_hosts is never called.
printf 'pve1.example.com %s\n' "$KEY" >"$M/known_hosts"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "no entry: web1.example.com (no key in memory/known_hosts)" \
  "announce: a host without a known key is left out"
lacks "$TMP/sshcalls" "== alice@web1.example.com" \
  "announce: a host without a known key is not called"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/operators.md" "$M/known_hosts"

# ================================================================
echo "== the coordinator"

# A stand-in for the claude CLI: agents --json prints
# $TMP/agents.json, --bg records what it was asked to start.
echo '[]' >"$TMP/agents.json"
cat >"$TMP/bin/claude" <<EOF
#!/bin/sh
case "\$1" in
  agents) cat "$TMP/agents.json" ;;
  --bg) echo "\$*" >>"$TMP/claude-bg" ;;
esac
exit 0
EOF
chmod +x "$TMP/bin/claude"

# start <source> — runs check-session.sh as a SessionStart hook.
start() {
  printf '{"hook_event_name":"SessionStart","session_id":"s0","source":"%s"}' "$1" \
    | sh "$R/.claude/hooks/check-session.sh" >"$TMP/hookout" 2>&1
}
started() {
  i=0
  while [ "$i" -lt 5 ] && [ ! -s "$TMP/claude-bg" ]; do sleep 1; i=$((i + 1)); done
  [ -s "$TMP/claude-bg" ]
}
LOCK="$CACHE/coordinator-start"

rm -f "$TMP/claude-bg"
start startup
hasi "$TMP/hookout" "coordinator started" "check-session: starts one where none runs"
started && hasi "$TMP/claude-bg" "/hostwarden-coordinator" \
  "check-session: starts the skill in the background" \
  || bad "check-session: nothing was started"

rm -f "$TMP/claude-bg"
start startup
lacks "$TMP/hookout" "coordinator started" "check-session: a held start lock starts none"

# The watch marks the coordinator and prints the picture first; a
# second one exits. A long command's run entry is no event.
echo '[{"sessionId":"coord1","kind":"background"}]' >"$TMP/agents.json"
mkdir -p "$PRES/sessw+web1.example.com+$(date +%s)" "$PRES/sessw+web1.example.com+run"
: >"$PRES/sessw+web1.example.com+run/1"
HOSTWARDEN_WATCH_ONCE=1 HOSTWARDEN_SESSION=coord1 run watch >"$TMP/out"
[ $? = 0 ] && ok || bad "watch: the first coordinator marks itself"
has "$TMP/out" "+ presence sessw web1.example.com touched" "watch: prints a touched entry"
lacks "$TMP/out" " run" "watch: a run entry is no event"
[ -d "$LOCK" ] && bad "watch: its mark releases the start lock" || ok
rm -rf "$PRES/sessw+web1.example.com+"*

# An impact 30 minutes past its window leaves the watch's picture.
OLDIMP="$CACHE/impact/oldid+pve1.example.com+reboot+$(($(date +%s) - 3000))+origin9"
mkdir -p "$OLDIMP/radius"
HOSTWARDEN_WATCH_ONCE=1 HOSTWARDEN_SESSION=coord1 run watch >"$TMP/out"
lacks "$TMP/out" "oldid+" "watch: an expired impact is pruned, not reported"
[ -d "$OLDIMP" ] && bad "watch: prunes an expired impact" || ok
HOSTWARDEN_WATCH_ONCE=1 HOSTWARDEN_SESSION=coord2 run watch >"$TMP/out"
[ $? = 1 ] && ok || bad "watch: a second coordinator exits"
hasi "$TMP/out" "another coordinator runs: coord1" "watch: names the first"
run coordinator >"$TMP/out"
has "$TMP/out" "coord1" "coordinator: names the live one"
# Two marks at once: the smaller session id stays.
echo '[{"sessionId":"coord0"},{"sessionId":"coord1"}]' >"$TMP/agents.json"
mkdir "$CACHE/coordinator+coord0+$(date +%s)"
HOSTWARDEN_WATCH_ONCE=1 HOSTWARDEN_SESSION=coord1 run watch >"$TMP/out"
[ $? = 1 ] && ok || bad "watch: the larger of two session ids exits"
hasi "$TMP/out" "another coordinator runs: coord0" "watch: names the one that stays"
rm -rf "$CACHE"/coordinator+coord0+*
echo '[{"sessionId":"coord1","kind":"background"}]' >"$TMP/agents.json"

rm -f "$TMP/claude-bg"
start startup
lacks "$TMP/hookout" "coordinator started" "check-session: a live coordinator starts none"

# Its session gone, the entry is stale and a new one starts.
echo '[]' >"$TMP/agents.json"
run coordinator >/dev/null
[ $? = 1 ] && ok || bad "coordinator: a session not listed is not live"
rm -f "$TMP/claude-bg"
start resume
started && ok || bad "check-session: a stale coordinator is replaced"
rmdir "$LOCK" 2>/dev/null

# Coordinator: off, a compaction and a development checkout start none.
printf '# Preferences\nCoordinator: off\n' >>"$M/user.md"
rm -f "$TMP/claude-bg"
start startup
lacks "$TMP/hookout" "coordinator started" "check-session: Coordinator: off starts none"
sed -i.bak '/^Coordinator: off$/d' "$M/user.md" && rm -f "$M/user.md.bak"
start compact
lacks "$TMP/hookout" "coordinator started" "check-session: a compaction starts none"
rm "$M/.hostwarden-workspace"
start startup
lacks "$TMP/hookout" "coordinator started" "check-session: a development checkout starts none"
: >"$M/.hostwarden-workspace"
rm -f "$TMP/bin/claude"

echo "coordination: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
