# lib/hostwarden-impact/watch.sh — windows, the coordinator and
# watch. Sourced by bin/hostwarden-impact, in the order its PARTS
# lists, into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# window_status <host> -- prints one line and returns 0 where a
# Downtime: window on <host> (rules/maintenance-windows.md) covers
# the current time, so losing SSH during it reads as a known cause
# (rules/maintenance-windows.md -> What other sessions do with it;
# rules/ssh-unreachable.md checks this before anything else). The
# Downtime: line itself names no zone, so the plan it points at
# (memory/plans/<slug>.md, its own Window: line) supplies one; a
# window whose plan is gone, or whose zone this reads cannot parse,
# is left out rather than guessed at -- the same tolerance
# rules/coordination.md -> The hooks already accepts elsewhere.
window_status() {
  ws_host=$1
  ws_now=$(date +%s)
  # A for loop, not a pipe into while: the last stage of a pipe runs
  # in a subshell, and a false `if` with no `else` exits 0 by itself
  # (POSIX), so a not-found result could not be told from a found
  # one through the subshell's own exit status. IFS holding only a
  # newline splits on lines alone; a line's own spaces stay intact.
  ws_dl=$(fields | awk -F "$TAB" -v h="$ws_host" \
    '$1 == h && $2 == "Downtime" { print $3 }')
  [ -n "$ws_dl" ] || return 1
  ws_ifs=$IFS
  IFS='
'
  for ws_line in $ws_dl; do
    IFS=$ws_ifs
    ws_date=$(printf '%s\n' "$ws_line" | awk '{ print $1 }')
    ws_start=$(printf '%s\n' "$ws_line" | grep -oE '^[^ ]+ [0-9]{2}:[0-9]{2}' \
      | awk '{ print $2 }')
    ws_end=$(printf '%s\n' "$ws_line" \
      | grep -oE '[0-9]{2}:[0-9]{2}( |\()' | tail -1 | awk '{ print $1 }')
    ws_slug=$(printf '%s\n' "$ws_line" | sed -n 's/.*(plan \([^)]*\)).*/\1/p')
    if [ -n "$ws_date" ] && [ -n "$ws_start" ] && [ -n "$ws_end" ] \
      && [ -n "$ws_slug" ]; then
      ws_plan="$M/plans/$ws_slug.md"
      if [ -f "$ws_plan" ]; then
        # The Window: line whose date and both times this Downtime:
        # entry's own name -- a rolling-cluster plan has one per
        # window, each free to name its own zone. index() is a
        # substring search, so this needs no regex for the dash
        # between the two times, whichever form it takes. The zone
        # is that line's last field, whatever it is: an IANA name
        # carries one slash (Europe/Berlin) or two
        # (America/Argentina/Buenos_Aires), and matching a fixed
        # slash count would silently truncate the second kind.
        ws_tz=$(awk -v d="$ws_date" -v s="$ws_start" -v e="$ws_end" '
          /^- Window:/ && index($0, d) && index($0, s) && index($0, e) {
            print $NF; exit
          }' "$ws_plan")
        # A zone date cannot resolve is not the same as no zone at
        # all: TZ set to garbage still lets `date` succeed, silently
        # falling back to a default rather than failing -- verified
        # live (`TZ=Not/AZone date -j -f … +%s` exits 0 on macOS).
        # The zoneinfo database is the one place that tells a real
        # zone from a typo.
        [ -n "$ws_tz" ] && [ -f "/usr/share/zoneinfo/$ws_tz" ] || continue
        if ws_from=$(TZ="$ws_tz" date -d "$ws_date $ws_start" +%s 2>/dev/null \
            || TZ="$ws_tz" date -j -f '%Y-%m-%d %H:%M' "$ws_date $ws_start" \
              +%s 2>/dev/null) \
          && ws_to=$(TZ="$ws_tz" date -d "$ws_date $ws_end" +%s 2>/dev/null \
            || TZ="$ws_tz" date -j -f '%Y-%m-%d %H:%M' "$ws_date $ws_end" \
              +%s 2>/dev/null) \
          && [ "$ws_now" -ge "$ws_from" ] && [ "$ws_now" -le "$ws_to" ]; then
          echo "$ws_host is inside its planned window" \
            "$ws_date $ws_start-$ws_end (plan $ws_slug)"
          return 0
        fi
      fi
    fi
    IFS='
'
  done
  IFS=$ws_ifs
  return 1
}

# coordinators — the session of each live coordinator entry: its
# session listed by `claude agents --json`, or, without the claude
# CLI, its beat under 30 minutes old. Removes the others; asks the
# CLI only where there is an entry to ask about.
coordinators() {
  set -- "$HOSTWARDEN_CACHE"/coordinator+*
  [ -e "$1" ] || return 0
  cs_ag=$(claude agents --json 2>/dev/null) || cs_ag=''
  cs_now=$(date +%s)
  for cs_e; do
    cs_s=${cs_e##*/coordinator+}; cs_b=${cs_s##*+}; cs_s=${cs_s%+*}
    case $cs_b in *[!0-9]* | '') rm -rf "$cs_e"; continue ;; esac
    if [ -n "$cs_ag" ]; then
      case $cs_ag in *"\"$cs_s\""*) ;; *) rm -rf "$cs_e"; continue ;; esac
    elif [ $((cs_now - cs_b)) -ge 1800 ]; then
      rm -rf "$cs_e"; continue
    fi
    echo "$cs_s"
  done
}

