# lib/hostwarden-fleet-run/config.sh — the operator, the fleet key,
# the work directory, the state, the judge's schema and the
# blacklist. Sourced by bin/hostwarden-fleet-run, in the order its
# PARTS lists, into the one shell every part shares; never run on
# its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# user_line <field> — the value of "<field>: value" in user.md,
# bullet or not; a commented-out template line does not count.
user_line() {
  sed -n "s/^[-*[:space:]]*$1:[[:space:]]*//p" "$M/user.md" 2>/dev/null \
    | head -n 1 | sed 's/[[:space:]]*$//'
}
# mem_line <host> <field> — the first word after "- <field>:" in
# the host's memory.md.
mem_line() {
  mem_value "$1" "$2" | sed 's/[[:space:]].*//'
}
# mem_value <host> <field> — the whole value after "- <field>:".
mem_value() {
  sed -n "s/^- $2:[[:space:]]*//p" "$M/machines/$1/memory.md" 2>/dev/null \
    | head -n 1 | sed 's/[[:space:]]*$//'
}

# The machine's own operator handle names it in every journal line,
# and only once the remote's operators.md holds it, so it cannot be
# a teammate's (rules/ssh-user.md → Operator). Its line may carry a
# status in brackets; one marked inactive runs nothing
# (rules/session-start.md → The operator handle).
NAME=$(user_line 'Operator')
case $NAME in
  '' | *[!a-z0-9-]*)
    die "memory/user.md needs 'Operator: <this host's handle>'" ;;
esac
HLINE=$(git -C "$M" show '@{upstream}:operators.md' 2>/dev/null \
  | grep -E "^- ${NAME}[[:space:]]*(\(.*\))?[[:space:]]*\$" | head -n 1)
[ -n "$HLINE" ] \
  || die "Operator: $NAME is not in the remote's memory/operators.md yet"
case $HLINE in
  *'(inactive since'*)
    die "Operator: $NAME is marked inactive in memory/operators.md" ;;
esac
KEY=$(user_line 'Fleet key')
KEY=${KEY:-$HOME/.ssh/id_fleet_read}
# shellcheck disable=SC2088 # a literal ~/ from user.md, expanded here
case $KEY in '~/'*) KEY=$HOME/${KEY#??} ;; esac
[ -r "$KEY" ] || die "no readable fleet key at $KEY"
MAIL=$(user_line 'Report email')
PUSH=$(user_line 'Workspace push')
[ -r "$SIGNERS" ] || die "no $SIGNERS (hostwarden-fleet-read skill)"

WORK=$(mktemp -d) || die "no temporary directory"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 1' HUP INT TERM
mkdir "$WORK/judge-cwd" "$WORK/hosts" "$WORK/running" "$WORK/verified" \
  "$WORK/resolve-ok"

# When each finding was first seen. A dry run reads it where it
# exists and creates nothing: no directory, no lock.
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/hostwarden/fleet-run
PREV=$STATE/findings.json
if [ -n "$DRY" ]; then
  [ -f "$PREV" ] || { PREV=$WORK/findings.json; echo '{}' >"$PREV"; }
else
  mkdir -p "$STATE" && chmod 700 "$STATE" || die "no state directory"
  [ -f "$PREV" ] || echo '{}' >"$PREV"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$STATE/lock"
    flock -n 9 || die "another run is still going"
  fi
fi

TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%Y-%m-%d %H:%M')
TIMEOUT=
command -v timeout >/dev/null 2>&1 && TIMEOUT=timeout
MODEL=${HOSTWARDEN_FLEET_MODEL:-sonnet}

# note <text> — one line for the report's Notes.
NOTES=
note() { NOTES="$NOTES
- $1"; }
printf '%s\n' "${HOSTWARDEN_FLEET_RUN_START:-}" | LC_ALL=C tr -cd '[:print:]\n' \
  | grep -v '^$' | head -n 5 >"$WORK/start"
while IFS= read -r l; do note "at the start: $l"; done <"$WORK/start"

# The severity order, shared by every jq program in run.sh and
# report.sh.
JQ_SEV='def rank: {"CRITICAL": 0, "WARN": 1, "INFO": 2}[.] // 2;
def count($s): map(select(.severity == $s and .class != "decided")) | length;'

SCHEMA='{"type":"object","required":["report","findings"],
"properties":{"report":{"type":"string"},
"skipped":{"type":"array","items":{"type":"string"}},
"findings":{"type":"array","items":{"type":"object",
"required":["severity","code","text","class"],
"properties":{"severity":{"enum":["CRITICAL","WARN","INFO"]},
"code":{"type":"string"},"text":{"type":"string"},
"class":{"enum":["new","known","expected","decided"]},
"quote":{"type":["string","null"]}}}}}}'

hostwarden_resolver
# Caches hostwarden_resolve_ok's failures for a name across every
# host and hop this run checks, so one unreachable entry does not
# wait out dig again for each of them in turn.
# shellcheck disable=SC2034 # read by hostwarden_resolve_ok in resolve.sh
HOSTWARDEN_RESOLVE_CACHE=$WORK/resolve-ok

# The blacklist (rules/access-control.md → Shared Lookup Logic),
# every entry and what it resolves to, worked out once. Only a
# blacklist that exists makes a missing resolver tool worth a note:
# with none, every host on it is skipped as unverifiable.
BLACK=$(hostwarden_list_entries "$M/blacklist.md")
[ -z "$BLACK" ] || [ -n "$HOSTWARDEN_RESOLVER" ] \
  || note "no resolver tool here: every host on the blacklist is \
skipped as unverifiable"
# aliases_of <host> — the DNS-alias directories that link to the
# host's memory (rules/dns-aliases.md): the blacklist may name it by
# one of them.
aliases_of() {
  for al in "$M"/machines/*; do
    [ -L "$al" ] || continue
    at=$(readlink "$al"); at=${at%/}
    [ "${at##*/}" = "$1" ] && printf '%s ' "${al##*/}"
  done
}
# bl_why_unresolved <host> <reason> — sets BL_WHY and notes why <host>
# could not be cleared against the blacklist: hostwarden_resolve_ok's
# "no-dig" is a missing tool, not a resolver problem, and gets said
# that way (rules/dns-aliases.md → Detection step 1); anything else
# from it is a resolver that could not be reached.
bl_why_unresolved() {
  case $2 in
    no-dig)
      BL_WHY="blacklist unverifiable: no dig here to tell a clean miss \
from an outage"
      ;;
    *) BL_WHY="blacklist unverifiable: resolver unreachable" ;;
  esac
  note "$1: could not resolve it to check the blacklist ($2)"
}

