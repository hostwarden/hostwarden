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

# --- override paths are unambiguous -----------------------------
# rules/overrides.md mirrors every shipped path into
# memory/custom-rules/, dropping the top-level directory and the
# references/ segment. Two shipped files that mirror to one path
# leave the user's override pointing at both and applying to
# whichever is read first. Comparing top-level names only would
# miss the nested seam: rules/foo/bar.md and skill foo's
# references/bar.md both mirror to foo/bar.md.
#
# So mirror everything and look for a repeat.
MIRRORED=$(
  find "$ROOT/rules" -name '*.md' 2>/dev/null \
    | sed "s#^$ROOT/rules/##"
  find "$ROOT/.agents/skills" -mindepth 1 -maxdepth 1 -type d \
    2>/dev/null | sed 's#.*/##; s#$#.md#'
  find "$ROOT/.agents/skills" -path '*/references/*.md' 2>/dev/null \
    | sed "s#^$ROOT/.agents/skills/##; s#/references/#/#"
)
CLASH=$(printf '%s\n' "$MIRRORED" | sed '/^$/d' \
  | LC_ALL=C sort | LC_ALL=C uniq -d)
if [ -z "$CLASH" ]; then
  ok
else
  for c in $CLASH; do
    bad "two shipped files both mirror to" \
        "memory/custom-rules/$c -- an override there is" \
        "ambiguous"
  done
fi

RULE_KEYS=$(find "$ROOT/rules" -maxdepth 1 -name '*.md' 2>/dev/null \
  | sed 's#.*/##; s#\.md$##')

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
  find "$ROOT/rules" "$ROOT/.agents" "$ROOT/contrib" \
       "$CLAUDE_DIR/rules" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/hooks" \
       "$ROOT/.github" -type f 2>/dev/null
  ls "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md" "$ROOT/README.md" \
     "$ROOT/CHANGELOG.md" 2>/dev/null
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

# SSH targets. A hostname a command connects to may well be
# real infrastructure -- security.debian.org, time.apple.com --
# and no pattern tells that from a borrowed example, so
# hostnames at large are a review matter. The target of an ssh
# or scp command never is: hostwarden only ever logs into a
# user's machine, so every one in an instruction file is an
# example and must say so. Both forms count, with a user and
# without.
#
# The command word must be followed by a space, or every
# rules/ssh-*.md reference in the tree reads as an invocation.
# A candidate ending in a file extension is a path, not a host,
# and openssh.com suffixes cipher and MAC names rather than
# naming a machine (ssh -c aes256-gcm@openssh.com host).
BAD_SSH=$(
  for f in $CORPUS_FILES; do
    strip_urls "$f" \
      | grep -oE '(^|[^a-z0-9_.-])(ssh|scp|ssh-copy-id) [^|;&`]*' \
      | grep -oE '[ =]([a-z0-9_-]+@)?[a-z0-9][a-z0-9-]*(\.[a-z0-9-]+)+' \
      | sed -E 's#^[ =]##; s#^[a-z0-9_-]+@##' \
      | grep -E '\.[a-z]{2,}$' \
      | grep -vE '\.(md|sh|conf|service|real|pub|txt|xz|json|ya?ml|log|key|example|local|d|bak|gz|img|sock)$' \
      | grep -vE '(^|\.)example\.(com|net|org)$' \
      | grep -vE '^(localhost|openssh\.com)$' \
      | sed "s#^#$f: #"
  done
)
if [ -z "$BAD_SSH" ]; then ok; else
  printf '%s\n' "$BAD_SSH" | while read -r l; do
    echo "FAIL: $l is not an RFC 2606 example target"
  done
  FAIL=$((FAIL + 1))
fi

# IPv6. Only 2001:db8::/32 is documentation space (RFC 3849).
# Matching every colon-hex string would catch timestamps and
# MAC addresses, so this looks for the global-unicast shape --
# a 2xxx: or 3xxx: literal with at least two more groups.
BAD_IP6=$(
  for f in $CORPUS_FILES; do
    strip_urls "$f" \
      | grep -oiE '\b[23][0-9a-f]{3}:[0-9a-f:]{2,}[0-9a-f]\b' \
      | grep -viE '^2001:0?db8[:0-9a-f]*$' | sed "s#^#$f: #"
  done
)
if [ -z "$BAD_IP6" ]; then ok; else
  printf '%s\n' "$BAD_IP6" | while read -r l; do
    echo "FAIL: $l is not an RFC 3849 documentation address"
  done
  FAIL=$((FAIL + 1))
fi

echo "instruction layout tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
