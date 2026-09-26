#!/bin/sh
# presence.sh — PreToolUse and PostToolUse hook (matcher:
# Bash|Monitor), operations checkouts only: the mechanical presence
# map rules/coordination.md → Presence map describes, read by
# `bin/hostwarden-impact wait`, `status` and by impact.sh.
#
# What a session does, not what it says: every Bash or Monitor call
# whose command reaches a host over ssh, scp or rsync (parsed by
# coord-lib.sh's hostwarden_coord_dest, the same limits that file
# documents) renews a "touched" entry for that host under
# ~/.cache/hostwarden/ws-<checkout ID>/presence/. A foreground Bash
# command additionally holds a "run" entry from Pre to Post — never
# for `run_in_background: true` or for Monitor, which only touch.
# A command that matches the register or the deregister snippet of
# rules/parallel-sessions.md sets or clears a "writer" entry for the
# same host.
#
# Entries are directories, name-only as the register's are: nothing
# is ever written into one that a reader trusts as more than a
# name — only local file names this session and its own hooks made.
# A "touched" entry is presence/<session>+<host>+<epoch>, renewed by
# renaming the previous one; "writer" is
# presence/<session>+<host>+writer. "run" is
# presence/<session>+<host>+run/, a directory a reader judges live
# by whether it holds a file younger than
# HOSTWARDEN_COORD_RUN_STALE_MIN (coord-lib.sh): Pre adds one, named
# for this call alone ($$, this hook's own process id, unique among
# whatever else is concurrently in flight); Post removes the oldest
# file in it, not necessarily its own — this Post's own $$ is not
# the Pre that made its marker, a different process, so which one
# was its own is not knowable here either, and removing the oldest
# is the rule that never strands a fresh marker's absence behind a
# stale one while trimming an old one. Two concurrent calls,
# identical command text included, each hold their own file, and
# either Post ending first still leaves the directory non-empty for
# the other.
#
# Never denies: it only records. A failure to record is silent, so
# a broken hook never blocks a session's work — the worst outcome
# is that this session's presence goes unseen, which is the same as
# not having this hook at all.

# Resolved the same way bin/hostwarden-impact resolves REPO_DIR
# (cd && pwd, no -P): hostwarden_cache_dir hashes this string, so a
# path spelled differently here would read a different cache
# directory than announce, wait, ack, done and status write to.
ROOT=$(cd "${0%/*}/../.." 2>/dev/null && pwd) || exit 0
for f in mode.sh json.sh coord-tokenize.sh coord-lib.sh; do
  [ -f "$ROOT/lib/$f" ] || exit 0
done
# shellcheck source=../../lib/mode.sh
. "$ROOT/lib/mode.sh"
# shellcheck source=../../lib/json.sh
. "$ROOT/lib/json.sh"
# shellcheck source=../../lib/coord-tokenize.sh
. "$ROOT/lib/coord-tokenize.sh"
# shellcheck source=../../lib/coord-lib.sh
. "$ROOT/lib/coord-lib.sh"

hostwarden_mode "$ROOT"
[ "$HOSTWARDEN_MODE" = operations ] || exit 0

# shellcheck disable=SC2034 # read by hook_field in json.sh
INPUT=$(cat)
EVENT=$(hook_field hook_event_name '[A-Za-z]')
TOOL=$(hook_field tool_name)
case "$TOOL" in
Bash | Monitor) ;;
*) exit 0 ;;
esac
SID=$(hook_session_id)
[ -n "$SID" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | jq -r '@sh "CMD=\(.tool_input.command // "")
    BG=\(.tool_input.run_in_background // false)"' 2>/dev/null)"
else
  CMD=$(hook_field command '[^"\\]')
  case "$INPUT" in
  *'"run_in_background":true'* | *'"run_in_background": true'*) BG=true ;;
  *) BG=false ;;
  esac
fi
[ -n "$CMD" ] || exit 0

# The common case — a command with no ssh, scp or rsync in it —
# ends here, before the cache directory is even touched: most Bash
# and Monitor calls in a session never reach a host at all.
DESTS=$(hostwarden_coord_dest "$CMD")
[ -n "$DESTS" ] || exit 0
TAB=$(printf '\t')

