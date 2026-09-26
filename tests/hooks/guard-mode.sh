#!/bin/sh
# tests/hooks/guard-mode.sh — dev-only fixture matrix for mode.sh,
# guard-mode.sh, session-mode.sh, bin/hostwarden-init,
# bin/hostwarden-sync, bin/hostwarden-ssh-config and
# scripts/lab.sh. CI runs it through
# scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks), except while building a
# guard patch in a scratch clone. Not invoked by Claude Code at
# runtime.
#
# Each mode gets a throwaway checkout of its own under a temp
# directory, because the mode is a property of the tree the hook
# sits in: the guard finds its root from its own path.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS="$REPO/.claude/hooks"

# bash_json <command> [tool] — for Bash, or the tool named.
bash_json() {
  printf '%s' "$1" | jq -Rs --arg t "${2:-Bash}" '{tool_name:$t,tool_input:{command:.}}'
}

# Child of drain below, judging a batch of queued hook fixtures:
# four arguments each, the expectation, the checkout, the tool (or
# JSON) and the command (or the whole input). One line per fixture,
# ok or FAIL. It exits before anything below runs, or each child
# would build the checkouts again.
if [ "${1:-}" = --verdict ]; then
  shift
  while [ $# -ge 4 ]; do
    in=$4
    [ "$3" = JSON ] || in=$(bash_json "$4" "$3")
    out=$(printf '%s' "$in" | sh "$2/.claude/hooks/guard-mode.sh")
    case "$out" in
    *'"permissionDecision":"deny"'*) got=deny ;;
    *) got=pass ;;
    esac
    if [ "$got" = "$1" ]; then echo ok
    else echo "FAIL: [$1, got $got] ${2##*/}: $in"
    fi
    shift 4
  done
  [ $# -eq 0 ] || echo "FAIL: a batch ended mid-fixture ($# arguments left)"
  exit 0
fi
SELF="$REPO/tests/hooks/${0##*/}"
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp mode
# Run inside a Claude Code session, session-mode.sh would write to
# that session's own env file, and every call carries what that
# file set: the shim first on PATH and git-ssh.sh as
# GIT_SSH_COMMAND. The cases build that environment themselves, so
# they start from one without it, as in CI.
unset CLAUDE_ENV_FILE GIT_SSH_COMMAND GIT_SSH HOSTWARDEN_GIT_SSH_COMMAND
PATH=$(printf %s "$PATH" | tr : '\n' | grep -v '/\.claude/hooks/shim$' |
  paste -sd: -)
export PATH

# fails <message> <command...> — the command must fail.
fails() { m=$1; shift; if "$@" >/dev/null 2>&1; then bad "$m"; else ok; fi; }
# has <text> <needle> <message> — the text contains the needle.
has() { case "$1" in *"$2"*) ok ;; *) bad "$3: $1" ;; esac; }

# commit <dir> <message> — as alice, whatever git is configured.
commit() {
  git -C "$1" add -A
  git -C "$1" -c user.name=alice -c user.email=alice@example.com \
    commit --quiet -m "$2"
}

# checkout <name> — a minimal tree: the hooks, the init script
# with its workspace skeleton, and a .gitignore like the real one.
checkout() {
  c="$TMP/$1"
  mkdir -p "$c/.claude/hooks" "$c/bin" "$c/lib" "$c/scripts" "$c/rules"
  cp "$HOOKS/guard-mode.sh" "$HOOKS/session-mode.sh" "$HOOKS/shim.sh" \
    "$HOOKS/git-ssh.sh" "$c/.claude/hooks/"
  cp -R "$HOOKS/shim" "$c/.claude/hooks/"
  cp "$REPO/lib/mode.sh" "$REPO/lib/json.sh" "$c/lib/"
  cp "$REPO/bin/hostwarden-init" "$REPO/bin/hostwarden-sync" \
    "$REPO/bin/hostwarden-ssh-config" "$REPO/bin/hostwarden-backup" \
    "$c/bin/"
  cp "$REPO/scripts/lab.sh" "$c/scripts/"
  mkdir -p "$c/templates"
  cp -R "$REPO/templates/workspace" "$c/templates/"
  printf 'memory/\n.claude/settings.local.json\n' > "$c/.gitignore"
  echo '# rule' > "$c/rules/backups.md"
  git -C "$c" init --quiet
  commit "$c" init
  (cd "$c" && pwd -P)
}

