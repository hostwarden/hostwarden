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

# Nearly every call never names the variable; one case, no fork.
case "$INPUT" in
  *HOSTWARDEN_GUARD_DISABLE*) ;;
  *) exit 0 ;;
esac

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
  printf '"permissionDecision":"deny",'
  printf '"permissionDecisionReason":"hostwarden guard: '
  printf 'HOSTWARDEN_GUARD_DISABLE in a Claude Code settings file '
  printf 'switches the taboo guard off, and only the operator may do '
  printf 'that, by hand (AGENTS.md - Critical Safety Rules). Blocked in '
  printf 'all permission modes. Explain this to the user; do not look '
  printf 'for another way to write it. README - Claude Code Desktop '
  printf 'describes what the operator does."}}\n'
  exit 0
}

SETTINGS_RE='settings(\.local)?\.json|managed-settings\.json'

# One jq call, three fields on separate lines: tool, target, and
# everything the call would write. Without jq, or on input it cannot
# read, the raw text stands in for all of them — that also counts an
# old_string that merely removes the name, so it can only over-block.
TOOL=""
if command -v jq >/dev/null 2>&1; then
  PARSED=$(printf '%s' "$INPUT" | jq -r '
    .tool_name // "",
    .tool_input.file_path // "",
    ([.tool_input.command, .tool_input.content,
      .tool_input.new_string,
      (.tool_input.edits // [] | .[].new_string)]
     | map(strings) | join(" "))' 2>/dev/null) || PARSED=""
  TOOL=$(printf '%s\n' "$PARSED" | sed -n 1p)
  FILE=$(printf '%s\n' "$PARSED" | sed -n 2p)
  NEW=$(printf '%s\n' "$PARSED" | sed -n '3,$p')
fi

if [ -z "$TOOL" ]; then
  printf '%s' "$INPUT" | grep -Eq "$SETTINGS_RE" && deny
  exit 0
fi

case "$NEW" in
  *HOSTWARDEN_GUARD_DISABLE*) ;;
  *) exit 0 ;;
esac

case "$TOOL" in
  Bash)
    printf '%s' "$NEW" | grep -Eq "$SETTINGS_RE" && deny ;;
  *)
    printf '%s' "${FILE##*/}" | grep -Eqx "$SETTINGS_RE" && deny ;;
esac
exit 0
