# tests/hooks/guard-mode/session-mode.sh — session-mode.sh. Sourced
# by tests/hooks/guard-mode.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- session-mode.sh -------------------------------------------
says() {
  out=$(sh "$2/.claude/hooks/session-mode.sh" 2>&1)
  case "$out" in
  *"$3"*) ok ;;
  *) bad "session-mode in $1 does not say: $3" ;;
  esac
}
says development "$DEV" "development checkout"
# A token in the origin URL never reaches the transcript.
git -C "$DEV" remote add origin https://alice:tok3n@git.example.com/team/fork.git
case "$(sh "$DEV/.claude/hooks/session-mode.sh")" in
*tok3n*) bad "session-mode printed the credentials in origin" ;;
*git.example.com/team/fork*) ok ;;
*) bad "session-mode did not name a non-GitHub origin" ;;
esac
git -C "$DEV" remote remove origin
says operations "$OPS" "operations checkout"
says worktree "$WT" "linked worktree"
says worktree "$WT" "how: rules/server-check-handoff.md"
says development "$DEV" "scripts/lab.sh exec <family>"
says worktree "$WT" "the SSH pipeline, FreeBSD or macOS"
case "$(sh "$OPS/.claude/hooks/session-mode.sh")" in
*lab.sh*) bad "session-mode named the lab in operations" ;;
*) ok ;;
esac
out=$(unset CLAUDE_ENV_FILE; sh "$DEV/.claude/hooks/session-mode.sh")
case "$out" in
*"no CLAUDE_ENV_FILE"*) ok ;;
*) bad "session-mode did not say that the shim is missing" ;;
esac
