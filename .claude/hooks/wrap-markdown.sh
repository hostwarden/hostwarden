#!/bin/sh
# wrap-markdown.sh — rewrap Markdown at 80 characters as soon as a
# tool has written it, with bin/hostwarden-wrap, so no agent wraps
# by hand. Registered as a PostToolUse hook, in both modes:
#
#   Edit, Write, MultiEdit  the file the tool wrote;
#   Bash, Monitor           every .md git sees as changed or new,
#                           since a command names no file: the
#                           checkout's in development, the
#                           workspace's (memory/) in operations.
#
# Tools without such a hook run the command themselves, and in
# operations bin/hostwarden-sync commit rewraps what it commits
# (AGENTS.md → Writing in this repo).
#
# A hook writes past guard-mode.sh, which keeps Hostwarden's own
# files read-only in an operations checkout. So there it rewraps
# only a file git ignores — memory/ and the like — and, in either
# mode, never a symbolic link or a file whose real path leaves the
# checkout.
#
# Emits hookSpecificOutput.additionalContext, which PostToolUse
# honors, only when there is something to say: a file was
# rewrapped, or a line in one is still over 80 and not a
# paragraph's.

ROOT=$(cd "${0%/*}/../.." && pwd -P)

# shellcheck disable=SC2034 # read by hook_field in json.sh
INPUT=$(cat)
# shellcheck source=../../lib/json.sh
. "$ROOT/lib/json.sh"
# shellcheck source=../../lib/mode.sh
. "$ROOT/lib/mode.sh"
hostwarden_mode "$ROOT"

# wrap <dir> <prefix> <args...> -- the command in <dir>, its names
# relative to it; <prefix> makes them relative to the checkout.
wrap() {
  d=$1 PREFIX=$2
  shift 2
  OUT=$(cd "$d" && sh "$ROOT/bin/hostwarden-wrap" "$@" 2>/dev/null)
}

FILE=$(hook_field file_path)
if [ -n "$FILE" ]; then
  case $FILE in
    /*.md) ;;
    *) exit 0 ;;
  esac
  [ -f "$FILE" ] && ! [ -L "$FILE" ] || exit 0
  # The real path, so a directory link inside memory/ that points
  # back into the checkout is judged by where it lands.
  DIR=$(cd "${FILE%/*}" 2>/dev/null && pwd -P) || exit 0
  case $DIR/ in
    "$ROOT"/*) REL=${DIR#"$ROOT"}/${FILE##*/}; REL=${REL#/} ;;
    *) exit 0 ;;
  esac
  if [ "$HOSTWARDEN_MODE" = operations ]; then
    git -C "$ROOT" check-ignore -q -- "$REL" 2>/dev/null || exit 0
  fi
  wrap "$ROOT" '' -- "$REL"
elif [ "$HOSTWARDEN_MODE" = operations ]; then
  # memory/ is a repository of its own, and all of it is ignored
  # by the checkout's.
  [ -e "$ROOT/memory/.git" ] || exit 0
  wrap "$ROOT/memory" memory/ --changed
else
  wrap "$ROOT" '' --changed
fi
[ -n "$OUT" ] || exit 0

DONE='' LEFT=''
while IFS= read -r l; do
  case $l in
    *': rewrapped') DONE="${DONE:+$DONE, }$PREFIX${l%: rewrapped}" ;;
    ?*) LEFT="$LEFT $PREFIX$l" ;;
  esac
done <<EOF
$OUT
EOF
MSG=''
[ -z "$DONE" ] || MSG="hostwarden-wrap rewrapped $DONE at 80 characters."
[ -z "$LEFT" ] || MSG="${MSG:+$MSG }Still over 80, and no paragraph it can rewrap:$LEFT. Shorten these lines by hand."
[ -n "$MSG" ] || exit 0

# A name git or the tool input carries has no quote, backslash or
# control character (hostwarden-wrap --changed leaves such a name
# alone, hook_field does not read one), so the message is JSON as
# it stands.
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse",'
printf '"additionalContext":"%s"}}\n' "$MSG"
