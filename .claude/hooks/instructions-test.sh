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

# shellcheck source=corpus.sh
. "$CLAUDE_DIR/hooks/corpus.sh"

# One awk over the whole corpus: prefix each line with its file
# and drop URLs, in a single process rather than two per file.
# shellcheck disable=SC2046
SCAN=$(awk -v root="$CORPUS_ROOT/" '
  { n = FILENAME
    if (index(n, root) == 1) n = substr(n, length(root) + 1)
    gsub(/https?:\/\/[^ )"`,]*/, "")
    print n ": " $0 }' $(corpus_files) 2>/dev/null)

report() {
  # report <findings> <what-they-are>
  if [ -z "$1" ]; then
    ok
    return
  fi
  printf '%s\n' "$1" | while read -r l; do
    echo "FAIL: $l is not $2"
  done
  FAIL=$((FAIL + 1))
}


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
  if [ ! -e "$link" ] && [ ! -L "$link" ]; then
    bad ".claude/skills/$name does not exist -- Claude Code does" \
        "not search .agents/, so this skill is invisible to it"
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
  # -e is false for a dangling symlink, so test -L as well or a
  # link to a deleted skill is skipped instead of reported.
  { [ -e "$e" ] || [ -L "$e" ]; } || continue
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
RULE_KEYS=$(
  find "$ROOT/rules" -maxdepth 1 -name '*.md' 2>/dev/null \
    | sed 's#.*/##; s#\.md$##'
  # a subdirectory mirrors to a directory too (rules/os -> os/),
  # so it can clash with a skill of the same name
  find "$ROOT/rules" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sed 's#.*/##'
)
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
if [ "$NRULES" -lt 1 ]; then
  bad "no rule files found -- the search broke"
else
  ok
fi

# --- every pointer resolves --------------------------------------
# A dangling instruction pointer fails the way the references/
# check already guards against: silently. The file that should
# have been read simply is not, and nothing says so. Three more
# shapes of pointer exist, so three more checks.

# `rules/...md` paths, named from anywhere.
report "$(printf '%s\n' "$SCAN" \
  | grep -oE '^[^ ]+: |`rules/[a-z0-9/_-]+\.md`' \
  | awk '/: $/ { f = $0; next } { print f $0 }' \
  | tr -d '`' \
  | while IFS=' ' read -r f r; do
      [ -f "$ROOT/$r" ] || echo "$f $r"
    done)" "a rule file that exists"

# Skills and subagents named in prose. Several rules point at
# one by name rather than by path, which a rename breaks without
# a trace. bin/hostwarden-* are scripts, not either.
report "$(printf '%s\n' "$SCAN" \
  | grep -oE '^[^ ]+: |`hostwarden-[a-z-]+`' \
  | awk '/: $/ { f = $0; next } { print f $0 }' \
  | tr -d '`' \
  | grep -vE ' hostwarden-(migrate|update|backup|adopt)$' \
  | while IFS=' ' read -r f s; do
      [ -d "$ROOT/.agents/skills/$s" ] && continue
      [ -f "$CLAUDE_DIR/agents/$s.md" ] && continue
      echo "$f $s"
    done)" "a skill or subagent that exists"

# A skill's frontmatter name against its directory. The override
# path keys off the directory; the slash command and the
# harness's own matching key off the frontmatter. Let them
# diverge and a user's override file names one while the skill
# fires as the other.
MISNAMED=$(
  for d in "$ROOT"/.agents/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    dn=$(basename "$d")
    fn=$(sed -n 's/^name:[[:space:]]*//p' "$d/SKILL.md" | head -1)
    [ "$fn" = "$dn" ] || echo ".agents/skills/$dn: frontmatter name '$fn'"
  done
)
report "$MISNAMED" "the name of its own directory"

# --- examples name nobody real ----------------------------------
# .claude/rules/instruction-authoring.md: hostnames from RFC 2606,
# addresses from RFC 5737/3849, people from the Alice-and-Bob
# convention. An example that borrows a real identifier points a
# reader -- or a copied command -- at somebody else's machine.
#
# One pass over the corpus rather than one per check: three
# separate loops each re-read every file and forked a pipeline per
# file, which was over half the runtime of this script.
#
# URLs are stripped first: linking to a project's documentation is
# not the same as pretending to own a name.
# Addresses outside the documentation ranges. Private, loopback,
# link-local and netmasks are legitimate subjects of an example.
report "$(printf '%s\n' "$SCAN" \
  | grep -oE '^[^ ]+: |\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' \
  | awk '/: $/ { f = $0; next } { print f $0 }' \
  | grep -vE ': (192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)' \
  | grep -vE ': (127\.|10\.|192\.168\.|169\.254\.|0\.0\.0\.0)' \
  | grep -vE ': 172\.(1[6-9]|2[0-9]|3[01])\.' \
  | grep -vE ': 255\.')" "an RFC 5737 documentation address"

# IPv6. Only 2001:db8::/32 is documentation space (RFC 3849).
# Matching every colon-hex string would catch timestamps and MAC
# addresses, so this looks for the global-unicast shape.
report "$(printf '%s\n' "$SCAN" \
  | grep -oiE '^[^ ]+: |\b[23][0-9a-f]{3}:[0-9a-f:]{2,}[0-9a-f]\b' \
  | awk '/: $/ { f = $0; next } { print f $0 }' \
  | grep -viE ': 2001:0?db8')" "an RFC 3849 documentation address"

# Mail addresses outside example.*. openssh.com is allowed because
# it suffixes algorithm names (umac-64@openssh.com), not people.
report "$(printf '%s\n' "$SCAN" \
  | grep -oE '^[^ ]+: |[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' \
  | awk '/: $/ { f = $0; next } { print f $0 }' \
  | grep -vE '@(.*\.)?example\.(com|net|org)$' \
  | grep -vE '@openssh\.com$')" "an RFC 2606 example address"

# SSH targets. A hostname a command connects to may well be real
# infrastructure -- security.debian.org, time.apple.com -- and no
# pattern tells that from a borrowed example, so hostnames at
# large are a review matter. The target of an ssh or scp command
# never is: hostwarden only ever logs into a user's machine. Both
# forms count, with a user and without.
#
# The command word must be followed by a space, or every
# rules/ssh-*.md reference reads as an invocation. A candidate
# ending in a file extension is a path, not a host, and
# openssh.com suffixes cipher names rather than naming a machine.
report "$(printf '%s\n' "$SCAN" \
  | grep -oE '^[^ ]+: |(^|[^a-z0-9_.-])(ssh|scp|ssh-copy-id) [^|;&`]*' \
  | awk '/: $/ { f = $0; next } { print f $0 }' \
  | grep -oE '^[^ ]+: |[ =]([a-z0-9_-]+@)?[a-z0-9][a-z0-9-]*(\.[a-z0-9-]+)+' \
  | awk '/: $/ { f = $0; next } { print f $0 }' \
  | sed -E 's#: [ =]#: #; s#: [a-z0-9_-]+@#: #' \
  | grep -E '\.[a-z]{2,}$' \
  | grep -vE '\.(md|sh|conf|service|real|pub|txt|xz|json|ya?ml|log|key|example|local|d|bak|gz|img|sock)$' \
  | grep -vE ': ([a-z0-9-]+\.)*example\.(com|net|org)$' \
  | grep -vE ': (localhost|openssh\.com)$')" "an RFC 2606 example target"

echo "instruction layout tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
