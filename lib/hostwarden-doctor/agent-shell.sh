# shellcheck shell=sh
# hostwarden-doctor, sourced: the shell Claude Code runs an agent's
# commands in. Reads has, row, miss and hint, and ROOT.
#
# Agents write Bash, and zsh, macOS's login shell, breaks it: a
# glob that matches nothing aborts the command, an unquoted
# variable is not split, arrays count from 1. macOS's own
# /bin/bash is 3.2, without mapfile, declare -A or ${v,,}. Only
# where Claude Code is set up; another tool picks its shell itself.

CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-$HOME/.claude}

# bash_new <path> — a Bash 4 or newer. Never given a zsh, which
# would read the user's ~/.zshenv first.
bash_new() {
  [ -x "$1" ] || return 1
  # shellcheck disable=SC2016 # that bash expands it, not this sh
  "$1" -c '[ "${BASH_VERSINFO[0]}" -ge 4 ]' >/dev/null 2>&1
}

# settings_shell — sets SH_VALUE and SH_FILE to the CLAUDE_CODE_SHELL
# of the settings file that wins: managed, local, project, user.
# A settings value wins over the shell's own, and a run by hand in a
# terminal sees only the shell's, so the files are read here: with
# jq where there is one, else as text joined to one line, since the
# key and its value may sit on lines of their own. Quiet: the shim
# test runs the doctor on a PATH without either
# (tests/hooks/guard-mode/shim.sh).
settings_shell() {
  SH_VALUE='' SH_FILE=''
  for f in "/Library/Application Support/ClaudeCode/managed-settings.json" \
    /etc/claude-code/managed-settings.json \
    "$ROOT/.claude/settings.local.json" "$ROOT/.claude/settings.json" \
    "$CLAUDE_DIR/settings.json"; do
    [ -f "$f" ] || continue
    if has jq; then
      SH_VALUE=$(jq -r '.env.CLAUDE_CODE_SHELL // empty' "$f" 2>/dev/null)
    else
      SH_VALUE=$({ tr '\n' ' ' < "$f" | sed -n \
        's/.*"CLAUDE_CODE_SHELL"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
      } 2>/dev/null)
    fi
    [ -z "$SH_VALUE" ] || { SH_FILE=$f; return; }
  done
}

# agent_shell — the shell Claude Code picks: CLAUDE_CODE_SHELL where
# it names a bash or zsh that runs, else the login shell where it
# is one of the two, else the first zsh, then bash, it finds on
# PATH or where systems install them. Empty where there is none.
agent_shell() {
  for s in "${SH_VALUE:-$CLAUDE_CODE_SHELL}" "$SHELL" \
    "$(command -v zsh)" /bin/zsh /usr/bin/zsh \
    "$(command -v bash)" /bin/bash /usr/bin/bash; do
    case $s in *bash*|*zsh*) [ -x "$s" ] && { echo "$s"; return; } ;; esac
  done
}

if [ -n "$CLAUDECODE" ] || [ -d "$CLAUDE_DIR" ]; then
  [ -n "$QUIET" ] || echo "Agent shell"
  settings_shell
  AGENT_SH=$(agent_shell)
  label="Claude Code's shell is Bash 4 or newer"
  case $AGENT_SH in *zsh*) ok='' ;; *) ok=1 ;; esac
  if [ -n "$ok" ] && bash_new "$AGENT_SH"; then
    row "ok       $label"
  else
    row "missing  $label"
    # Looked for only here: each candidate costs a process.
    NEW_SH=''
    for b in "$(command -v bash)" /opt/homebrew/bin/bash \
      /usr/local/bin/bash; do
      bash_new "$b" && { NEW_SH=$b; break; }
    done
    miss shell "$label" "it is ${AGENT_SH:-none}; set CLAUDE_CODE_SHELL under \
env in ${SH_FILE:-$CLAUDE_DIR/settings.json} to \
${NEW_SH:-a Bash 4 or newer — $(hint bash)}"
  fi
fi
