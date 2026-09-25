#!/bin/sh
# impact.sh — PreToolUse hook (matcher: Bash), operations checkouts
# only: the mechanical half of rules/coordination.md → The hooks.
# Separate from guard-taboos.sh, which stays unchanged
# (.claude/rules/repo-release.md → Guard findings).
#
# Two checks, in this order:
#
#   Origin. Each ;/&/|-delimited segment of the command is judged on
#     its own (hostwarden_coord_kind, coord-lib.sh): a segment can
#     name more than one disruptive kind — a compound command that
#     restarts two units names both — and each one whose text names
#     a reboot, a firewall reload or restart, a network change, or
#     a restart of a systemd/service/launchctl unit, and whose
#     destination (hostwarden_coord_dest, the same reader an
#     agent's own presence gets parsed with, so the same limits
#     apply: a via-host guest, a script or a destination in a
#     variable is not read, and the command runs unchecked) names a
#     host, is checked against that host's radius
#     (bin/hostwarden-impact radius, a subprocess: the index it
#     reads is the one announce already warmed, so this stays fast
#     — rules/coordination.md → Blast radius). So `ssh h1 uptime;
#     ssh h2 reboot` checks only h2 as a reboot target, not h1.
#     Where the radius holds a live session other than this one (the
#     local presence map, read the same way `announce` reads it) and
#     this session has no impact entry of its own for that host
#     whose window has not yet ended, the segment's command is
#     denied, naming the radius, the affected sessions and the
#     announce command to run first. With nothing live on the
#     radius, or a still-open impact of this session's own, it
#     passes silently.
#   Receiver. Any command reaching a host inside another session's
#     active, not yet stale, impact — not this session's own — is
#     refused once, with the impact's origin, kind and end time and
#     this host's place in the radius. A marker under the impact
#     entry remembers the refusal, so the retry after it goes
#     through: the receiver is informed, never paused.
#
# Fast path: without jq, or without a disruptive pattern anywhere in
# the command and no active impact at all, this exits within
# milliseconds — a plain case match on the raw JSON, before anything
# is parsed. That match is only a "maybe": the firewall and network
# patterns require a write or reload verb, never a bare tool name,
# so a read-only audit command (`ufw status verbose`, `firewall-cmd
# --list-all`, `nft list ruleset`, `pfctl -s…`) never reaches it in
# the first place, and the `reboot` match names a mention, not yet
# an invocation — `last reboot` (rules/busybox.md) matches it too —
# so once the command is clean text (after jq), each segment is
# judged again, precisely, by hostwarden_coord_kind.
#
# What it deliberately does not do: read a local-mode command (one
# with no ssh, scp or rsync in it) as aimed at any host, infer a
# restart's unit where the command does not name one plainly, or
# recognise `brew services` or `networksetup` as a macOS restart —
# only `launchctl kickstart|stop|start`. All are the same tolerance
# rules/coordination.md → Presence map accepts for presence.sh's own
# parsing: a command this parser cannot place runs unchecked, and
# the prose in AGENTS.md is the backstop the mechanical check cannot
# be.

# Resolved the same way bin/hostwarden-impact resolves REPO_DIR
# (cd && pwd, no -P): hostwarden_cache_dir hashes this string, so a
# path spelled differently here would read a different cache
# directory than announce, wait, ack, done and status write to.
ROOT=$(cd "${0%/*}/../.." 2>/dev/null && pwd) || exit 0
for f in mode.sh json.sh coord-lib.sh; do
  [ -f "$ROOT/.claude/hooks/$f" ] || exit 0
done
# shellcheck source=mode.sh
. "$ROOT/.claude/hooks/mode.sh"
# shellcheck source=json.sh
. "$ROOT/.claude/hooks/json.sh"
# shellcheck source=coord-lib.sh
. "$ROOT/.claude/hooks/coord-lib.sh"

