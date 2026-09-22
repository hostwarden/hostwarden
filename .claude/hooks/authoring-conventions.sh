#!/bin/sh
# authoring-conventions.sh — name the authoring rules when an
# instruction file is edited.
#
# Registered as a PostToolUse hook on Edit|Write. Emits
# hookSpecificOutput.additionalContext, which that event honors.
#
# Why a hook and not a `paths` glob: .claude/rules/ files load
# when a matching file is *read*, and a glob cannot tell reading
# a rule in order to follow it on a production host from reading
# it in order to edit it. rules/** and .agents/skills/** are the
# product, so a glob over them would load authoring conventions
# into every sysadmin session — the exact cost the layout removes.
# An edit is unambiguous: nobody edits the product by accident.
#
# Once per session, not once per edit. The pointer is worth
# saying; saying it after every Edit call is noise, and noise is
# what gets instructions ignored.

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"

INPUT=$(cat)

field() {
  # field <dotted.path> — one value out of the hook's JSON input.
  #
  # Three readers, because a workstation is whatever the user
  # runs Hostwarden from and this hook may not assume any one
  # interpreter is on it. Without the sed branch a host with
  # neither jq nor python3 loses the pointer and says nothing
  # about it, which is the one failure a hook whose whole job is
  # to speak up must not have.
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" \
      | jq -r --arg p "$1" \
        'getpath($p | split(".")) | strings // ""' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d, dict) else None
    if d is None:
        break
print(d if isinstance(d, str) else "")
' "$1" 2>/dev/null
  else
    # No parser, so match the leaf key as text. Sound for the two
    # keys this hook asks for: `file_path` and `session_id` each
    # occur once in the event, and a value carrying an escape is
    # a path no case below matches anyway.
    K="${1##*.}"
    printf '%s' "$INPUT" | tr ',{' '\n\n' \
      | sed -n "s/.*\"$K\"[[:blank:]]*:[[:blank:]]*\"\([^\"]*\)\".*/\1/p" \
      | head -1
  fi
}

FILE=$(field tool_input.file_path)
[ -n "$FILE" ] || exit 0

# Repo-relative, so a path outside the project cannot match.
case "$FILE" in
  "$ROOT"/*) REL="${FILE#"$ROOT"/}" ;;
  *) exit 0 ;;
esac

case "$REL" in
  rules/*.md|.agents/skills/*) ;;
  *) exit 0 ;;
esac

# Session-scoped marker. A session id the harness did not send
# means no dedup is possible, and saying it once too often beats
# not saying it at all.
SESSION=$(field session_id)
STATE="${TMPDIR:-/tmp}/hostwarden-authoring-$(id -u)"
if [ -n "$SESSION" ]; then
  mkdir -p "$STATE" 2>/dev/null || exit 0
  MARK="$STATE/$(printf '%s' "$SESSION" | tr -c 'A-Za-z0-9_-' '_')"
  [ -e "$MARK" ] && exit 0
  : > "$MARK" 2>/dev/null || exit 0
fi

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "You are editing Hostwarden's instruction set, which is the product. `.claude/rules/instruction-authoring.md` carries the conventions: which mechanism a new instruction belongs to, current state only (no before/after narration), 80-character wrapping, and example identifiers from RFC 2606/5737/3849 with Alice and Bob for people. Every change also gets one entry under `## Unreleased` in `CHANGELOG.md`, written as `.claude/rules/repo-release.md` says. Run `sh .claude/hooks/instructions-test.sh` and `sh .claude/hooks/guard-taboos-test.sh` before committing; they check the mechanical half. Said once per session."
  }
}
JSON
