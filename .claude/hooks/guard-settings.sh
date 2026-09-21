#!/bin/sh
# guard-settings.sh — PreToolUse hook (matcher: Bash|Edit|Write|MultiEdit).
#
# The taboo guard honours HOSTWARDEN_GUARD_DISABLE only when the
# session STARTED with it: check-session.sh (SessionStart) records
# that in ~/.cache/hostwarden/guard-off-<session_id>, and
# guard-taboos.sh looks for the record. A value that reaches the
# environment mid-session — the `env` key of a settings file is
# reloaded while the session runs — switches nothing off, however it
# was written. What is left for this hook is small:
#
#   - keep the variable out of Claude Code settings files, where it
#     would switch the guard off for the NEXT session: an Edit, Write
#     or MultiEdit of a settings file (any letter case — macOS and
#     Windows resolve SETTINGS.JSON to the same file; either path
#     separator) whose new text names it, and a Bash command that
#     names it and a settings file. A Bash command naming both
#     cannot be told from a read, so a grep of the two together is
#     denied too; grep one at a time.
#   - while the project or user settings file already carries it,
#     any Edit or MultiEdit of that file and any Bash command naming
#     a settings file: either could flip "0" to "1" without naming
#     the variable. A Write without it — or the operator, by hand —
#     takes it out.
#   - keep hands off the records: any write to a guard-off-* file,
#     and any Bash command that names guard-off- at all (grep for
#     "guard-off" without the hyphen when reading about it).
#
# The operator sets the variable by hand, which reaches no hook, and
# starts a new session (README → Claude Code Desktop). The next
# session's start-up notice says the guard is off, whichever way it
# got there — that notice, not this hook, is what the operator reads.
#
# Deliberately NOT honouring HOSTWARDEN_GUARD_DISABLE: a guard that
# is off for one session must not let the model make it off for the
# next. A backstop against the everyday mistake, not a sandbox.

INPUT=$(cat)
V=HOSTWARDEN_GUARD_DISABLE

# Only the tool's own input counts: the envelope names paths under
# ~/.claude for every call. One case, no fork, for nearly every call.
TI=${INPUT#*\"tool_input\"}
case "$TI" in
  *"$V"*|*guard-off-*) ;;
  *[Ss][Ee][Tt][Tt][Ii][Nn][Gg][Ss]*.[Jj][Ss][Oo][Nn]*) ;;
  *) exit 0 ;;
esac

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
  printf '"permissionDecision":"deny",'
  printf '"permissionDecisionReason":"hostwarden guard: '
  printf 'HOSTWARDEN_GUARD_DISABLE and its session records belong to '
  printf 'the operator, who sets the variable by hand before a session '
  printf 'starts (AGENTS.md - Critical Safety Rules). Blocked in all '
  printf 'permission modes. Explain this to the user; do not look for '
  printf 'another way to write it. README - Claude Code Desktop '
  printf 'describes what the operator does."}}\n'
  exit 0
}

SETTINGS_RE='settings(\.local)?\.json|managed-settings\.json'
RECORD_RE='guard-off-'

# A settings file this session loads that already carries the
# variable. Two files, test and grep, no parsing of paths.
PROJECT=${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}
any_holds_var() {
  grep -qs "$V" "$PROJECT/.claude/settings.local.json" \
    "$PROJECT/.claude/settings.json" "$HOME/.claude/settings.json"
}

# One jq call, three lines: tool, target, and everything the call
# would write. Without jq, or on input it cannot read, the raw text
# stands in for all of them, which can only over-block.
TOOL=""
if command -v jq >/dev/null 2>&1; then
  PARSED=$(printf '%s' "$INPUT" | jq -r '
    .tool_name // "",
    (.tool_input.file_path // "" | gsub("\n"; " ")),
    ([.tool_input.command, .tool_input.content,
      .tool_input.new_string,
      (.tool_input.edits // [] | .[].new_string)]
     | map(strings) | join(" ") | gsub("\n"; " "))
    ' 2>/dev/null) || PARSED=""
  { IFS= read -r TOOL; IFS= read -r FILE; IFS= read -r NEW; } <<EOF
$PARSED
EOF
fi

if [ -z "$TOOL" ]; then
  printf '%s' "$TI" | grep -q "$RECORD_RE" && deny
  printf '%s' "$TI" | grep -Eiq "$SETTINGS_RE" || exit 0
  case "$TI" in *"$V"*) deny ;; esac
  any_holds_var && deny
  exit 0
fi

case "$TOOL" in
  Bash)
    printf '%s' "$NEW" | grep -q "$RECORD_RE" && deny
    printf '%s' "$NEW" | grep -Eiq "$SETTINGS_RE" || exit 0
    case "$NEW" in *"$V"*) deny ;; esac
    any_holds_var && deny ;;
  *)
    # Either separator: a native Windows path uses backslashes.
    B=${FILE##*[/\\]}
    case "$B" in guard-off-*) deny ;; esac
    printf '%s' "$B" | grep -Eiqx "$SETTINGS_RE" || exit 0
    case "$NEW" in *"$V"*) deny ;; esac
    case "$TOOL" in
      Write) ;;
      *) grep -qs "$V" "$FILE" && deny ;;
    esac ;;
esac
exit 0
