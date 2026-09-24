#!/bin/sh
# dev-tools.sh — SessionStart hook: install the tools scripts/check.sh
# needs (mise.dev.toml: ShellCheck, actionlint, betterleaks) in a
# Claude Code cloud session, whose container starts without them and
# where a development session has no sudo to add them (guard-mode.sh).
# A workstation clone installs them once by hand (CONTRIBUTING.md →
# Setup), so this does nothing outside Claude Code on the web, and
# nothing in an operations checkout, which never runs the checks.
#
# It installs and nothing more. scripts/check.sh brings the tools
# onto PATH itself (`MISE_ENV=dev mise env`), so this hook never puts
# anything in front of the shim that session-mode.sh sets first.
#
# Where it cannot work — mise.run is not on the Trusted network
# access level's default allowlist — it does nothing, and
# scripts/check.sh fails as it always did, naming
# `bin/hostwarden-doctor --dev` for the install command.

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

ROOT="$(cd "${0%/*}/../.." && pwd -P)"
# shellcheck source=mode.sh
. "$ROOT/.claude/hooks/mode.sh"
cd "$ROOT" || exit 0

hostwarden_mode "$ROOT"
case "$HOSTWARDEN_MODE" in
development | worktree) ;;
*) exit 0 ;;
esac

# Renovate keeps this pin current (renovate.json) and holds each
# release back seven days, as it does every other tool; mise.run
# alone would install whatever was released an hour ago.
MISE_VERSION=v2026.9.10

MISE="$HOME/.local/bin/mise"
if ! [ -x "$MISE" ]; then
  if command -v mise >/dev/null 2>&1; then
    MISE=$(command -v mise)
  else
    # -k backs TERM with a KILL: a process stuck on an unreachable
    # host can outlive TERM alone, and the hook's own timeout would
    # then discard its output.
    MISE_VERSION=$MISE_VERSION timeout -k 5 30 \
      sh -c 'curl -fsSL https://mise.run | sh' >/dev/null 2>&1
  fi
fi
[ -x "$MISE" ] || exit 0

"$MISE" trust "$ROOT/mise.dev.toml" >/dev/null 2>&1
MISE_ENV=dev timeout -k 5 20 "$MISE" install >/dev/null 2>&1 || exit 0

# scripts/check.sh finds mise by name. The cloud image has
# ~/.local/bin on PATH already; where it does not, append it —
# appended, never prepended, so the shim stays first.
command -v mise >/dev/null 2>&1 && exit 0
[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0
LINE="export PATH=\"\$PATH:${MISE%/*}\""
grep -qxF "$LINE" "$CLAUDE_ENV_FILE" 2>/dev/null ||
  echo "$LINE" >> "$CLAUDE_ENV_FILE"
