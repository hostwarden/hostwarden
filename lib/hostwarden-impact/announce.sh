# lib/hostwarden-impact/announce.sh — announce, wait, ack, done and
# status. Sourced by bin/hostwarden-impact, in the order its PARTS
# lists, into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# untell <dir> — removes the register entries announce made on the
# hosts under <dir>/remote/, one call each; a host that cannot be
# reached, or is on the blacklist by now, keeps its entry until it
# goes stale.
untell() {
  [ -d "$1/remote" ] || return 0
  team_setup lists
  u_id=${1##*/}; u_id=${u_id%%+*}
  for f in "$1"/remote/*; do
    [ -e "$f" ] || continue
    h=${f##*/}
    way_in "$h"
    blocked "$h" >/dev/null \
      && { echo "entry left: $h ($BLOCKED_WHY; it goes stale on its own)"; continue; }
    # shellcheck disable=SC2154 # way_in (team.sh) sets u and dest
    ssh -F "$SSHCFG" -l "$u" ${port:+-p "$port"} "$dest" \
      "rmdir /tmp/hostwarden/$u_id+* 2>/dev/null; true" </dev/null >/dev/null 2>&1 \
      || echo "entry left: $h (not reached; it goes stale on its own)"
  done
}

do_announce() {
  [ $# -ge 2 ] || { usage >&2; exit 2; }
  ip_prev='' ip_last=''
  for ip_a in "$@"; do ip_prev=$ip_last ip_last=$ip_a; done
  case $ip_last in
    '' | *[!0-9]*) AKIND=$ip_last AMIN='' ip_hn=$(($# - 1)) ;;
    *) AMIN=$ip_last AKIND=$ip_prev ip_hn=$(($# - 2)) ;;
  esac
  [ "$ip_hn" -ge 1 ] || { usage >&2; exit 2; }
  case $AKIND in
    reboot | network | firewall) ;;
    restart:?*) case ${AKIND#restart:} in *[!A-Za-z0-9@._:-]*) usage >&2; exit 2 ;; esac ;;
    *) usage >&2; exit 2 ;;
  esac
  AHOSTS='' ip_i=0
  for ip_a in "$@"; do
    ip_i=$((ip_i + 1))
    [ "$ip_i" -le "$ip_hn" ] || break
    case $ip_a in *[!A-Za-z0-9@._:%-]*) usage >&2; exit 2 ;; esac
    AHOSTS="$AHOSTS $ip_a"
  done
  case $AKIND in
    reboot) : "${AMIN:=10}" ;;
    network) : "${AMIN:=5}" ;;
    *) : "${AMIN:=2}" ;;
  esac
  case $AMIN in *[!0-9]* | '') usage >&2; exit 2 ;; esac

  impact_setup
  impact_prune
  RADIUS=$(hostwarden_coord_radius "$REPO_DIR" "$AHOSTS" "$AKIND") \
    || die "the radius could not be computed"
  HOSTLIST=$(printf '%s\n' "$RADIUS" | awk '{print $1}')

  ID=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
  SESSION=$(impact_session)
  NOW=$(date +%s)
  UNTIL=$((NOW + AMIN * 60))
  ORIGINJ=$(printf '%s\n' "$AHOSTS" | awk '{ $1=$1; print }' \
    | tr ' ' ',')
  DIR="$HOSTWARDEN_CACHE/impact/$ID+$ORIGINJ+$AKIND+$UNTIL+$SESSION"
  mkdir -p "$DIR/radius" || die "cannot write $DIR"
  chmod 700 "$DIR" 2>/dev/null
  # shellcheck disable=SC2034 # ip_rest keeps a detail word off ip_thr
  printf '%s\n' "$RADIUS" | while IFS=' ' read -r ip_h ip_rel ip_thr ip_rest; do
    [ -n "$ip_h" ] || continue
    : > "$DIR/radius/$ip_h+$ip_rel+${ip_thr:--}"
  done

  echo "$ID"
  AFF=$(hostwarden_coord_affected "$HOSTWARDEN_CACHE" "$HOSTLIST" "$SESSION")
  if [ -z "$AFF" ]; then
    echo "no live session on the radius; proceeding"
  else
    printf '%s\n' "$AFF" | awk '
      { pr = ($3 == "run") ? 3 : ($3 == "writer") ? 2 : 1
        if (pr > best[$1] || !($1 in best)) { best[$1] = pr; bh[$1] = $2; bk[$1] = $3 } }
      END { for (s in best) print s, bh[s], bk[s] }' | sort
  fi
  if impact_team; then tell "$DIR" "$RADIUS"; fi
}