# coordinator_mark — marks this session as the coordinator, or
# renews its mark; returns 1, having said why, where another stays:
# one that was there first, or on a renewal one with the smaller
# session id, so two that marked themselves at once settle on one.
coordinator_mark() {
  SESSION=$(impact_session)
  MINE=''
  for ip_e in "$HOSTWARDEN_CACHE"/coordinator+"$SESSION"+*; do
    [ -e "$ip_e" ] && MINE=1
  done
  for ip_s in $(coordinators); do
    [ "$ip_s" = "$SESSION" ] && continue
    if [ -z "$MINE" ] || [ "$(printf '%s\n%s\n' "$ip_s" "$SESSION" | LC_ALL=C sort | head -n 1)" = "$ip_s" ]; then
      echo "another coordinator runs: $ip_s"
      return 1
    fi
  done
  hostwarden_coord_beat "$HOSTWARDEN_CACHE" "coordinator+$SESSION"
  rmdir "$HOSTWARDEN_CACHE/coordinator-start" 2>/dev/null
  return 0
}

do_coordinator() {
  [ $# -eq 0 ] || { usage >&2; exit 2; }
  impact_setup
  CS=$(coordinators)
  [ -n "$CS" ] || exit 1
  printf '%s\n' "$CS"
}

# snapshot — one line per thing the coordinator watches: each live
# touched and writer presence entry, without its time, each impact and
# each ack under it, and each plan with its checksum. A run entry
# comes and goes with every long command and asks nothing of it.
snapshot() {
  sn_now=$(date +%s)
  (cd "$HOSTWARDEN_CACHE" 2>/dev/null && ls -1d presence/* impact/* impact/*/ack/* 2>/dev/null) \
    | awk -F/ -v now="$sn_now" '
      $1 == "presence" {
        n = split($2, p, "+")
        if (p[n] ~ /^[0-9]+$/ && now - p[n] <= 1800) print "presence " p[1] " " p[2] " touched"
        next
      }
      $1 == "impact" && NF == 2 { print "impact " $2; next }
      $1 == "impact" && $3 == "ack" { split($2, i, "+"); print "ack " i[1] " " $4 }'
  # A writer entry counts while its own age is under 30 minutes, as
  # hostwarden_coord_affected (coord-lib.sh) counts it.
  find "$HOSTWARDEN_CACHE/presence" -mindepth 1 -maxdepth 1 -name '*+writer' -mmin -30 \
    2>/dev/null | while IFS= read -r sn_w; do
      sn_w=${sn_w##*/}; sn_w=${sn_w%+writer}
      echo "presence ${sn_w%%+*} ${sn_w#*+} writer"
    done
  for sn_f in "$M"/plans/*.md; do
    [ -f "$sn_f" ] && printf 'plan %s %s\n' "${sn_f##*/}" "$(cksum <"$sn_f" | cut -d' ' -f1)"
  done
}

do_watch() {
  [ $# -eq 0 ] || { usage >&2; exit 2; }
  impact_setup
  coordinator_mark || exit 1
  POLL=${HOSTWARDEN_WATCH_POLL:-5}
  OLD=$(mktemp "${TMPDIR:-/tmp}/hostwarden-watch.XXXXXX") || die "no temp file"
  NEW=$OLD.new
  trap 'rm -f "$OLD" "$NEW"' EXIT INT TERM
  : >"$OLD"
  ELAPSED=0 BEAT=0 TICK=0
  while :; do
    impact_prune
    snapshot | LC_ALL=C sort -u >"$NEW"
    LC_ALL=C comm -13 "$OLD" "$NEW" | sed 's/^/+ /'
    LC_ALL=C comm -23 "$OLD" "$NEW" | sed 's/^/- /'
    mv "$NEW" "$OLD"
    # Another mark that appeared since — two coordinators that
    # started at the same moment — settles at once, not at the next
    # renewal: the smaller session id stays.
    for ip_e in "$HOSTWARDEN_CACHE"/coordinator+*; do
      case $ip_e in "$HOSTWARDEN_CACHE/coordinator+$SESSION+"* | *'*') continue ;; esac
      [ -e "$ip_e" ] && { coordinator_mark || exit 1; BEAT=$ELAPSED; break; }
    done
    if [ $((ELAPSED - BEAT)) -ge 300 ]; then
      coordinator_mark || exit 1
      BEAT=$ELAPSED
    fi
    if [ $((ELAPSED - TICK)) -ge 900 ]; then
      grep -qs '^- Window:' "$M"/plans/*.md && echo "tick $(date +%H:%M)"
      TICK=$ELAPSED
    fi
    [ -z "${HOSTWARDEN_WATCH_ONCE:-}" ] || exit 0
    sleep "$POLL"
    ELAPSED=$((ELAPSED + POLL))
  done
}
