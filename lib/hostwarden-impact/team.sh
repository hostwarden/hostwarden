# lib/hostwarden-impact/team.sh — teams: who else works on a host,
# and telling them. Sourced by bin/hostwarden-impact, in the order
# its PARTS lists, into the one shell every part shares; never run
# on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- teams --------------------------------------------------------

# impact_team — true where memory/operators.md lists two or more
# active people: a handle without "(inactive since …)" and without
# "(operations host)" (rules/coordination.md → Teams). A workspace
# with a remote is no team by itself.
impact_team() {
  awk '
    /^- [a-z0-9-]+[ \t]*(\(.*\))?[ \t]*$/ {
      if ($0 ~ /\((inactive since|operations host)/) next
      n++
    }
    END { exit !(n >= 2) }' "$M/operators.md" 2>/dev/null
}

# host_value <host> <key> — the value of "- <key>:" in the host's
# memory.md, from the fields list in $TW/fields.
host_value() {
  awk -F "$TAB" -v h="$1" -v k="$2" \
    '$1 == h && $2 == k { print $3; exit }' "$TW/fields"
}

# way_in <host> — sets dest, port and u to how the host is logged
# into: its Reached as: destination with its SSH port:, else its own
# name, as the user memory/user.md gives it (rules/ssh-user.md).
way_in() {
  dest=$(host_value "$1" 'Reached as' | awk '{ print $1 }')
  port=''
  [ -n "$dest" ] && port=$(host_value "$1" 'SSH port' | awk '$1 ~ /^[0-9]+$/ { print $1 }')
  dest=${dest:-$1}
  u=$(user_for "$dest")
  case $dest in *@*) u=${dest%%@*} dest=${dest#*@} ;; esac
}

# names_of <host> <dest> — every name and address the lists are
# matched against for <host>: the host, its destination, the names
# the index knows it by (its IP: and FQDN: among them, and each
# DNS-alias directory that links to it) and what the
# destination resolves to (rules/access-control.md → Shared Lookup
# Logic).
names_of() {
  printf '%s %s ' "$1" "$2"
  awk -F "$TAB" -v h="$1" '($1 == "K" || $1 == "A") && $2 == h { printf "%s ", $3 }
    $1 == "N" && $3 == h { printf "%s ", $2 }' "$IDX"
  hostwarden_resolve_or_unresolved "$2"
}

# hop_names <host> — each hop on the host's way in, what it resolves
# to and, where memory knows the hop, the names of its DNS-alias
# directories. The alias names come from the index, which does not
# change during the call, and are looked up once per hop however
# many hosts share it; what the hop resolves to is asked at every
# check, since a clean miss from an earlier one proves nothing once
# the resolver is down (lib/resolve.sh → hostwarden_resolve_ok).
hop_names() {
  for hop in $(awk -F "$TAB" -v h="$1" '$1 == "J" && $2 == h { print $3 }' "$IDX"); do
    memo="$TW/hop.$(printf '%s' "$hop" | cksum | cut -d' ' -f1)"
    [ -f "$memo" ] || awk -F "$TAB" -v k="$hop" '$1 == "K" && $3 == k { h[$2] = 1 }
        $1 == "N" { n[$3] = n[$3] " " $2 }
        END { for (x in h) printf "%s ", n[x] }' "$IDX" >"$memo"
    printf '%s %s ' "$hop" "$(hostwarden_resolve_or_unresolved "$hop")"
    cat "$memo"
  done
}

# blocked <host> — true, having named the host, where it or a hop on
# its way in is on memory/blacklist.md as the file is now: read again
# right before every call, the cleanup's included, since a host can
# be listed while the calls before it run (rules/access-control.md →
# Server Blacklist). Sets names for the read-only check, and
# BLOCKED_WHY to the reason where true. A resolver
# that cannot be reached while any of this runs is treated as if the
# host were blacklisted, never as a clean miss (rules/access-control.md
# → Server Blacklist): "no entry" either way, since the fail-safe
# outcome for hostwarden-impact's team-telling is the same one the
# blacklist itself gets.
blocked() {
  BLACK=$(hostwarden_list_entries "$M/blacklist.md")
  names=''
  [ -z "$BLACK$RO" ] || names=$(names_of "$1" "$dest")
  if [ -n "$BLACK" ]; then
    hops=$(hop_names "$1")
    if hostwarden_listed "$BLACK $names $hops" "$HOSTWARDEN_UNRESOLVED_NO_DIG \
$HOSTWARDEN_UNRESOLVED_UNREACHABLE"; then
      BLOCKED_WHY="blacklist unverifiable: \
$(hostwarden_unresolved_words "$BLACK $names $hops")"
      echo "no entry: $1 ($BLOCKED_WHY)"
      return 0
    fi
    if hostwarden_listed "$BLACK" "$names $hops"; then
      BLOCKED_WHY='blacklisted now'
      echo "no entry: $1 (blacklisted, or a hop on its way in is)"
      return 0
    fi
  fi
  return 1
}

# tell_one <host> — the one call a radius host gets in a team: the
# register entry (rules/parallel-sessions.md → Register, and renew,
# with <until> as its beat) and the journal line
# (rules/changelog.md → Impact lines). Prints one result line, or
# nothing where the host got both, and marks remote/<host> where it
# got the entry. The hosts it leaves out are rules/coordination.md →
# Teams's.
tell_one() {
  h=$1
  case $(host_value "$h" Mode | tr '[:upper:]' '[:lower:]') in
    via*) echo "no entry: $h (reached through its host)"; return ;;
    local*) echo "no entry: $h (the local machine)"; return ;;
  esac
  case $(host_value "$h" 'Distro family' | tr '[:upper:]' '[:lower:]') in
    windows*) echo "no entry: $h (Windows: no sh to write with)"; return ;;
  esac
  case $(host_value "$h" SSH) in
    untested*) echo "no entry: $h (never connected)"; return ;;
  esac
  way_in "$h"
  [ -n "$u" ] || { echo "no entry: $h (no SSH user in memory/user.md)"; return; }
  blocked "$h" && return
  if ! g=$(ssh -F "$SSHCFG" -G -l "$u" ${port:+-p "$port"} "$dest" </dev/null 2>/dev/null); then
    echo "no entry: $h (ssh -G cannot read its configuration)"; return
  fi
  kh=$(printf '%s\n' "$g" | awk '$1 == "hostkeyalias" { a = $2 } $1 == "hostname" { n = $2 }
    $1 == "port" { p = $2 } END { k = (a != "" ? a : n); print (p == 22 ? k : "[" k "]:" p) }')
  if ! ssh-keygen -F "$kh" -f "$M/known_hosts" >/dev/null 2>&1; then
    echo "no entry: $h (no key in memory/known_hosts)"; return
  fi
  # The journal line goes where the host's OS file writes one
  # (rules/changelog.md → Journal Headlines): QNAP's event log
  # through log_tool, none where memory records that logger does not
  # land (rules/appliance/synology-dsm.md → Logs), syslog elsewhere.
  case $(host_value "$h" Journal):$(host_value "$h" Appliance) in
    'not written'*) log='' ;;
    *:QTS* | *:QuTS*) log=$T_QLOG ;;
    *) log=$T_LOG ;;
  esac
  reg=1
  ro_reason=read-only
  if [ -n "$RO_UNRESOLVED" ] || hostwarden_listed "$names" \
    "$HOSTWARDEN_UNRESOLVED_NO_DIG $HOSTWARDEN_UNRESOLVED_UNREACHABLE"; then
    reg=''
    ro_reason="read-only status unverifiable: \
$(hostwarden_unresolved_words "$RO $names")"
  elif [ "$RO_ALL" = 1 ] || { [ -n "$RO" ] && hostwarden_listed "$RO" "$names"; }; then
    reg=''
  fi
  if [ -z "$reg$log" ]; then
    echo "no entry: $h ($ro_reason, and memory says its journal is not written)"
    return
  fi
  out=$({ [ -z "$reg" ] || printf '%s\n' "$T_REG"; [ -z "$log" ] || printf '%s\n' "$log"; } \
    | ssh -F "$SSHCFG" -l "$u" ${port:+-p "$port"} "$dest" sh -s 2>/dev/null)
  case $out in *registered*) : >"$T_DIR/remote/$h" ;; esac
  case ${reg:-ro}:$out in
    *registered*logged*) ;;
    ro:*logged*) echo "journal only: $h ($ro_reason)" ;;
    *logged*) echo "journal only: $h (no register it can use)" ;;
    *registered*)
      if [ -n "$log" ]; then echo "register only: $h (the journal line failed)"
      else echo "register only: $h (memory says its journal is not written)"; fi ;;
    *:) echo "no entry: $h (not reached)" ;;
    *) echo "no entry: $h (neither written)" ;;
  esac
}

