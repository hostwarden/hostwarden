# guard-mode.d/operations.sh — operations: the shipped files are
# read-only. Sourced by guard-mode.sh, in the order its
# GUARD_MODULES lists, into the one shell every module shares; never
# run on its own.
# shellcheck shell=sh disable=SC2034 # read by the modules after it

if [ "$HOSTWARDEN_MODE" = operations ]; then
  # --- Operations: the shipped files are read-only ----------
  case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  *) exit 0 ;;
  esac
  if [ -z "$P" ]; then
    [ -n "$JQ" ] && exit 0
    deny "without jq the path of this edit cannot be read, so it \
cannot be shown to stay inside memory/ - install jq"
  fi
  case "$P" in
  /*) ;;
  *) P="$WD/$P" ;;
  esac
  # Resolve both sides physically, so a symlinked checkout path
  # or a .. segment cannot walk around the comparison. A file
  # that does not exist yet is judged by the directory it would
  # be created in.
  ROOT=$(cd "$ROOT" && pwd -P)
  D=${P%/*} B=${P##*/}
  while [ ! -d "${D:-/}" ]; do
    B="${D##*/}/$B" D=${D%/*}
  done
  REAL="$(cd "${D:-/}" && pwd -P)/$B"
  # An existing link as the last component is followed too: an
  # edit writes through it, so memory/x -> ../rules/y is rules/y.
  # Bounded, so a loop of links cannot hold the hook.
  n=0
  while [ -L "$REAL" ] && [ $n -lt 10 ]; do
    L=$(readlink "$REAL")
    case "$L" in /*) ;; *) L="${REAL%/*}/$L" ;; esac
    D=${L%/*} B=${L##*/}
    REAL="$(cd "${D:-/}" 2>/dev/null && pwd -P)/$B"
    n=$((n + 1))
  done
  # Still a link after ten steps: a loop, or a chain long enough
  # to hide where it ends. Either way it cannot be shown to stay
  # in memory/.
  [ -L "$REAL" ] && deny "this edit goes through a chain of links \
that does not end, so it cannot be shown to stay inside memory/"
  # A .. after a directory that does not exist stays unresolved,
  # and memory/nosuch/../../rules/x would pass for a path under
  # memory/. Inside the checkout, such a path counts as shipped.
  case "/$B/" in
  */../*)
    case "$REAL" in "$ROOT"/*) REAL="$ROOT/${B##*../}" ;; esac
    ;;
  esac
  case "$REAL" in
  "$ROOT"/memory/*) exit 0 ;;
  "$ROOT"/*) ;;
  *) exit 0 ;;
  esac
  REL=${REAL#"$ROOT"/}
  # Ignored means the user's own: local settings, history.
  # Everything else is what Hostwarden ships.
  if git -C "$ROOT" check-ignore -q --no-index -- "$REL" 2>/dev/null
  then
    exit 0
  fi
  deny "this checkout operates servers, so the files Hostwarden \
ships are read-only here - $REL is one of them. Only memory/ \
and other gitignored files may change. Make the change in a \
development checkout, a separate clone of Hostwarden or of your \
fork, and send it as a pull request"
fi
