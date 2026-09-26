# guard-mode.d/read.sh — every field of the call, read once. Sourced
# by guard-mode.sh, in the order its GUARD_MODULES lists, into the
# one shell every module shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the modules after it

# Every field in one jq call, as shell assignments @sh has
# quoted. Without jq, sed reads the simple string fields — a
# JSON string without quotes or backslashes in it — and what it
# cannot read, the guard refuses rather than passes.
TOOL="" P="" WD="" CMD="" JQ=1
if command -v jq >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | jq -r '@sh "TOOL=\(.tool_name // "")
    P=\(.tool_input.file_path // .tool_input.notebook_path // "")
    WD=\(.cwd // "") CMD=\(.tool_input.command // "")"' 2>/dev/null)"
else
  JQ=
  TOOL=$(hook_field tool_name)
  P=$(hook_field file_path)
  [ -n "$P" ] || P=$(hook_field notebook_path)
  WD=$(hook_field cwd)
fi