# team_setup [lists] — what tell_one and untell read, worked out
# once; with "lists", also the access lists tell_one checks.
team_setup() {
  SSHCFG=$REPO_DIR/memory/ssh_config
  [ -r "$SSHCFG" ] || sh bin/hostwarden-ssh-config >&2
  TW=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-impact-team.XXXXXX") || die "no temp directory"
  trap 'rm -rf "$TW"' EXIT INT TERM
  fields >"$TW/fields"
  [ "${1:-}" = lists ] || return 0
  IDX=$HOSTWARDEN_CACHE/radius.idx
  hostwarden_resolver
  # Caches hostwarden_resolve_ok's failures for a name across every
  # radius host this team-telling call checks, so one unreachable
  # entry does not wait out dig again for each of them in turn.
  # shellcheck disable=SC2034 # read by hostwarden_resolve_ok in resolve.sh
  HOSTWARDEN_RESOLVE_CACHE=$TW
  RO=$(hostwarden_list_entries "$M/readonly.md")
  RO_ALL=0
  case " $RO " in *' * '*) RO_ALL=1 ;; esac
  # A readonly.md entry the resolver could not check leaves every
  # host's read-only status unverifiable for this run: default to
  # the safe direction, read-only, rather than to registering a
  # write on a host the list might actually cover.
  RO_UNRESOLVED=''
  hostwarden_listed "$RO" \
    "$HOSTWARDEN_UNRESOLVED_NO_DIG $HOSTWARDEN_UNRESOLVED_UNREACHABLE" \
    && RO_UNRESOLVED=1
}

