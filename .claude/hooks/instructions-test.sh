#!/bin/sh
# instructions-test.sh — dev-only structural checks on the
# instruction layer. Run manually before committing changes to
# it:  sh .claude/hooks/instructions-test.sh
# Not invoked by Claude Code at runtime.
#
# What the content of an instruction says is a matter of judgement.
# Where it lives is not, and neither is whether the mechanism that
# loads it still points at it. That is what this file asserts.

CLAUDE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CLAUDE_DIR/.." && pwd)"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

# --- skills resolve through .claude/skills ---------------------
# The skills live in .agents/skills/, which OpenCode and other
# AGENTS-style tools read directly. Claude Code does NOT search
# .agents/, so the .claude/skills link is load-bearing: a
# checkout that turns it into a plain file loses every skill,
# including the security audit. Fail loudly instead.
if [ ! -L "$CLAUDE_DIR/skills" ]; then
  bad ".claude/skills is not a symlink -- Claude Code does not" \
      "search .agents/, so no skill is visible to it"
elif [ ! -d "$CLAUDE_DIR/skills" ]; then
  bad ".claude/skills is a symlink that does not resolve"
elif [ "$(cd "$CLAUDE_DIR/skills" && pwd -P)" \
       != "$(cd "$ROOT/.agents/skills" && pwd -P)" ]; then
  bad ".claude/skills resolves somewhere other than" \
      ".agents/skills/"
else
  ok
fi

# --- every skill is a skill ------------------------------------
# A directory without a SKILL.md is invisible to every tool, so
# it is a skill nobody loads rather than a skill.
NSKILLS=0
for d in "$ROOT"/.agents/skills/*/; do
  [ -d "$d" ] || continue
  NSKILLS=$((NSKILLS + 1))
  if [ -f "$d/SKILL.md" ]; then
    ok
  else
    bad ".agents/skills/$(basename "$d") has no SKILL.md"
  fi
done

if [ "$NSKILLS" -eq 0 ]; then
  bad "no skills found under .agents/skills/ -- the search broke"
fi

echo "instruction layout tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