DEV=$(checkout dev)
OPS=$(checkout ops)
sh "$OPS/bin/hostwarden-init" >/dev/null
# A worktree checks out the committed hooks, so it needs nothing
# copied in.
WT="$TMP/wt"
git -C "$DEV" worktree add --quiet -b feat/x "$WT" 2>/dev/null

# --- mode.sh ---------------------------------------------------
mode_is() {
  # shellcheck source=../../lib/mode.sh
  got=$(. "$REPO/lib/mode.sh"; hostwarden_mode "$2"; echo "$HOSTWARDEN_MODE")
  if [ "$got" = "$1" ]; then ok; else bad "mode of $2: want $1, got $got"; fi
}
mode_is development "$DEV"
mode_is operations "$OPS"
mode_is worktree "$WT"
# An archive copy, not a clone: never operations, even with a
# workspace in it, and init refuses to make one.
ARC="$TMP/archive"
mkdir -p "$ARC/memory"
cp -R "$DEV/.claude" "$DEV/bin" "$DEV/lib" "$DEV/templates" "$ARC/"
cp "$OPS/memory/.hostwarden-workspace" "$ARC/memory/"
mode_is development "$ARC"
rm "$ARC/memory/.hostwarden-workspace"
fails "init made a workspace outside a git clone" sh "$ARC/bin/hostwarden-init"

# --- guard-mode.sh ---------------------------------------------
edit_json() {
  jq -n --arg p "$1" \
    '{tool_name:"Edit",tool_input:{file_path:$p,old_string:"ssh a",new_string:"ssh b"}}'
}
write_json() {
  jq -n --arg p "$1" '{tool_name:"Write",tool_input:{file_path:$p,content:"x"}}'
}

# Hook fixtures are queued, not run: each is an independent call of
# the hook, and one after the other they took ~24 s. drain runs the
# queue in parallel batches. A fixture that depends on a file the
# test changes later is drained before the change.
QUEUE="$TMP/queue"
: > "$QUEUE"
NQ=0
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
# queue <expect> <checkout> <tool or JSON> <command or input> —
# none of them empty: BSD xargs drops an empty field, and the count
# in drain then fails.
queue() {
  printf '%s\0%s\0%s\0%s\0' "$1" "$2" "$3" "$4" >> "$QUEUE"
  NQ=$((NQ + 1))
}
drain() {
  [ "$NQ" -gt 0 ] || return 0
  res=$(xargs -0 -n 100 -P "$JOBS" sh "$SELF" --verdict < "$QUEUE")
  dn=$(printf '%s\n' "$res" | grep -c '^ok$')
  df=$(printf '%s\n' "$res" | grep -c '^FAIL: ')
  PASS=$((PASS + dn))
  FAIL=$((FAIL + df))
  [ "$df" -eq 0 ] || printf '%s\n' "$res" | grep -v '^ok$'
  [ $((dn + df)) -eq "$NQ" ] \
    || bad "$NQ fixtures queued, only $((dn + df)) judged"
  : > "$QUEUE"
  NQ=0
}
# verdict <expect> <checkout> <json>
verdict() { queue "$1" "$2" JSON "$3"; }
cmd() { queue "$1" "$2" Bash "$3"; }
edit() { verdict "$1" "$2" "$(edit_json "$3")"; }
write() { verdict "$1" "$2" "$(write_json "$3")"; }

# The rest lives in tests/hooks/guard-mode/, one file per stage,
# sourced in this order into this shell: each reads what the ones
# before it set.
PARTS='development monitor containers operations session-mode shim
init sync backup-lab'
for part in $PARTS; do
  [ -f "$REPO/tests/hooks/guard-mode/$part.sh" ] || {
    echo "${0##*/}: tests/hooks/guard-mode/$part.sh is missing" >&2
    exit 1
  }
done
for part in $PARTS; do
  # shellcheck source=/dev/null
  . "$REPO/tests/hooks/guard-mode/$part.sh"
done

finish guard-mode