hostwarden_mode "$ROOT"
[ "$HOSTWARDEN_MODE" = operations ] || exit 0

INPUT=$(cat)
case "$INPUT" in
*'"tool_name":"Bash"'* | *'"tool_name": "Bash"'*) ;;
*) exit 0 ;;
esac

hostwarden_cache_dir "$ROOT"
IMPD="$HOSTWARDEN_CACHE/impact"
IDX="$HOSTWARDEN_CACHE/radius.idx"

# Any impact/ entry at all, stale or not — a cheap existence test,
# never a full read; the loops below judge staleness themselves.
ACTIVE=
for _d in "$IMPD"/*; do [ -d "$_d" ] && { ACTIVE=1; break; }; done

# The cheap "maybe" prefilter of rules/coordination.md → The hooks
# → Origin, matched on the raw command text: inside an ssh remote
# command string too, on the same tolerance guard-mode.sh accepts
# for its own prefilter. It only decides whether to fork jq at all;
# the precise, per-segment answer comes from hostwarden_coord_kind
# once the command is clean text.
MAYBE=
case "$INPUT" in
*'reboot'* | *'shutdown '*'-r'* | *'kexec'* \
  | *'nft -f '* | *'nft flush ruleset'* | *'nft delete table'* \
  | *'firewall-cmd'*'-reload'* \
  | *'ufw enable'* | *'ufw disable'* | *'ufw reload'* \
  | *'pve-firewall'*'restart'* | *'pve-firewall compile'* \
  | *'netfilter-persistent'* \
  | *'iptables-restore'* | *'ip6tables-restore'* \
  | *'pfctl -f '* | *'pfctl -e'* | *'pfctl -d'* \
  | *'ifreload'* | *'netplan apply'* | *'ifdown '* | *'ifup '* \
  | *'ip link set'*'down'* | *'/etc/init.d/networking'*'restart'* \
  | *'service networking'*'restart'* \
  | *'systemctl restart'* | *'systemctl reload-or-restart'* \
  | *'service '*'restart'* | *'rc-service'*'restart'* \
  | *'launchctl kickstart'* | *'launchctl stop'* \
  | *'launchctl start'*) MAYBE=1 ;;
esac

[ -n "$MAYBE" ] || [ -n "$ACTIVE" ] || exit 0

# Every field this hook needs in one jq call; without jq it cannot
# read the command reliably enough to judge either check, so it
# lets the call through rather than guess.
command -v jq >/dev/null 2>&1 || exit 0
eval "$(printf '%s' "$INPUT" | jq -r '@sh "CMD=\(.tool_input.command // "")
  SID=\(.session_id // "")"' 2>/dev/null)"
[ -n "$CMD" ] && [ -n "$SID" ] || exit 0

SELF=$(hostwarden_coord_sanitize "$SID")
NOW=$(date +%s)
TAB=$(printf '\t')

deny() { hook_deny "hostwarden coordination guard: $1"; }

DESTS=$(hostwarden_coord_dest "$CMD")

# --- receiver: any command reaching a host of another session's
# active impact is refused once ------------------------------------
if [ -n "$ACTIVE" ] && [ -n "$DESTS" ]; then
  while IFS="$TAB" read -r d _; do
    [ -n "$d" ] || continue
    h=$(hostwarden_coord_canon "$IDX" "$d" "$ROOT")
    for e in "$IMPD"/*; do
      [ -d "$e" ] || continue
      b=${e##*/}
      esess=$(printf '%s' "$b" | cut -d+ -f5)
      [ "$esess" = "$SELF" ] && continue
      until=$(printf '%s' "$b" | cut -d+ -f4)
      case $until in *[!0-9]* | '') continue ;; esac
      # Stale 30 minutes past its window, the same as a register
      # entry (rules/parallel-sessions.md → The register).
      [ $((NOW - until)) -le 1800 ] || continue
      set -- "$e/radius/$h"+*
      [ -e "$1" ] || continue
      [ -e "$e/refused-$SELF" ] && continue
      origin=$(printf '%s' "$b" | cut -d+ -f2)
      kind=$(printf '%s' "$b" | cut -d+ -f3)
      rb=${1##*/}
      rel=$(printf '%s' "$rb" | cut -d+ -f2)
      thr=$(printf '%s' "$rb" | cut -d+ -f3)
      # shellcheck disable=SC2174 # $e exists already; only the marker is new
      mkdir -p -m 700 "$e" 2>/dev/null
      : > "$e/refused-$SELF" 2>/dev/null
      hhmm=$(hostwarden_coord_hhmm "$until")
      deny "$origin $kind by $esess until $hhmm; $h $rel $thr. \
This notice is informational, not a hold: the retry goes through \
(rules/coordination.md → The hooks)."
    done
  done <<EOF
$DESTS
EOF
fi

# --- origin: a disruptive segment aimed at a host whose radius
# holds another live session, with no still-open impact of this
# session's own for it -------------------------------------------
[ -n "$DESTS" ] || exit 0

while IFS="$TAB" read -r d seg; do
  [ -n "$d" ] || continue
  KINDS=$(hostwarden_coord_kind "$seg")
  [ -n "$KINDS" ] || continue
  TH=$(hostwarden_coord_canon "$IDX" "$d" "$ROOT")

  # One segment can name more than one disruptive kind — a compound
  # command that restarts two units each names its own
  # restart:<unit> (coord-lib.sh's own hostwarden_coord_kind), and
  # each is checked and, if it reaches another session, denied in
  # turn.
  while IFS= read -r KIND; do
    [ -n "$KIND" ] || continue
    RADIUS=$(hostwarden_coord_radius "$ROOT" "$TH" "$KIND" 2>/dev/null) \
      || continue
    HOSTLIST=$(printf '%s\n' "$RADIUS" | awk '{print $1}')
    [ -n "$HOSTLIST" ] || continue

    # A live session other than this one, on any host the radius
    # named (coord-lib.sh — the same parser bin/hostwarden-impact's
    # announce and wait read the presence map with).
    AFF=$(hostwarden_coord_affected "$HOSTWARDEN_CACHE" "$HOSTLIST" "$SELF")
    [ -n "$AFF" ] || continue
    OTHER=$(printf '%s\n' "$AFF" | awk '{ printf " %s on %s;", $1, $2 }')

    # This session's own impact for this host, whose announced
    # window has not ended yet, covers it — not a fixed ten minutes
    # since it was made, which a longer announced window would
    # outlive. An earlier announcement of a narrower kind
    # (`restart:nginx`) does not cover a bigger one later
    # (`reboot`): only an announcement of the same kind, or of a
    # kind that already takes the whole radius
    # (hostwarden_coord_kind_whole, a superset of any single
    # service's own dependents), counts.
    COVERED=
    for e in "$IMPD"/*; do
      [ -d "$e" ] || continue
      b=${e##*/}
      [ "$(printf '%s' "$b" | cut -d+ -f5)" = "$SELF" ] || continue
      set -- "$e/radius/$TH"+*
      [ -e "$1" ] || continue
      AKIND=$(printf '%s' "$b" | cut -d+ -f3)
      [ "$AKIND" = "$KIND" ] || hostwarden_coord_kind_whole "$AKIND" \
        || continue
      until=$(printf '%s' "$b" | cut -d+ -f4)
      case $until in *[!0-9]* | '') continue ;; esac
      [ "$until" -gt "$NOW" ] && { COVERED=1; break; }
    done
    [ -n "$COVERED" ] && continue

    deny "$TH $KIND reaches other live sessions:$OTHER Run \
\`bin/hostwarden-impact announce $TH $KIND\` first, and wait or ack \
as rules/coordination.md → Announce, wait, go says."
  done <<KEOF
$KINDS
KEOF
done <<EOF
$DESTS
EOF
