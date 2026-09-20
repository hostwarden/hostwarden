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

# --- examples name nobody real ----------------------------------
# .claude/rules/instruction-authoring.md: hostnames from RFC 2606,
# addresses from RFC 5737/3849, people from the Alice-and-Bob
# convention. An example that borrows a real identifier points a
# reader -- or a copied command -- at somebody else's machine.
#
# URLs are stripped first: linking to a project's documentation is
# not the same as pretending to own a name.
CORPUS_FILES=$(
  find "$ROOT/rules" "$ROOT/.agents" "$ROOT/contrib" -name '*.md' \
    2>/dev/null
  ls "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md" 2>/dev/null
)

strip_urls() { sed -E 's#https?://[^ )"`,]*##g' "$1"; }

# Addresses outside the documentation ranges. Private, loopback,
# link-local and netmasks are legitimate subjects of an example.
BAD_IP=$(
  for f in $CORPUS_FILES; do
    strip_urls "$f" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' \
      | grep -vE '^(192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)' \
      | grep -vE '^(127\.|10\.|192\.168\.|169\.254\.|0\.0\.0\.0)' \
      | grep -vE '^172\.(1[6-9]|2[0-9]|3[01])\.' \
      | grep -vE '^255\.' | sed "s#^#$f: #"
  done
)
if [ -z "$BAD_IP" ]; then ok; else
  printf '%s\n' "$BAD_IP" | while read -r l; do
    echo "FAIL: $l is not an RFC 5737 documentation address"
  done
  FAIL=$((FAIL + 1))
fi

# Mail addresses outside example.*. openssh.com is allowed because
# it suffixes algorithm names (umac-64@openssh.com), not people.
BAD_MAIL=$(
  for f in $CORPUS_FILES; do
    strip_urls "$f" \
      | grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' \
      | grep -vE '@(.*\.)?example\.(com|net|org)$' \
      | grep -vE '@openssh\.com$' | sed "s#^#$f: #"
  done
)
if [ -z "$BAD_MAIL" ]; then ok; else
  printf '%s\n' "$BAD_MAIL" | while read -r l; do
    echo "FAIL: $l is not an RFC 2606 example address"
  done
  FAIL=$((FAIL + 1))
fi

# SSH targets. A hostname a command connects to may well be real
# infrastructure -- security.debian.org, time.apple.com -- and no
# pattern tells that from a borrowed example, so hostnames at
# large are a review matter. An SSH target never is: hostwarden
# only ever logs into a user's machine, so every one in an
# instruction file is an example and must say so.
BAD_SSH=$(
  for f in $CORPUS_FILES; do
    strip_urls "$f" \
      | grep -oE '[a-z0-9_-]+@[a-z0-9][a-z0-9.-]*\.[a-z]{2,}' \
      | grep -vE '@(.*\.)?example\.(com|net|org)$' \
      | grep -vE '@openssh\.com$' | sed "s#^#$f: #"
  done
)
if [ -z "$BAD_SSH" ]; then ok; else
  printf '%s\n' "$BAD_SSH" | while read -r l; do
    echo "FAIL: $l is not an RFC 2606 example target"
  done
  FAIL=$((FAIL + 1))
fi

echo "instruction layout tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
