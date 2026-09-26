#!/bin/sh
# tests/hooks/guard-taboos.sh — dev-only fixture matrix for
# .claude/hooks/guard-taboos.sh and its modules in guard-taboos.d/.
# CI runs it through scripts/check.sh; an agent session leaves it to
# CI, except while building a guard patch in a scratch clone
# (.claude/rules/pull-requests.md → Checks). The fixtures live in
# tests/hooks/guard-taboos/, one file per effect.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CLAUDE_DIR="$REPO/.claude"
# The skills live here. .claude/skills is a link to it, but
# the real path is the one thing every tool agrees on.
# shellcheck disable=SC2034 # read by the fixture parts
SKILLS_DIR="$REPO/.agents/skills"
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"

# The guard picks its scope from the checkout it sits in (the
# header of guard-taboos.sh), and this matrix runs in a development
# checkout or a worktree. So it judges copies: one in a tree that
# is an operations checkout by mode.sh's own test, for the full
# scope, and one in a plain directory, for the local one. A
# --verdict child inherits both through the environment.
if [ -z "${GUARD_OPS:-}" ]; then
  GUARD_TREES=$(mktemp -d)
  for t in ops dev; do
    mkdir -p "$GUARD_TREES/$t/.claude/hooks" "$GUARD_TREES/$t/lib"
    cp "$CLAUDE_DIR/hooks/guard-taboos.sh" "$GUARD_TREES/$t/.claude/hooks/"
    cp -R "$CLAUDE_DIR/hooks/guard-taboos.d" "$GUARD_TREES/$t/.claude/hooks/"
    cp "$REPO/lib/mode.sh" "$REPO/lib/json.sh" "$GUARD_TREES/$t/lib/"
  done
  mkdir -p "$GUARD_TREES/ops/.git" "$GUARD_TREES/ops/memory"
  : > "$GUARD_TREES/ops/memory/.hostwarden-workspace"
  GUARD_OPS="$GUARD_TREES/ops/.claude/hooks/guard-taboos.sh"
  GUARD_DEV="$GUARD_TREES/dev/.claude/hooks/guard-taboos.sh"
  export GUARD_OPS GUARD_DEV
fi
HOOK=$GUARD_OPS

json_for() {
  # json_for <command> [tool] [mode] — a raw command string as
  # PreToolUse hook input for Bash, or for the tool named, in the
  # permission mode given, or none. The tool JSON takes the first
  # argument as the whole hook input already.
  if [ "${2:-}" = JSON ]; then
    printf '%s' "$1"
  elif command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -cRs --arg t "${2:-Bash}" --arg m "${3:-}" \
      '{tool_name:$t,tool_input:{command:.}}
       + (if $m == "" then {} else {permission_mode:$m} end)'
  else
    printf '%s' "$1" | python3 -c 'import json,sys; \
d={"tool_name":sys.argv[1],"tool_input":{"command":sys.stdin.read()}}; \
d.update({"permission_mode":sys.argv[2]} if sys.argv[2] else {}); \
print(json.dumps(d))' "${2:-Bash}" "${3:-}"
  fi
}

# Whether a guard's output is a deny. verdict below and hook_case
# further down both judge by it.
denied() { case "$1" in *'"permissionDecision":"deny"'*) true ;; *) false ;; esac; }
# The guard's second tier: a prompt the user answers, for a guest
# stopped or deleted (guard-taboos.sh -> Guest stop and delete).
asked() { case "$1" in *'"permissionDecision":"ask"'*) true ;; *) false ;; esac; }

verdict() {
  # verdict <expect> <tool> <command> <hook> <input> [label] — one
  # fixture, one line of output, in the queue's own field order.
  # Runs no process but the guard itself: every fork and exec here
  # is paid once per fixture, and on a workstation with an EDR agent
  # each one is also inspected. HOSTWARDEN_GUARD_DISABLE is unset by
  # the caller, once.
  OUT=$(sh "$4" <<EOF
$5
EOF
)
  if denied "$OUT"; then GOT=deny
  elif asked "$OUT"; then GOT=ask
  else GOT=pass
  fi
  # A decision Claude Code cannot parse is no decision at all: a
  # reason with a backslash in it once broke the JSON unnoticed.
  # The drain validates every deny and every ask it gets back, all
  # in one jq run.
  case "$GOT:$1" in
  deny:deny|ask:ask) printf '%s:%s\n' "$GOT" "$OUT" ;;
  pass:pass) echo ok ;;
  *)
    case $2 in
    Bash) echo "FAIL [$1, got $GOT]$6: $3" ;;
    *) echo "FAIL [$1, got $GOT] $2$6: $3" ;;
    esac ;;
  esac
}

