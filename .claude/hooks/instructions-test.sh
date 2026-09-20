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
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

# --- skills resolve through .claude/skills/ --------------------
# The skills live in .agents/skills/, which OpenCode and other
# AGENTS-style tools read directly. Claude Code does NOT search
# .agents/, so each .claude/skills/<name> symlink is load-bearing:
# a checkout that turns symlinks into plain files loses every
# skill, including the security audit. Fail loudly instead.
NSKILLS=0
for d in "$ROOT"/.agents/skills/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  NSKILLS=$((NSKILLS + 1))

  if [ ! -f "$d/SKILL.md" ]; then
    bad ".agents/skills/$name has no SKILL.md"
    continue
  fi

  link="$CLAUDE_DIR/skills/$name"
  if [ ! -L "$link" ]; then
    bad ".claude/skills/$name is not a symlink -- Claude Code" \
        "does not search .agents/, so this skill is invisible" \
        "to it"
  elif [ ! -f "$link/SKILL.md" ]; then
    bad ".claude/skills/$name is a symlink that does not resolve"
  else
    ok
  fi
done

if [ "$NSKILLS" -eq 0 ]; then
  bad "no skills found under .agents/skills/ -- the search broke"
fi

# --- no stray skill directory beside the links -----------------
# A real directory under .claude/skills/ means someone added a
# skill in the old place. Claude Code would load it and every
# other tool would miss it.
for e in "$CLAUDE_DIR"/skills/*; do
  [ -e "$e" ] || continue
  if [ ! -L "$e" ]; then
    bad ".claude/skills/$(basename "$e") is a real path, not a" \
        "link into .agents/skills/"
  fi
done

# --- override paths are unambiguous -----------------------------
# rules/overrides.md mirrors the shipped path into
# memory/custom-rules/, dropping the top-level directory and the
# references/ segment. That is unique by construction everywhere
# except one seam: a rules/<name>.md and a skill called <name>
# would both mirror to memory/custom-rules/<name>.md.
RULE_KEYS=$(find "$ROOT/rules" -maxdepth 1 -name '*.md' 2>/dev/null \
  | sed 's#.*/##; s#\.md$##')
SKILL_KEYS=$(find "$ROOT/.agents/skills" -mindepth 1 -maxdepth 1 \
  -type d 2>/dev/null | sed 's#.*/##')

CLASH=$(printf '%s\n%s\n' "$RULE_KEYS" "$SKILL_KEYS" | sed '/^$/d' \
  | LC_ALL=C sort | LC_ALL=C uniq -d)
if [ -z "$CLASH" ]; then
  ok
else
  for c in $CLASH; do
    bad "'$c' is both a rule file and a skill -- both would" \
        "mirror to memory/custom-rules/$c.md"
  done
fi

NRULES=$(printf '%s\n' "$RULE_KEYS" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$NRULES" -lt 15 ]; then
  bad "only $NRULES rule files found -- the search broke"
else
  ok
fi

echo "instruction layout tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
