#!/bin/sh
# guard-settings.sh — PreToolUse hook (matcher: Bash|Edit|Write|MultiEdit).
#
# Keeps the model from switching the taboo guard off through a
# Claude Code settings file. guard-taboos.sh honours
# HOSTWARDEN_GUARD_DISABLE from its inherited environment, and the
# `env` key of any settings.json feeds that environment — reloaded
# mid-session, without a relaunch. JSON spells the variable without
# an equals sign, so the guard's own inline-assignment rule never
# sees it, and the guard does not see Edit or Write at all.
#
# Denies:
#   - an Edit, Write or MultiEdit whose target is a settings file
#     and whose NEW text names the variable. Taking it out again is
#     an edit whose new text does not, so the clean-up passes.
#   - a Bash command that names both the variable and a settings
#     file. That cannot tell a read from a write, so a grep of the
#     two together is denied too; grep one of them at a time.
#   - while a settings file already carries the variable: an Edit
#     of that file that does not take it out, and any Bash command
#     that names a settings file. Either could flip the value
#     without naming the variable at all.
#
# The operator sets it by hand in an editor, which reaches no hook.
# README → Claude Code Desktop describes that.
#
# Deliberately NOT honouring HOSTWARDEN_GUARD_DISABLE, and a hook of
# its own for that reason: guard-taboos.sh exits at once when the
# guard is off, and a guard that is off for one session must not let
# the model make it off for every session after.
#
# Boundary, as for the guard: a backstop against the everyday
# mistake, not a sandbox. A file written elsewhere and copied into
# place, or a JSON \u escape, defeats any string matcher. The
# session-start notice from check-session.sh is what tells the
# operator the guard is off, whichever way it happened.

INPUT=$(cat)

V=HOSTWARDEN_GUARD_DISABLE

# Nearly every call names neither the variable nor a settings file;
# one case, no fork.
case "$INPUT" in
  *"$V"*|*settings.json*|*settings.local.json*) ;;
  *) exit 0 ;;
esac

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
  printf '"permissionDecision":"deny",'
  printf '"permissionDecisionReason":"hostwarden guard: '
  printf 'HOSTWARDEN_GUARD_DISABLE in a Claude Code settings file '
  printf 'switches the taboo guard off, and only the operator may '
  printf 'set or change it, by hand (AGENTS.md - Critical Safety '
  printf 'Rules). Blocked in all permission modes. Explain this to the '
  printf 'user; do not look for another way to write it. README - '
  printf 'Claude Code Desktop describes what the operator does."}}\n'
  exit 0
}

SETTINGS_RE='settings(\.local)?\.json|managed-settings\.json'

# holds_var <file> — the file already carries the variable. Then a
# change that does not name it can still flip its value ("0" to
# "1"), so only its removal may pass.
holds_var() { [ -f "$1" ] && grep -q "$V" "$1" 2>/dev/null; }

# The settings files a shell command can reach by a relative or
# short path; the managed ones need root and are left to the Edit
# branch, which sees the full path.
PROJECT=${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}
any_holds_var() {
  for f in "$PROJECT/.claude/settings.local.json" \
           "$PROJECT/.claude/settings.json" \
           "$HOME/.claude/settings.local.json" \
           "$HOME/.claude/settings.json"; do
    holds_var "$f" && return 0
  done
  return 1
}

# One jq call, four lines: tool, target, everything the call would
# write, everything it would replace. Without jq, or on input it
# cannot read, the raw text is judged as a whole, which can only
# over-block.
TOOL=""
if command -v jq >/dev/null 2>&1; then
  PARSED=$(printf '%s' "$INPUT" | jq -r '
    .tool_name // "",
    .tool_input.file_path // "",
    ([.tool_input.command, .tool_input.content,
      .tool_input.new_string,
      (.tool_input.edits // [] | .[].new_string)]
     | map(strings) | join(" ") | gsub("\n"; " ")),
    ([.tool_input.old_string,
      (.tool_input.edits // [] | .[].old_string)]
     | map(strings) | join(" ") | gsub("\n"; " "))' 2>/dev/null) \
    || PARSED=""
  TOOL=$(printf '%s\n' "$PARSED" | sed -n 1p)
  FILE=$(printf '%s\n' "$PARSED" | sed -n 2p)
  NEW=$(printf '%s\n' "$PARSED" | sed -n 3p)
  OLD=$(printf '%s\n' "$PARSED" | sed -n 4p)
fi

if [ -z "$TOOL" ]; then
  printf '%s' "$INPUT" | grep -Eq "$SETTINGS_RE" || exit 0
  case "$INPUT" in *"$V"*) deny ;; esac
  any_holds_var && deny
  exit 0
fi

case "$TOOL" in
  Bash)
    printf '%s' "$NEW" | grep -Eq "$SETTINGS_RE" || exit 0
    case "$NEW" in *"$V"*) deny ;; esac
    any_holds_var && deny ;;
  *)
    printf '%s' "${FILE##*/}" | grep -Eqx "$SETTINGS_RE" || exit 0
    case "$NEW" in *"$V"*) deny ;; esac
    # Already set: a Write that leaves it out, or an Edit that
    # replaces text naming it, takes it out. Anything else may be
    # the value-only flip.
    if holds_var "$FILE"; then
      case "$TOOL" in
        Write) ;;
        *) case "$OLD" in *"$V"*) ;; *) deny ;; esac ;;
      esac
    fi ;;
esac
exit 0