# tell <dir> <radius> — tell_one for every radius host with memory
# here, the hosts behind one jump host one after another and the
# groups side by side (rules/multi-host.md → Order), then the
# summary. The impact is ID, UNTIL, AKIND and ORIGINJ of announce.
tell() {
  T_DIR=$1
  team_setup lists
  T_OP=$(sed -n 's/^[-*[:space:]]*Operator:[[:space:]]*//p' "$M/user.md" 2>/dev/null \
    | head -n 1 | awk '{ print $1 }')
  case $T_OP in '' | *[!a-z0-9-]*) T_OP=user ;; esac
  T_WS="$(hostwarden_coord_sanitize "$(id -un)")@$(hostwarden_coord_sanitize \
    "$(hostname -s 2>/dev/null || hostname)")"
  T_TASK=$(printf 'impact-%s-%s' "$AKIND" "$ORIGINJ" | tr ':' '-' \
    | tr '[:upper:]' '[:lower:]')
  # The two parts of the call, their values filled in here: every one
  # of them is held to the characters announce accepts, none of which
  # a shell or sed's | reads. The register part is the call of
  # rules/parallel-sessions.md → Register, and renew, with <until> as
  # the beat, which that section allows for a step that ends later.
  fill() {
    sed -e "s|@ID@|$ID|g" -e "s|@UNTIL@|$UNTIL|g" -e "s|@WS@|$T_WS|g" \
      -e "s|@TASK@|$T_TASK|g" -e "s|@OP@|$T_OP|g" -e "s|@KIND@|$AKIND|g" \
      -e "s|@ORIGIN@|$ORIGINJ|g"
  }
  T_REG=$(fill <<'EOF'
D=/tmp/hostwarden
[ -e "$D" ] || (umask 0 && mkdir "$D")
ls -ld "$D"
if [ ! -L "$D" ] && cd "$D" 2>/dev/null \
   && [ "$(pwd -P)" = "$(cd /tmp && pwd -P)/hostwarden" ] \
   && [ "$(ls -ld . | cut -c1-10)" = drwxrwxrwx ]; then
  N="@ID@+@UNTIL@+@WS@+@TASK@"
  E=$(ls -d @ID@+* 2>/dev/null)
  if [ -n "$E" ]; then mv "$E" "$N"; else mkdir "$N"; fi && echo registered
fi
cd /
EOF
)
  T_LOG=$(fill <<'EOF'
hm=$(date -d @@UNTIL@ +%H:%M 2>/dev/null || date -r @UNTIL@ +%H:%M 2>/dev/null || echo @UNTIL@)
logger -t hostwarden "[@OP@ as $(id -un)] impact @ID@: @KIND@ of @ORIGIN@ until $hm" && echo logged
EOF
)
  T_QLOG=$(fill <<'EOF'
hm=$(date -d @@UNTIL@ +%H:%M 2>/dev/null || date -r @UNTIL@ +%H:%M 2>/dev/null || echo @UNTIL@)
/sbin/log_tool -t0 -uSystem -p127.0.0.1 -mlocalhost -a "hostwarden: [@OP@ as $(id -un)] impact @ID@: @KIND@ of @ORIGIN@ until $hm" && echo logged
EOF
)
  mkdir -p "$T_DIR/remote" "$TW/out"
  # A host without memory here never gets a call, so it is not walked
  # for its jump group either.
  hosts=''
  for th in $(printf '%s\n' "$2" | awk '{ print $1 }'); do
    if [ -f "$M/machines/$th/memory.md" ]; then hosts="$hosts $th"
    else echo "no entry: $th (no memory here)" >>"$TW/out/nomem"
    fi
  done
  # shellcheck disable=SC2086 # each host is its own argument
  [ -z "$hosts" ] || sh "$SCRIPT_DIR/hostwarden-impact" radius --jumps $hosts \
    >"$TW/groups" 2>/dev/null
  gi=0
  while read -r what rest; do
    gi=$((gi + 1))
    case $what in
      unreadable) echo "no entry: $rest (way in not readable)" >"$TW/out/u$gi" ;;
      group) ( for gh in $rest; do tell_one "$gh"; done >"$TW/out/g$gi" ) & ;;
    esac
  done <"$TW/groups"
  wait
  n=$(printf '%s\n' "$2" | grep -c .)
  cat "$TW"/out/* 2>/dev/null | sort >"$TW/results"
  k=$(grep -c . "$TW/results")
  echo "team: register entry and journal line on $((n - k)) of $n hosts"
  cat "$TW/results"
}