do_wait() {
  [ $# -eq 1 ] || { usage >&2; exit 2; }
  impact_setup
  SESSION=$(impact_session)
  DIR=$(impact_dir_for_id "$1") || die "no active impact $1"
  HOSTS=$(for ip_r in "$DIR"/radius/*; do
    [ -e "$ip_r" ] || continue
    printf '%s\n' "${ip_r##*/}" | cut -d+ -f1
  done)
  POLL=${HOSTWARDEN_IMPACT_WAIT_POLL:-5}
  MAXT=${HOSTWARDEN_IMPACT_WAIT_MAX:-120}
  WORK=$(mktemp "${TMPDIR:-/tmp}/hostwarden-impact-wait.XXXXXX") \
    || die "no temp file"
  trap 'rm -f "$WORK"' EXIT INT TERM
  ELAPSED=0
  while :; do
    : > "$WORK"
    hostwarden_coord_affected "$HOSTWARDEN_CACHE" "$HOSTS" "$SESSION" \
      | while IFS=' ' read -r ip_s ip_h ip_k; do
      [ -n "$ip_s" ] || continue
      if [ "$ip_k" = run ]; then
        echo "$ip_s run on $ip_h" >> "$WORK"
      elif [ "$ip_k" = writer ]; then
        ACKF="$DIR/ack/$ip_s"
        if [ -f "$ACKF" ] && [ "$(awk '{print $1}' "$ACKF")" = safe ]; then
          :
        elif [ -f "$ACKF" ]; then
          echo "$ip_s busy on $ip_h" >> "$WORK"
        else
          echo "$ip_s no answer on $ip_h" >> "$WORK"
        fi
      fi
    done
    if [ ! -s "$WORK" ]; then
      echo "all safe"
      exit 0
    fi
    [ "$ELAPSED" -ge "$MAXT" ] && break
    sleep "$POLL"
    ELAPSED=$((ELAPSED + POLL))
  done
  echo "not all safe:"
  sort -u "$WORK"
  exit 1
}

do_ack() {
  [ $# -ge 2 ] || { usage >&2; exit 2; }
  case $2 in safe | busy) ;; *) usage >&2; exit 2 ;; esac
  impact_setup
  DIR=$(impact_dir_for_id "$1") || die "no active impact $1"
  ST=$2
  shift 2
  SESSION=$(impact_session)
  # shellcheck disable=SC2174 # $DIR exists already; only ack/ is new
  mkdir -p -m 700 "$DIR/ack" 2>/dev/null
  printf '%s %s\n' "$ST" "$*" > "$DIR/ack/$SESSION"
}

do_done() {
  [ $# -eq 1 ] || { usage >&2; exit 2; }
  impact_setup
  if DIR=$(impact_dir_for_id "$1"); then
    untell "$DIR"
    rm -rf "$DIR"
  fi
  exit 0
}

do_status() {
  [ $# -eq 1 ] || { usage >&2; exit 2; }
  impact_setup
  impact_prune
  CH=$(hostwarden_coord_canon "$HOSTWARDEN_CACHE/radius.idx" "$1" "$REPO_DIR")
  FOUND=1
  for ip_d in "$HOSTWARDEN_CACHE"/impact/*; do
    [ -d "$ip_d" ] || continue
    ip_b=${ip_d##*/}
    ip_origin=$(printf '%s' "$ip_b" | cut -d+ -f2)
    ip_kind=$(printf '%s' "$ip_b" | cut -d+ -f3)
    ip_until=$(printf '%s' "$ip_b" | cut -d+ -f4)
    ip_sess=$(printf '%s' "$ip_b" | cut -d+ -f5)
    for ip_r in "$ip_d/radius/$CH+"*; do
      [ -e "$ip_r" ] || continue
      ip_rb=${ip_r##*/}
      ip_rel=$(printf '%s' "$ip_rb" | cut -d+ -f2)
      ip_thr=$(printf '%s' "$ip_rb" | cut -d+ -f3)
      echo "$ip_origin $ip_kind by $ip_sess until $(hostwarden_coord_hhmm "$ip_until"); $CH $ip_rel $ip_thr"
      FOUND=0
    done
  done
  window_status "$CH" && FOUND=0
  exit $FOUND
}
