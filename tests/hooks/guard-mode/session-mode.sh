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
# Remote: the way out is Claude Code on the workstation, and no lab.
if [ -r /proc/sys/kernel/osrelease ]; then
  out=$(CLAUDE_CODE_REMOTE=true sh "$OPS/.claude/hooks/session-mode.sh" 2>&1)
  case "$out" in
  *"VM apart from the workstation"*) ok ;;
  *) bad "session-mode in remote does not name the VM: $out" ;;
  esac
  case "$out" in
  *"Claude Code on the workstation"*) ok ;;
  *) bad "session-mode in remote does not name the way out: $out" ;;
  esac
  case "$out" in
  *lab.sh*) bad "session-mode named the lab in remote" ;;
  *) ok ;;
  esac
fi
out=$(unset CLAUDE_ENV_FILE; sh "$DEV/.claude/hooks/session-mode.sh")
case "$out" in
*"no CLAUDE_ENV_FILE"*) ok ;;
*) bad "session-mode did not say that the shim is missing" ;;
esac
# In operations the tools mise.toml pins go first on the PATH of
# every Bash call, one line however often the hook runs and
# replaced when mise's answer changed; in development the shim's
# PATH carries nothing of them. Only where mise is installed and has
# put something there.
if command -v mise >/dev/null 2>&1 \
   && [ -n "$(cd "$OPS" && mise bin-paths 2>/dev/null)" ]; then
  e="$TMP/mise-env"
  : > "$e"
  for i in 1 2; do
    CLAUDE_ENV_FILE="$e" sh "$OPS/.claude/hooks/session-mode.sh" </dev/null >/dev/null
  done
  n=$(grep -c '# mise.toml$' "$e")
  if [ "$n" -eq 1 ] && grep -q "esac # mise.toml$" "$e"; then
    ok
  else
    bad "session-mode wrote the mise line $n times in operations"
  fi
  # Sourced twice, the line prepends once.
  # shellcheck source=/dev/null
  p1=$(PATH=/usr/bin:/bin; . "$e"; echo "$PATH")
  # shellcheck source=/dev/null
  p2=$(PATH=/usr/bin:/bin; . "$e"; . "$e"; echo "$PATH")
  if [ "$p1" = "$p2" ] && [ "$p1" != /usr/bin:/bin ]; then
    ok
  else
    bad "session-mode's mise line is not idempotent: $p2"
  fi
  # In mise's order: the first tool's directory stays first, the
  # pinned ansible-core before the one inside ansible-lint's.
  want=$(cd "$OPS" && mise bin-paths | tr '\n' ':')
  case $p1 in
  "$want"*) ok ;;
  *) bad "session-mode's mise line reordered the directories: $p1" ;;
  esac
  # A PATH that came with any one of the directories, from a shell
  # mise was activated in, still gets the whole list in front, in
  # mise's order.
  for d in $(cd "$OPS" && mise bin-paths); do
    # shellcheck source=/dev/null
    p3=$(PATH="$d:/usr/bin:/bin"; . "$e"; echo "$PATH")
    case $p3 in
    "$want"*) ok ;;
    *) bad "session-mode's mise line kept $d out of order: $p3" ;;
    esac
  done
  # A line from before mise installed more, or a pin was raised, is
  # replaced and the rest of the file stays.
  { echo 'export HOSTWARDEN_SESSION=s1'
    echo "export PATH='/nonexistent/old':\"\$PATH\" # mise.toml"; } > "$e"
  CLAUDE_ENV_FILE="$e" sh "$OPS/.claude/hooks/session-mode.sh" </dev/null >/dev/null
  if [ "$(grep -c '# mise.toml$' "$e")" -eq 1 ] && ! grep -q nonexistent "$e" \
     && grep -q '^export HOSTWARDEN_SESSION=s1$' "$e"; then
    ok
  else
    bad "session-mode did not replace the stale mise line"
  fi
  : > "$e"
  CLAUDE_ENV_FILE="$e" sh "$DEV/.claude/hooks/session-mode.sh" </dev/null >/dev/null
  if grep -q '# mise.toml$' "$e"; then
    bad "session-mode wrote the mise line in development"
  else
    ok
  fi
fi