# bl_check_unresolved <host> — true, having set BL_WHY and noted it,
# where $bl_a (the caller's own hostwarden_resolve "<host>") came
# back empty and hostwarden_resolve_ok cannot clear it either.
bl_check_unresolved() {
  [ -z "$bl_a" ] || return 1
  bl_r=$(hostwarden_resolve_ok "$1") && return 1
  bl_why_unresolved "$1" "$bl_r"
}

# blacklisted <host> <depth> [<user>] [<config>] — the host, the name
# ssh maps it to for that login user, its recorded IP or an address it
# resolves to is on the blacklist, or so is a jump host the
# connection would pass through, named by ProxyJump or by what
# ProxyCommand runs; or the path cannot be read, which counts the
# same: a blacklisted host is never reached, not even as a hop
# (rules/access-control.md → Server Blacklist). BL_WHY says which.
# <config> is the file ssh -G reads: - for the standard options,
# empty for the user's own, which is what a ProxyCommand's ssh reads
# without -F; = for a host reached another way than an ssh from here
# (a proxy, what a jump host goes on to), looked up by name and
# address alone. A resolver that cannot be reached while any of this
# runs counts as blacklisted too, never as a clean miss: this is the
# one gate before a connection, so it fails the same way whether it
# was never resolvable or could not be resolved right now.
blacklisted() {
  [ -n "$BLACK" ] || return 1
  [ "$2" -gt 0 ] || BL_SEEN=
  BL_WHY=blacklisted
  if hostwarden_listed "$BLACK" \
    "$HOSTWARDEN_UNRESOLVED_NO_DIG $HOSTWARDEN_UNRESOLVED_UNREACHABLE"; then
    bl_words=$(hostwarden_unresolved_words "$BLACK")
    BL_WHY="blacklist unverifiable: $bl_words"
    note "$1: the blacklist has an entry the resolver could not check ($bl_words)"
    return 0
  fi
  if [ "${4-}" = = ]; then
    bl_a=$(hostwarden_resolve "$1")
    for x in "$1" $(mem_line "$1" IP) $bl_a $(aliases_of "$1"); do
      case " $BLACK " in *" $x "*) return 0 ;; esac
    done
    bl_check_unresolved "$1" && return 0
    return 1
  fi
  bl_c=$SSHCFG
  [ "${4--}" = - ] || bl_c=$4
  if ! bl_g=$(ssh ${bl_c:+-F "$bl_c"} -G ${3:+-l "$3"} "$1" </dev/null 2>/dev/null); then
    BL_WHY="configuration not readable"
    note "$1: ssh -G could not read its configuration${bl_c:+ ($bl_c)}"
    return 0
  fi
  bl_a=$(hostwarden_resolve "$1")
  for x in "$1" "$(printf '%s\n' "$bl_g" | sed -n 's/^hostname //p')" \
      $(mem_line "$1" IP) $bl_a $(aliases_of "$1"); do
    [ -n "$x" ] || continue
    case " $BLACK " in *" $x "*) return 0 ;; esac
  done
  bl_check_unresolved "$1" && return 0
  # The hops, each as <config>|<user>|<host>, and !|| where the path
  # cannot be read (lib/hops.sh).
  hops=$(printf '%s\n' "$bl_g" | hostwarden_hops "$1" "${4--}")
  # A path that cannot be read counts as blacklisted, and so does a
  # chain longer than five hops: no one is here to answer for it. The
  # program alone is named: the rest of the line can hold a password.
  case $hops in *'!||'*)
    BL_WHY="jump path not readable"
    note "$1: the blacklist check cannot read the path its ProxyCommand ($(printf '%s\n' \
      "$bl_g" | sed -n 's/^proxycommand //p' | awk '{ print ($1 == "exec" ? $2 : $1) }')) takes"
    return 0 ;;
  esac
  if [ "$2" -ge 5 ] && [ -n "$(printf '%s' "$hops" | grep -v '^!||')" ]; then
    BL_WHY="jump path not readable"
    note "$1: its jump path is longer than five hops"
    return 0
  fi
  for e in $hops; do
    # A hop checked once in this lookup is not checked again.
    case " !|| $BL_SEEN " in *" $e "*) continue ;; esac
    BL_SEEN="$BL_SEEN $e"
    ju=${e#*|}
    blacklisted "${e##*|}" $(($2 + 1)) "${ju%|*}" "${e%%|*}" && return 0
  done
  return 1
}
