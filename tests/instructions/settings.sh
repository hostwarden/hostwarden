# tests/instructions/settings.sh — the hooks settings.json
# registers, and the tools each guard sees. Sourced by
# tests/instructions.sh, in its order, into the one shell every part
# shares; never run on its own.
# shellcheck shell=sh

# --- every registered hook starts, and starts the right file -----
# A hook that cannot start fails open, the taboo guard included.
# So every command is `sh "$CLAUDE_PROJECT_DIR/<existing file>"`
# with plain arguments at most -- not bash (exit 127 when it is
# missing), not a relative path (breaks after a cd, #2), nothing
# chained -- or the one mkdir, matched whole: a prefix would let
# `mkdir … && bash …` through.
NHOOKS=0 GUARD=''
while IFS= read -r c; do
  [ -n "$c" ] || continue
  NHOOKS=$((NHOOKS + 1))
  case $c in
    'mkdir -p -m 700 \"$HOME/.cache/hostwarden\"') ok; continue ;;
    'sh \"$CLAUDE_PROJECT_DIR/'*) ;;
    *) bad "settings.json starts a hook as: $c"; continue ;;
  esac
  h=${c#*CLAUDE_PROJECT_DIR/}
  h=${h%%\\\"*}
  # After the script, plain arguments only: `; bash …` or `&& …`
  # would start a second command the checks above never see.
  case ${c#*"$h"\\\"} in
    *[!a-z0-9\ -]*)
      bad "settings.json runs more than $h: $c"
      continue ;;
  esac
  [ "$h" = .claude/hooks/guard-taboos.sh ] && GUARD=1
  if [ -f "$ROOT/$h" ]; then
    ok
  else
    bad "settings.json registers $h, which does not exist"
  fi
done <<EOF
$(sed -n 's/^ *"command": *"\(.*\)",\{0,1\} *$/\1/p' "$CLAUDE_DIR/settings.json")
EOF
if [ "$NHOOKS" -eq 0 ]; then
  bad "settings.json registers no hook script -- either the" \
      "guard is gone or this check stopped matching"
fi
# Sound hooks say nothing about whether the guard is among them.
if [ -n "$GUARD" ]; then
  ok
else
  bad "settings.json no longer registers the taboo guard"
fi

# --- every tool that runs a command is guarded or denied ----------
# A hook matches by tool name. Monitor runs shell commands just as
# Bash does, and a matcher that names only Bash let a taboo through
# it with no guard in the way. So each tool known to run a command
# is either in the matcher of every guard that reads commands, or
# denied outright by its bare name in permissions.deny. A new such
# tool in Claude Code belongs on this list.
# One jq prints "<tool> <guard>" for every gap.
if command -v jq >/dev/null 2>&1; then
  GAPS=$(jq -r '
    . as $s
    | ("Bash", "Monitor", "PowerShell") as $t
    | select($s.permissions.deny // [] | any(. == $t) | not)
    | ("guard-taboos.sh", "guard-settings.sh", "guard-mode.sh") as $g
    | select([$s.hooks.PreToolUse[]?
        | select(any(.hooks[]?;
            .command | endswith("/.claude/hooks/" + $g + "\"")))
        | .matcher // "*"
        # No matcher, "" or "*" matches every tool.
        | if . == "*" or . == "" then $t
          else split("[|,]"; null)[] | gsub("^ +| +$"; "") end]
      | any(. == $t) | not)
    | "\($t) \($g)"' "$CLAUDE_DIR/settings.json") \
    || bad "jq could not read settings.json"
  while read -r t g; do
    [ -n "$t" ] || continue
    bad "settings.json lets $t run commands past $g: add it" \
        "to that hook's matcher, or deny \"$t\" outright"
  done <<EOF
$GAPS
EOF
  [ -n "$GAPS" ] || ok
else
  bad "jq is missing, so the guard matchers cannot be checked"
fi
