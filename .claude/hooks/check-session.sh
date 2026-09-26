#!/bin/sh
# check-session.sh — SessionStart hook: say when the taboo guard is
# switched off for this session, before anything reaches a machine,
# and in an operations checkout start the coordinator where none
# runs, in one line. Silent otherwise. (A linked worktree is
# announced by session-mode.sh, with the rest of the mode.)
#
# The taboo guard switched off toward one host. Only a session
#    that STARTS with HOSTWARDEN_GUARD_DISABLE naming one host, or
#    localhost — from the shell, or a settings file the operator
#    edited before starting it — gets it: this hook records the host
#    in ~/.cache/hostwarden/guard-off-<session_id>, and
#    guard-taboos.d/off.sh honours the variable only where the
#    record holds the host it names. A value that names no single
#    host, such as `1` or a list, is refused and recorded nowhere. A
#    value that arrives or changes mid-session, through a settings
#    file reloaded while it runs, finds no record of itself and
#    changes nothing. Only `startup` and `resume` start a process
#    with a fresh environment; `clear` and `compact` run inside the
#    old one and may only take a record away. The notice at every
#    start is also how the operator sees that the setting took
#    effect.

# shellcheck disable=SC2034 # read by hook_field in json.sh
INPUT=$(cat)
case $0 in */*) HERE=${0%/*} ;; *) HERE=. ;; esac
# shellcheck source=../../lib/json.sh
. "$HERE/../../lib/json.sh"
# shellcheck source=../../lib/mode.sh
. "$HERE/../../lib/mode.sh"

CACHE="$HOME/.cache/hostwarden"
SID=$(hook_session_id)
REC=$(hostwarden_off_record "$SID")
OFF=""
if [ -n "${HOSTWARDEN_GUARD_DISABLE:-}" ] &&
  ! OFF=$(hostwarden_off_host "$HOSTWARDEN_GUARD_DISABLE"); then
  echo "hostwarden: HOSTWARDEN_GUARD_DISABLE names no single host, so"
  echo "  the taboo guard stays ON. Tell the user: the operator sets it"
  echo "  to the one host the work is for, or to localhost, and starts"
  echo "  a new session."
fi
if [ -n "$OFF" ] && [ -n "$SID" ]; then
  case "$(hook_field source '[A-Za-z0-9_-]')" in
    startup|resume|"")
      # shellcheck disable=SC2174 # 0700 is for $CACHE alone
      mkdir -p -m 700 "$CACHE" && printf '%s\n' "$OFF" > "$REC" ;;
  esac
fi
if [ -n "$SID" ] && [ -e "$REC" ]; then
  if hostwarden_off_recorded "$SID" "${HOSTWARDEN_GUARD_DISABLE:-}" \
    >/dev/null; then
    echo "hostwarden: the taboo guard is OFF toward $OFF for this session"
    echo "  and on for everything else. Say so in your first reply; unless"
    echo "  this session is for the disk steps of an OS install on $OFF,"
    echo "  ask the user to remove it and start a new one."
  else
    rm -f "$REC"
  fi
elif [ -n "$OFF" ]; then
  echo "hostwarden: HOSTWARDEN_GUARD_DISABLE is set, but this session"
  echo "  did not start with it, so the taboo guard stays ON. Tell the"
  echo "  user: the operator sets it and then starts a new session."
fi

# Records of sessions long gone.
find "$CACHE" -name 'guard-off-*' -mtime +2 -exec rm -f {} + 2>/dev/null

# The coordinator (rules/coordination.md → The coordinator). An
# operations checkout's session starts one in the background when
# none runs for this checkout, unless memory/user.md says
# `Coordinator: off`; a development checkout and a worktree start
# none. `bin/hostwarden-impact coordinator` says whether one
# is live. The start lock, an atomic mkdir, keeps two sessions
# starting at once — and the background session's own start, which
# runs this hook too — from starting a second; the coordinator
# checks for another on its own start as well. `claude --bg` goes
# into the background itself, since it takes about two seconds of
# the hook's five.
case "$(hook_field source '[A-Za-z0-9_-]')" in startup | resume | "") ;; *) exit 0 ;; esac
# cd && pwd, no -P: the same string presence.sh and
# bin/hostwarden-impact hash for the cache directory.
ROOT=$(cd "$HERE/../.." 2>/dev/null && pwd) || exit 0
hostwarden_mode "$ROOT"
[ "$HOSTWARDEN_MODE" = operations ] || exit 0
grep -Eqi '^[-*[:space:]]*Coordinator:[[:space:]]*off([[:space:]]|$)' \
  "$ROOT/memory/user.md" 2>/dev/null && exit 0
command -v claude >/dev/null 2>&1 || exit 0
sh "$ROOT/bin/hostwarden-impact" coordinator >/dev/null 2>&1 && exit 0
hostwarden_cache_dir "$ROOT"
LOCK=$HOSTWARDEN_CACHE/coordinator-start
[ -n "$(find "$LOCK" -maxdepth 0 -mmin +2 2>/dev/null)" ] && rmdir "$LOCK" 2>/dev/null
mkdir "$LOCK" 2>/dev/null || exit 0
(cd "$ROOT" && claude --bg -n "hostwarden coordinator" "/hostwarden-coordinator" \
  </dev/null >/dev/null 2>&1 &)
echo "hostwarden: coordinator started in the background; /hostwarden-coordinator stops it for good."

exit 0