# Child of the parallel drain at the bottom, judging a batch of
# fixtures. Everything it needs is defined above; it must exit
# before the fixtures below, or each child would queue the whole
# matrix again.
# Each fixture is four arguments: expectation, tool, command, and
# the hook input the drain built from them (a dash without jq).
# An expectation with a dev- prefix is judged by the copy in the
# development tree (check_dev below).
if [ "$1" = "--verdict" ]; then
  shift
  unset HOSTWARDEN_GUARD_DISABLE
  while [ $# -ge 4 ]; do
    IN=$4
    [ "$IN" != - ] || IN=$(json_for "$3" "$2")
    case $1 in
    dev-*) verdict "${1#dev-}" "$2" "$3" "$GUARD_DEV" "$IN" \
      ' in development' ;;
    *) verdict "$1" "$2" "$3" "$HOOK" "$IN" ;;
    esac
    shift 4
  done
  # A batch cut short mid-fixture would misread every fixture after
  # the cut; it fails the run instead.
  [ $# -eq 0 ] || echo "FAIL: a batch ended mid-fixture ($# arguments left)"
  exit 0
fi

SELF="$REPO/tests/hooks/$(basename "$0")"
QUEUE=$(mktemp)
trap 'rm -rf "$QUEUE" "$QUEUE.in" "$GUARD_TREES"' EXIT INT TERM
NCHECKS=0
# One core is the floor, not the default: a machine that will not
# say how many it has still runs the matrix, just no faster. Off
# CI, half the cores is the ceiling: on a workstation, other
# sessions and endpoint protection inspecting every process need the
# rest.
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
[ -n "${CI:-}" ] || JOBS=$((JOBS / 2))
[ "$JOBS" -ge 1 ] || JOBS=1

check() {
  # Queued, not run. Every fixture is an independent invocation of
  # the guard costing ~80 ms, and nothing in one depends on
  # another, so running them one after the other spent ~55 s to
  # learn what ~13 s answers. A check that slow is a check people
  # stop running before they commit.
  # check <expect> <command> [tool] — Bash unless a tool is named.
  printf '%s\0%s\0%s\0' "$1" "${3:-Bash}" "$2" >> "$QUEUE"
  NCHECKS=$((NCHECKS + 1))
}

check_mode() {
  # check_mode <expect> <permission mode> <command> -- a Bash call
  # in that mode. check alone sends no mode at all.
  check "$1" "$(json_for "$3" Bash "$2")" JSON
}

# The fixtures, one file per effect, in this order. Each queues its
# checks with check or check_mode; a few judge the hook directly.
for part in block guests first-boot storage ssh-keys windows pass instruction-blocks pass-ssh sshd heredoc override edit session development; do
  # shellcheck source=/dev/null
  . "$REPO/tests/hooks/guard-taboos/$part.sh"
done

# --- drain the queued fixtures ---------------------------------
# Failures are sorted rather than printed as they land, so two
# runs of the same broken tree read the same.
if [ "$NCHECKS" -gt 0 ]; then
  # One jq run builds every fixture's hook input, so no child
  # starts one: four fields per fixture from here on.
  # Without jq the fourth is a dash and the child falls back to
  # json_for. Not an empty field: BSD xargs drops those. printf
  # repeats its format, so one takes a hundred fixtures.
  if command -v jq >/dev/null 2>&1; then
    jq -Rsj '([0] | implode) as $nul | split($nul)[:-1] | _nwise(3)
      | (.[0], .[1], .[2],
         if .[1] == "JSON" then .[2]
         else {tool_name: .[1], tool_input: {command: .[2]}} | tojson
         end) + $nul' < "$QUEUE" > "$QUEUE.in"
  else
    xargs -0 -n 300 printf '%s\0%s\0%s\0-\0' < "$QUEUE" > "$QUEUE.in"
  fi
  # Batches of 25, not one child per fixture: each child is a shell
  # that parses this file. 25 keeps a batch far below GNU xargs'
  # 128 KiB command buffer (under 30 KB today, the longest fenced
  # blocks included) and still gives every core several batches. A
  # batch that xargs cuts at that limit anyway fails in the child,
  # which counts what is left over. (BSD xargs -x would say so
  # itself, but with -0 it hands over one argument per call.)
  RESULT=$(xargs -0 -n 100 -P "$JOBS" sh "$SELF" --verdict \
    < "$QUEUE.in")
  XSTATUS=$?
  # Every deny that came back is valid JSON Claude Code reads as a
  # deny, or a failure: one jq run turns each deny: line into ok or
  # a FAIL line. Without jq the JSON cannot be checked.
  if command -v jq >/dev/null 2>&1; then
    RESULT=$(printf '%s\n' "$RESULT" | jq -Rr '
      if startswith("deny:") or startswith("ask:")
      then (index(":")) as $i | .[:$i] as $d | .[$i+1:] as $j
        | if ($j | try (fromjson
              | .hookSpecificOutput.permissionDecision == $d)
            catch false)
          then "ok"
          else "FAIL [\($d), got \($d) as invalid JSON]: \($j)" end
      else . end')
  else
    RESULT=$(printf '%s\n' "$RESULT" | sed -e 's/^deny:.*/ok/' \
      -e 's/^ask:.*/ok/')
  fi
  NGOT=$(printf '%s\n' "$RESULT" | grep -c . || true)
  NOK=$(printf '%s\n' "$RESULT" | grep -c '^ok$' || true)
  PASS=$((PASS + NOK))
  BADS=$(printf '%s\n' "$RESULT" | grep -v '^ok$' | grep . \
    | LC_ALL=C sort || true)
  if [ -n "$BADS" ]; then
    printf '%s\n' "$BADS"
    FAIL=$((FAIL + $(printf '%s\n' "$BADS" | wc -l)))
  fi
  # Every queued fixture has to come back with a line. A child
  # that dies before it prints one -- a failed spawn, an OOM kill
  # -- leaves a fixture unjudged, and a matrix that ran in part
  # is not a matrix that passed: that is how a taboo stops being
  # blocked without anything saying so.
  if [ "$XSTATUS" -ne 0 ] || [ "$NGOT" -ne "$NCHECKS" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL: the parallel drain returned $NGOT verdicts for" \
      "$NCHECKS fixtures (xargs exit $XSTATUS) -- the matrix did" \
      "not run in full, which is not the same as it passing"
  fi
fi

finish "guard-taboos tests"
