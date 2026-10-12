#!/bin/sh
# dev-tools.sh — SessionStart hook: install the jq the hooks run and
# the tools scripts/check.sh needs (mise.toml: jq, ShellCheck;
# mise.dev.toml: actionlint, betterleaks, Node) in a
# Claude Code cloud session, whose container starts without them and
# where a development session has no sudo to add them (guard-mode.sh).
# A workstation clone installs them once by hand (CONTRIBUTING.md →
# Setup), so this does nothing outside Claude Code on the web, and
# nothing in an operations checkout, which never runs the checks.
#
# It installs, and leaves the cache of the jq's directory
# (lib/json.sh); nothing more. scripts/check.sh brings the tools
# onto PATH itself (`MISE_ENV=dev mise env`), so this hook never puts
# anything in front of the shim that session-mode.sh sets first.
#
# Where it cannot work — mise.run is not on the Trusted network
# access level's default allowlist — it does nothing, and
# scripts/check.sh fails as it always did, naming
# `bin/hostwarden-doctor --dev` for the install command.

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

ROOT="$(cd "${0%/*}/../.." && pwd -P)"
# shellcheck source=../../lib/mode.sh
. "$ROOT/lib/mode.sh"
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
# Only what the hooks and scripts/check.sh run, named as the files spell them
# (a short name would resolve to the registry's latest, not the
# pin): mise.toml also pins Python and the Ansible packages, which
# a development session never runs (the shim refuses the tools that
# reach a server) and which would not fit the hook's 90 seconds
# after the bootstrap.
# The jq the hooks run comes first and alone, a small download that
# the check tools' slowness must not take with it. session-mode.sh
# looked for it before this ran and found none in a fresh container;
# the hooks read the cache it leaves, which is written now.
timeout -k 5 20 "$MISE" install aqua:jqlang/jq >/dev/null 2>&1
# shellcheck source=../../lib/json.sh
. "$ROOT/lib/json.sh"
# mise may not be on the PATH yet; the tail below depends on that.
OLD_PATH=$PATH
PATH="${MISE%/*}:$PATH"
hostwarden_mise_bins "$ROOT"
PATH=$OLD_PATH
hostwarden_write_mise_jq "$ROOT"

MISE_ENV=dev timeout -k 5 20 "$MISE" install aqua:koalaman/shellcheck \
  aqua:rhysd/actionlint aqua:betterleaks/betterleaks node \
  >/dev/null 2>&1 || exit 0

# scripts/check.sh finds mise by name. The cloud image has
# ~/.local/bin on PATH already; where it does not, append it —
# appended, never prepended, so the shim stays first.
command -v mise >/dev/null 2>&1 && exit 0
[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0
LINE="export PATH=\"\$PATH:${MISE%/*}\""
grep -qxF "$LINE" "$CLAUDE_ENV_FILE" 2>/dev/null ||
  echo "$LINE" >> "$CLAUDE_ENV_FILE"