hostwarden_cache_dir "$ROOT"
PRES="$HOSTWARDEN_CACHE/presence"
IDX="$HOSTWARDEN_CACHE/radius.idx"
# shellcheck disable=SC2174
mkdir -p -m 700 "$PRES" 2>/dev/null || exit 0

# A touched or writer entry nobody renewed in an hour is past every
# staleness window a reader checks (30 minutes); a sweep on the Pre
# call alone keeps a long session's directory from only ever
# growing. A run entry is swept on HOSTWARDEN_COORD_RUN_STALE_MIN
# instead (coord-lib.sh, the same window hostwarden_coord_affected's
# own read-time check uses): the sixty-minute one would delete it
# mid-command, and a run whose Post call never fires (Bash crashed,
# or Claude Code itself did) must still go stale eventually — its
# own markers with it, at whatever count.
if [ "$EVENT" = PreToolUse ]; then
  find "$PRES" -mindepth 1 -maxdepth 1 ! -name '*+run' -mmin +60 \
    -exec rm -rf {} + 2>/dev/null
  find "$PRES" -mindepth 1 -maxdepth 1 -name '*+run' \
    -mmin "+$HOSTWARDEN_COORD_RUN_STALE_MIN" \
    -exec rm -rf {} + 2>/dev/null
fi

while IFS="$TAB" read -r d _; do
  [ -n "$d" ] || continue
  h=$(hostwarden_coord_canon "$IDX" "$d" "$ROOT")
  hostwarden_coord_beat "$PRES" "$SID+$h"
  if [ "$TOOL" = Bash ] && [ "$BG" != true ]; then
    RUNDIR="$PRES/$SID+$h+run"
    case "$EVENT" in
    PreToolUse)
      # shellcheck disable=SC2174
      mkdir -p -m 700 "$RUNDIR" 2>/dev/null
      : > "$RUNDIR/$$" 2>/dev/null
      ;;
    PostToolUse)
      # Removes the oldest marker, not an arbitrary one: this
      # Post's own Pre ran under a different process id than this
      # one, so which marker was its own is not knowable here
      # either — but always pruning from the oldest end means a
      # call that has held its marker open the longest is always
      # the one a Post trims first. Any other rule (glob order, most
      # recent) risks leaving only an old marker behind while a
      # genuinely still-running call's own fresh one is removed
      # instead: hostwarden_coord_affected's read-time cap on a run
      # marker's age (coord-lib.sh) would then read the host as not
      # live while that call is still in flight.
      _oldest=
      for _m in "$RUNDIR"/*; do
        [ -e "$_m" ] || continue
        if [ -z "$_oldest" ] || [ "$_m" -ot "$_oldest" ]; then
          _oldest=$_m
        fi
      done
      [ -n "$_oldest" ] && rm -f "$_oldest" 2>/dev/null
      rmdir "$RUNDIR" 2>/dev/null
      ;;
    esac
  fi
  # rules/parallel-sessions.md → Register, and renew / Deregister:
  # the canonical snippets both name /tmp/hostwarden; a register
  # creates or renames an entry under it (mkdir, or mv where one
  # already exists) and a deregister removes one (rmdir). A false
  # match costs one wrong writer entry, corrected at the next
  # register or deregister on that host — the same tolerance
  # rules/coordination.md → Presence map accepts for the rest of
  # this parser. A renewal on an already-open writer entry still
  # refreshes its age with touch — mkdir alone would fail silently
  # on it and leave a long-writing session's entry to go stale.
  case "$CMD" in
  *'/tmp/hostwarden'*)
    case "$CMD" in
    *rmdir*)
      [ "$EVENT" = PostToolUse ] && rmdir "$PRES/$SID+$h+writer" 2>/dev/null
      ;;
    *mkdir* | *' mv '* | *';mv '*)
      if [ "$EVENT" = PostToolUse ]; then
        if [ -d "$PRES/$SID+$h+writer" ]; then
          touch "$PRES/$SID+$h+writer" 2>/dev/null
        else
          mkdir "$PRES/$SID+$h+writer" 2>/dev/null
        fi
      fi
      ;;
    esac
    ;;
  esac
done <<EOF
$DESTS
EOF

exit 0
