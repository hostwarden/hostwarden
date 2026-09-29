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
# A recorded operations clone is named, in a worktree too where its
# main checkout has no workspace; a record of anything else is none.
mkdir -p "$XDG_CONFIG_HOME/hostwarden"
printf '%s\n' "$OPS" > "$XDG_CONFIG_HOME/hostwarden/operations-checkout"
says development "$DEV" "operations session in $OPS, the operations clone"
says worktree "$WT" "operations session in $OPS, the operations clone"
OWT="$TMP/opswt"
git -C "$OPS" worktree add --quiet -b feat/o "$OWT" 2>/dev/null
printf '%s\n' "$DEV" > "$XDG_CONFIG_HOME/hostwarden/operations-checkout"
says worktree "$OWT" "the main checkout, $OPS, if"
# The parts after this one find the operations checkout as it was.
git -C "$OPS" worktree remove --force "$OWT"
git -C "$OPS" branch --quiet -D feat/o
says development "$DEV" "a separate clone, set up once"
printf 'ops\n' > "$XDG_CONFIG_HOME/hostwarden/operations-checkout"
says development "$DEV" "a separate clone, set up once"
rm "$XDG_CONFIG_HOME/hostwarden/operations-checkout"
case "$(sh "$OPS/.claude/hooks/session-mode.sh")" in
*lab.sh*) bad "session-mode named the lab in operations" ;;
*) ok ;;
esac
out=$(unset CLAUDE_ENV_FILE; sh "$DEV/.claude/hooks/session-mode.sh")
case "$out" in
*"no CLAUDE_ENV_FILE"*) ok ;;
*) bad "session-mode did not say that the shim is missing" ;;
esac
