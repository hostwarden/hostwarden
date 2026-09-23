#!/bin/sh
# instructions-test.sh — dev-only structural checks on the
# instruction layer. CI runs it through scripts/check.sh; an
# agent session leaves it to CI (.claude/rules/pull-requests.md →
# Checks). Not invoked by Claude Code at runtime.
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

# shellcheck source=corpus.sh
. "$CLAUDE_DIR/hooks/corpus.sh"

# One awk over the whole corpus: prefix each line with its file
# and drop URLs, in a single process rather than two per file.
#
# Fed NUL-separated through xargs rather than as an unquoted
# $(corpus_files): a checkout under a path with a space in it split
# into arguments awk could not open, and with its diagnostics
# discarded SCAN came back empty -- every check below then passed
# over nothing at all. That is the one failure this file cannot
# have, so awk's stderr is kept and an empty scan is a failure.
#
# A URL's host is a link, not an identifier the example claims to
# own, so it goes. Its path does not: an address literal written
# as https://192.0.2.7/status is still an address, and the IPv4
# check has to see it.
SCAN=$(corpus_files | tr '\n' '\0' \
  | xargs -0 awk -v root="$CORPUS_ROOT/" '
  { n = FILENAME
    if (index(n, root) == 1) n = substr(n, length(root) + 1)
    gsub(/https?:\/\/[^\/ )"`,]*/, " ")
    # A command continued with a trailing backslash puts its
    # destination on the next line, where nothing says it belongs
    # to an ssh. Join them, so the checks below see one command.
    if (held != "") { $0 = held " " $0; held = "" }
    if ($0 ~ /\\[ \t]*$/) { sub(/\\[ \t]*$/, "", $0); held = $0; next }
    print n ": " $0 }
  END { if (held != "") print n ": " held }')
if [ -z "$SCAN" ]; then
  bad "the corpus scan came back empty -- every identifier and" \
      "pointer check below would pass over nothing"
fi

scan() { printf '%s\n' "$SCAN"; }

# tag <extended-regex> -- reads the corpus on stdin and prints
# every match, each prefixed with the file it came from. On stdin
# rather than straight from SCAN, because several checks below
# filter or rewrite the corpus before they look at it.
#
# The prefix carries its trailing space and the split is on `: `
# rather than on a final colon. A match may itself end in a colon
# -- a compressed IPv6 address does -- and a bare `/:$/` reads
# that as the next filename and drops it, which is precisely the
# shape the address check has to catch.
tag() {
  grep -oE "^[^ ]+: |$1" \
    | awk '/: $/ { f = $0; next } { print f $0 }'
}

# tag_i <extended-regex> -- tag, case-insensitively, folding the
# match to lower case so one spelling reaches the comparisons
# below: domain names are case-insensitive, and alice@Example.COM
# is the same example as alice@example.com. The file name is left
# alone, since it is a path and a failure names it back to the
# reader.
tag_i() {
  grep -oiE "^[^ ]+: |$1" \
    | awk '/: $/ { f = $0; next } { print f tolower($0) }'
}

report() {
  # report <findings> <what-they-are>
  if [ -z "$1" ]; then
    ok
    return
  fi
  printf '%s\n' "$1" | while read -r l; do
    echo "FAIL: $l is not $2"
  done
  # One per finding, not one per check: a count that says 1
  # while three lines print above it sends whoever works the
  # list by the number looking for a problem that is not there.
  FAIL=$((FAIL + $(printf '%s\n' "$1" | wc -l)))
}



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

# --- every override the migration moves has somewhere to land ---
# bin/hostwarden-migrate carries a table of topics that changed
# address, and moves a user's override to the new one. A row whose
# destination does not exist relocates an override to a path
# nothing reads -- the exact failure the table exists to prevent.
MIGRATE="$ROOT/bin/hostwarden-migrate"
if [ -f "$MIGRATE" ]; then
  map_rows() {
    sed -n "/^MAP='/,/'\$/p" "$MIGRATE" | sed "s/^MAP='//; s/'\$//"
  }

  # The other direction, and the one that costs a user their
  # override rather than misplacing it: a row moves
  # `memory/custom-rules/<old>.md` away, which is right only while
  # nothing ships under that key any more. Ship a rule file named
  # after a row's left column again and the migration relocates a
  # live override on the next pull, silently, because that move
  # looks exactly like the intended one.
  BAD_SRC=$(
    map_rows \
      | while read -r old new; do
          [ -n "$old" ] && [ -n "$new" ] || continue
          if [ -f "$ROOT/rules/$old.md" ] \
            || [ -d "$ROOT/.agents/skills/$old" ]; then
            echo "bin/hostwarden-migrate: $old"
          fi
        done
  )
  report "$BAD_SRC" "a topic that has actually moved away"

  BAD_MAP=$(
    map_rows \
      | while read -r old new; do
          # Only a wholly blank row is nothing. A row that names a
          # topic and no destination makes the script move the
          # override onto memory/custom-rules/ itself.
          [ -n "$old" ] || continue
          if [ -z "$new" ]; then
            echo "bin/hostwarden-migrate: '$old' with no destination"
            continue
          fi
          # The destination is a file name, and the override lookup
          # reads .md. Without it the move lands somewhere nothing
          # reads, which is the failure this table exists to stop.
          case "$new" in
            (*.md) ;;
            (*) echo "bin/hostwarden-migrate: $new (no .md suffix)"
                continue ;;
          esac
          skill="${new%%/*}"
          leaf="${new##*/}"
          if [ "$skill" = "$new" ]; then
            # a bare name is a skill's own SKILL.md
            [ -f "$ROOT/.agents/skills/${new%.md}/SKILL.md" ] && continue
          else
            [ -f "$ROOT/.agents/skills/$skill/references/$leaf" ] && continue
          fi
          [ -f "$ROOT/rules/$new" ] && continue
          echo "bin/hostwarden-migrate: $new"
        done
  )
  report "$BAD_MAP" "a path anything ships"
fi

# --- a references/ pointer resolves ----------------------------
# Two shapes, because `references/x.md` means "inside the skill
# that wrote this". A skill may use it; anywhere else it resolves
# against nothing, so a cross-skill pointer spells the path out
# from the repo root -- longer, and unambiguous.
#
# Both are checked here, at any depth, wherever they are written:
# a full path is a pointer no matter which file names it, and the
# whole point of rewriting one is that it can then be verified.
#
# What is not checked: a relative pointer in a file outside
# `.agents/skills/`. In `rules/overrides.md` and
# docs/overrides.md that shape appears in a table *describing*
# the mirror scheme, and no pattern separates an example of a path
# from a use of one. Those two files document; they do not route.
REF_RE='`(\.agents/skills/[a-z0-9-]+/)?references/[a-z0-9._/-]+\.md`'
BAD_REFS=$(
  scan | tag "$REF_RE" \
    | tr -d '`' \
    | while IFS=' ' read -r f r; do
        fp="${f%:}"
        case "$r" in
          (.agents/skills/*)
            [ -f "$ROOT/$r" ] || echo "$f $r" ;;
          (*)
            case "$fp" in
              (.agents/skills/*)
                sk=$(printf '%s' "$fp" | cut -d/ -f1-3)
                [ -f "$ROOT/$sk/$r" ] || echo "$f $r" ;;
            esac ;;
        esac
      done
)
NREFS=$(scan | tag "$REF_RE" | grep -c . || true)
report "$BAD_REFS" "a reference that resolves"
if [ "$NREFS" -lt 5 ]; then
  bad "only $NREFS references/ pointers found -- the search broke"
fi

# --- override paths are unambiguous -----------------------------
# rules/overrides.md mirrors every shipped path into
# memory/custom-rules/, dropping the top-level directory and the
# references/ segment. Two shipped files that mirror to one path
# leave the user's override pointing at both and applying to
# whichever is read first. Comparing top-level names only would
# miss the nested seam: a rule file one level down and a skill
# reference of the same name both mirror to one path.
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
# `all.md` is the every-file override the preflight loads, so a
# a rule file named `all`, or a skill of that name, would mirror
# onto it and be
# both at once. Seeding the list with it makes that a duplicate.
CLASH=$(printf '%s\nall.md\n' "$MIRRORED" | sed '/^$/d' \
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
if [ "$NRULES" -lt 1 ]; then
  bad "no rule files found -- the search broke"
else
  ok
fi

# --- every pointer resolves --------------------------------------
# A dangling instruction pointer fails the way the references/
# check already guards against: silently. The file that should
# have been read simply is not, and nothing says so. Every other
# shape of pointer gets a check of its own below.

# `rules/...md` paths, named from anywhere -- in backticks, in a
# Markdown link, or bare in a sentence. A rename breaks all three
# the same way, so the formatting is not part of the pointer.
#
# The left boundary earns its place: an override path under
# `memory/custom-rules/`, and any path under `.claude/rules/`,
# both end in the same shape a pointer has. Without a boundary
# every one of them reads as a pointer at a rule that does not
# exist, and this check drowns in its own corpus.
#
# CHANGELOG.md is out of scope. It is the one file that records a
# change as a change -- the release rule in `.claude/rules/` says
# so -- which means it names paths that moved, by design.
report "$(scan \
  | grep -v '^CHANGELOG\.md: ' \
  | tag '(^|[^a-z0-9/_.-])rules/[a-z0-9/_-]+\.md' \
  | sed -E 's#^([^ ]+:) [^a-z0-9/_.-]?rules/#\1 rules/#' \
  | while IFS=' ' read -r f r; do
      [ -f "$ROOT/$r" ] || echo "$f $r"
    done)" "a rule file that exists"

# Skills and subagents named in prose. Several rules point at
# one by name rather than by path, which a rename breaks without
# a trace. A script in bin/ is neither and counts as existing, and
# so does hostwarden-workspace, the repository name
# docs/operations.md recommends for the workspace remote.
report "$(scan \
  | grep -v '^CHANGELOG\.md: ' \
  | tag '`hostwarden-[a-z-]+`' \
  | tr -d '`' \
  | grep -v ' hostwarden-workspace$' \
  | while IFS=' ' read -r f s; do
      [ -d "$ROOT/.agents/skills/$s" ] && continue
      [ -f "$CLAUDE_DIR/agents/$s.md" ] && continue
      [ -f "$ROOT/bin/$s" ] && continue
      echo "$f $s"
    done)" "a skill or subagent that exists"

# A skill's frontmatter name against its directory, and a
# subagent's against its file name. The override path keys off the
# directory; the slash command and the harness's own matching key
# off the frontmatter. Let them diverge and a user's override file
# names one while the skill fires as the other -- and a subagent
# is dispatched by its frontmatter name, so the same split leaves
# the fleet audit calling for an agent nothing answers to.
MISNAMED=$(
  for a in "$CLAUDE_DIR"/agents/*.md; do
    [ -f "$a" ] || continue
    an=$(basename "$a" .md)
    afn=$(awk 'NR == 1 && $0 != "---" { exit }
      NR > 1 && $0 == "---" { exit }
      NR > 1' "$a" \
      | sed -n 's/^name:[[:space:]]*//p' | head -1)
    [ "$afn" = "$an" ] || echo ".claude/agents/$an.md: frontmatter name '$afn'"
  done
  for d in "$ROOT"/.agents/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    dn=$(basename "$d")
    # Only inside the opening --- block: a `name:` further down is
    # body text, and the harness cannot key off it.
    fn=$(awk 'NR == 1 && $0 != "---" { exit }
      NR > 1 && $0 == "---" { exit }
      NR > 1' "$d/SKILL.md" \
      | sed -n 's/^name:[[:space:]]*//p' | head -1)
    [ "$fn" = "$dn" ] || echo ".agents/skills/$dn: frontmatter name '$fn'"
  done
)
report "$MISNAMED" "the name it is dispatched by"

# load(path) -- awk, for the two checks below: reads the ATX
# headings of a Markdown file once into H[path, 1..NH[path]] and
# returns whether the file could be read. Each target is named by
# dozens of pointers; reading it once per pointer tripled the
# runtime of this file. A heading inside an HTML comment renders as
# nothing, so a section parked in one has no anchor either.
LOAD_AWK="$FENCE_AWK"'
function load(p,   l, h) {
  if (p in NH) return NH[p] >= 0
  NH[p] = -1
  if ((getline l < p) <= 0) return 0
  NH[p] = 0; FM = CM = ""
  do {
    if (commented(l)) continue
    # Seven or more #s are text, not a heading.
    if (!fenced(l) && l ~ /^#+[ \t]/ && l !~ /^#######/) {
      h = l; sub(/^#+[ \t]+/, "", h); sub(/[ \t]+(#+[ \t]*)?$/, "", h)
      H[p, ++NH[p]] = h }
  } while ((getline l < p) > 0)
  close(p)
  return 1
}'

# Headings named in prose: `AGENTS.md` → SSH Options,
# `rules/dns-aliases.md` § Detection, and the ASCII spelling
# `AGENTS.md - Critical Safety Rules` a hook's printf uses. A renamed heading leaves every one of them pointing at a
# section the reader then cannot find, and nothing says so.
#
# Such a pointer wraps wherever the sentence does, often between
# the arrow and the heading, and a comment or an echo line wraps
# without the backslash the scan joins on. So every line that names
# a file is read together with the next, minus the comment marker
# or the echo that opens it. A separator marks the seam: a match
# that does not cross it started on the next line, which is read
# in its own turn.
#
# The heading has to be where the pointer text begins, not the
# whole of it -- "Detection step 1" is a pointer at Detection, and
# where a heading ends in a sentence no pattern can say. A heading
# is named without its step number, subtitle or parenthetical:
# "Boot Configuration Safety" for "Boot Configuration Safety
# (CRITICAL)". A bold bullet is not a heading; point at the
# heading above it. README alone is README.md. A relative target
# resolves against the root, the skill it is written in, then its
# own directory. Someone else's README ("its README", "Heinzel's
# README") is not ours.
SEP=$(printf '\037')
PTR_RE="(^|[^A-Za-z0-9_./<>-])(its |[A-Za-z]+'s )?\`?([A-Za-z0-9_./-]*[A-Za-z0-9_-]\\.md|README)\`?[[:blank:]]*(→|§| - ).*"
POINTERS=$(scan \
  | grep -v '^CHANGELOG\.md: ' \
  | awk -v sep="$SEP" '
    { f = $1; t = substr($0, length($1) + 2) }
    NR > 1 && (index(pt, ".md") || index(pt, "README")) {
      n = (f == pf) ? t : ""
      sub(/^[ \t]*(#+|\/\/)?[ \t]*((echo|printf)[ \t]+)?["\047]?/, "", n)
      print pf " " pt sep " " n }
    { pf = f; pt = t }
    END { if (NR) print pf " " pt sep }' \
  | tag "$PTR_RE" \
  | grep "$SEP")
NPTR=$(printf '%s\n' "$POINTERS" | grep -c . || true)
if [ "$NPTR" -lt 10 ]; then
  bad "only $NPTR heading pointers found -- the search broke"
fi
report "$(printf '%s\n' "$POINTERS" \
  | awk -v sep="$SEP" -v root="$ROOT/" "$LOAD_AWK"'
    function named(h, l) {
      return index(h, l) == 1 && substr(h, length(l) + 1) !~ /^[A-Za-z0-9]/
    }
    NF {
      f = $1; s = substr($0, length($1) + 2); gsub(sep, " ", s)
      if (s ~ /^[^A-Za-z]?(its |[A-Za-z]+\047s )/) next
      match(s, /[A-Za-z0-9_.\/-]*[A-Za-z0-9_-]\.md|README/)
      t = substr(s, RSTART, RLENGTH)
      h = substr(s, RSTART + RLENGTH)
      sub(/^`?[ \t]*(→|§| - )[ \t]*["`]?/, "", h)
      gsub(/[ \t]+/, " ", h)
      if (t == "README") t = "README.md"
      fp = f; sub(/:$/, "", fp)
      dir = fp; sub(/[^\/]*$/, "", dir)
      skill = ""
      if (match(fp, /^\.agents\/skills\/[^\/]+\//))
        skill = substr(fp, 1, RLENGTH)
      if (load(root t)) p = root t
      else if (skill != "" && load(root skill t)) p = root skill t
      else if (load(root dir t)) p = root dir t
      else { print f " " t " (no such file)"; next }
      for (i = 1; i <= NH[p]; i++) {
        l = H[p, i]
        if (named(h, l)) next
        sub(/^[0-9]+\. /, "", l); sub(/ (\(|—|–).*/, "", l)
        if (named(h, l)) next
      }
      print f " " t " → " h }')" "a heading that exists"

# Anchored links in the documents GitHub renders: the file has to
# exist and the anchor has to be a slug GitHub derives from one of
# its headings -- lower case, punctuation but `-` and `_` dropped,
# spaces to `-`, and a slug already taken gets the first free -N,
# counted per base the way github-slugger does. A dead anchor still
# opens the page, at the top, which is why nobody notices.
#
# Bytes, not characters, so the punctuation class can keep every
# letter outside ASCII. The price is tolower(), which then folds
# ASCII only; the Latin-1 capitals (Ä, Ö, Ü, É …) are folded by
# hand, and anything beyond them is a matter for review.
#
# A link shown in a fenced block is code, not a link, and one inside
# an HTML comment renders as nothing, as load() reads its headings.
# A heading that is a link slugs from its text alone:
# `## [Install](x.md)` is #install. Inline HTML renders as nothing;
# an autolink renders as its address.
report "$(scan \
  | grep -E '^((README|CONTRIBUTING|SECURITY)\.md|docs/[^/]*\.md): ' \
  | awk "$FENCE_AWK"'
    { f = $0; sub(/: .*/, "", f)
      if (f != last) { FM = CM = ""; last = f }
      t = $0; sub(/^[^ ]+: /, "", t)
      if (!commented(t) && !fenced(t)) print }' \
  | tag '\]\([^):[:space:]]*#[^)[:space:]]+([[:space:]][^)]*)?\)' \
  | sed -E 's#^([^ ]+): \]\(([^#]*)\#([^)[:space:]]*).*$#\1|\2|\3#' \
  | LC_ALL=C awk -F'|' -v root="$ROOT/" "$LOAD_AWK"'
    {
      f = $1; dir = f; sub(/[^\/]*$/, "", dir)
      p = root ($2 == "" ? f : dir $2)
      if (!load(p)) { print f ": " $2 " (no such file)"; next }
      if (!(p in SLUGGED)) {
        SLUGGED[p] = 1
        for (i = 1; i <= NH[p]; i++) {
          s = H[p, i]
          while (match(s, /\[[^]]*\]\([^)]*\)/)) {
            t = substr(s, RSTART + 1, RLENGTH - 1); sub(/\]\(.*$/, "", t)
            s = substr(s, 1, RSTART - 1) t substr(s, RSTART + RLENGTH)
          }
          # An autolink shows its address; any other tag is HTML.
          while (match(s, /<([A-Za-z][A-Za-z0-9+.-]*:[^ <>]*|[^ <>@]+@[^ <>]+)>/))
            s = substr(s, 1, RSTART - 1) substr(s, RSTART + 1, RLENGTH - 2) \
              substr(s, RSTART + RLENGTH)
          gsub(/<[^>]*>/, "", s)
          s = tolower(s)
          for (c = 128; c <= 158; c++)
            if (c != 151)
              gsub("\303" sprintf("%c", c), "\303" sprintf("%c", c + 32), s)
          gsub(/\342\200[\223\224]/, "", s)
          gsub(/[^a-z0-9 _\200-\377-]/, "", s)
          gsub(/ /, "-", s)
          b = s
          while ((p, s) in SLUG) s = b "-" (++SEEN[p, b])
          SLUG[p, s] = 1
        }
      }
      if (!((p, $3) in SLUG)) print f ": " $2 "#" $3 }')" \
  "an anchor GitHub renders"

# Every page under docs/, subdirectories included, is listed in its
# index. The README points there instead of keeping a list of its
# own, so a page the index leaves out is a page no link reaches.
UNLISTED=$(cd "$ROOT/docs" && find . -name '*.md' ! -path ./README.md \
  | sed 's#^\./##' | sort | while read -r n; do
    grep -qF -e "]($n)" -e "]($n#" -e "]($n " README.md \
      || echo "docs/$n"
  done)
report "$UNLISTED" "listed in docs/README.md"

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
# Addresses outside the documentation ranges. Private, shared
# (RFC 6598), loopback, link-local and netmasks are legitimate
# subjects of an example.
report "$(scan \
  | sed -E 's#([[:space:]])[vV]ersion [0-9]+(\.[0-9]+)+#\1#g
            s#([[:space:]])v[0-9]+(\.[0-9]+)+#\1#g' \
  | tag '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' \
  | grep -vE ': (192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)' \
  | grep -vE ': (127\.|10\.|192\.168\.|169\.254\.|0\.0\.0\.0)' \
  | grep -vE ': 172\.(1[6-9]|2[0-9]|3[01])\.' \
  | grep -vE ': 100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.' \
  | grep -vE ': 255\.')" "an RFC 5737 documentation address"

# IPv6. Only 2001:db8::/32 is documentation space for examples
# (RFC 3849). Matching every colon-hex string would catch
# timestamps and MAC addresses, so this looks for the
# global-unicast shape, including the compressed forms that end in
# `::` -- which is why `tag` splits on `: ` and not on a final
# colon. RFC 9637's 3fff::/20 passes only as the bare prefix, which
# rules/network.md names as a range never to find on a host.
report "$(scan \
  | tag_i '\b[23][0-9a-f]{3}:[0-9a-f]*(:[0-9a-f]*)+' \
  | grep -vE ': 2001:0?db8:' \
  | grep -vE ': 3fff::$')" "an RFC 3849 documentation address"

# Mail addresses outside the reserved domains.
#
# openssh.com is exempt only where it does what it does in this
# corpus: suffix an algorithm name (umac-64-etm@openssh.com). A
# local part with no hyphen names a person, and an address of
# that shape at that domain is borrowed like any other.
report "$(scan \
  | tag_i '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' \
  | grep -vE '@(.*\.)?example\.(com|net|org)$' \
  | grep -vE '@([a-z0-9-]+\.)*(test|invalid)$' \
  | grep -vE ' [a-z0-9]+(-[a-z0-9]+)+@openssh\.com$')" \
  "an RFC 2606 example address"

# SSH targets. A hostname a command connects to may well be real
# infrastructure -- security.debian.org, time.apple.com -- and no
# pattern tells that from a borrowed example, so hostnames at
# large are a review matter. The target of an ssh or scp command
# never is: Hostwarden only ever logs into a user's machine. Both
# forms count, with a user and without.
#
# The command word must be followed by whitespace -- a tab
# separates words in a shell as well as a space -- or every
# rules/ssh-*.md reference reads as an invocation. The destination
# may be quoted. A candidate ending in a file extension is a path,
# not a host.
#
# What is left on that suffix list is file extensions only. Two
# came off it: `.example` is a reserved TLD and belongs with the
# other reserved names below, and `.local` is what an internal
# machine is actually called -- excusing it as a file extension
# was excusing exactly the target this check exists to catch. The
# rest are not plausible hostname suffixes in this corpus; a
# hostname that genuinely ends in one is a review matter, which
# is what the comment above says about hostnames at large.
#
# Only a candidate shaped like a network name is examined: this
# corpus is prose, and after the word "ssh" it usually says "key",
# "access" or "user". A dot and a letter suffix is the only thing
# that separates a host from a sentence here, so a single-label
# destination is out of reach -- see the note at the end of this
# check.
#
# Everything up to the *last* `@` is the login, so a dotted
# account name like john.doe@example.com is not read as a host.
report "$(scan \
  | grep -v '^CHANGELOG\.md: ' \
  | tag_i '(^|[^a-z0-9_.-])(ssh|scp|ssh-copy-id)[[:blank:]]+[^|;&`]*' \
  | awk '{ n = 0; out = $1
      # When the command carries a login@host, that is the
      # destination and every other dotted word on the line is an
      # operand -- the local file an scp copies, an option value.
      # Keep only the logins; fall back to the whole line when
      # there is none.
      rest = substr($0, length($1) + 1)
      # An option value is not a destination: -c names a cipher,
      # which in OpenSSH is spelled like a mail address. Only the
      # flags that actually take an argument are consumed, so a
      # bare -v does not swallow the host after it.
      gsub(/-[bcdeefijllmoopqrsww] +[^ ]+/, " ", rest)
      gsub(/[^ ]+=[^ ]+/, " ", rest)
      tmp = rest
      while (match(tmp, /[a-z0-9._%+-]+@[a-z0-9][a-z0-9.-]*/)) {
        out = out " " substr(tmp, RSTART, RLENGTH); n++
        tmp = substr(tmp, RSTART + RLENGTH)
      }
      print (n ? out : $0) }' \
  | tag '[[:blank:]="'"'"']([a-z0-9._%+-]+@)*[a-z0-9][a-z0-9-]*(\.[a-z0-9-]+)+' \
  | sed -E 's#: [[:blank:]="'"'"']#: #; s#: .*@#: #' \
  | grep -E '\.[a-z]{2,}$' \
  | grep -vE '\.(md|conf|service|real|pub|txt|xz|json|ya?ml|log|key|d|bak|gz|img|sock)$' \
  | grep -vE ': ([a-z0-9-]+\.)*example\.(com|net|org)$' \
  | grep -vE ': ([a-z0-9-]+\.)*(test|invalid|example)$' \
  | grep -vE ': localhost$')" "an RFC 2606 example target"

# --- one term for an override -----------------------------------
# .claude/rules/instruction-authoring.md → For people and for the
# agent: what a user writes under memory/custom-rules/ is an
# override. A second word for it reads, to people and agent alike,
# as a second mechanism. CHANGELOG.md keeps what was released
# under the old words, contrib/ speaks Heinzel's language, and the
# two files that state the rule have to name what they retire.
report "$(scan \
  | grep -vE '^(CHANGELOG\.md|contrib/[^ ]*|\.claude/rules/instruction-authoring\.md|\.claude/hooks/instructions-test\.sh): ' \
  | tag_i 'customi[sz]ations?|custom rules?')" "the one term, override"

# --- every .md wraps at 80 -------------------------------------
# .claude/rules/instruction-authoring.md → Layout: a URL or a
# command line that cannot be broken may exceed it. So a fenced
# line is skipped, and a URL or a link target is taken out before
# the rest of its line is measured -- the prose around a link
# still wraps.
#
# Characters, not bytes: an em dash is three bytes, and the awk
# on a CI runner is not the awk on a Mac. The C locale makes every
# awk count bytes, and dropping the UTF-8 continuation bytes first
# turns that into a count of characters on all of them.
report "$(corpus_files | grep '\.md$' | tr '\n' '\0' \
  | LC_ALL=C xargs -0 awk -v root="$CORPUS_ROOT/" "$FENCE_AWK"'
  FNR == 1 { FM = "" }
  fenced($0) { next }
  { s = $0
    gsub(/\]\([^)]*\)/, "]", s)
    gsub(/https?:\/\/[^ )>`]*/, "", s)
    gsub(/[\200-\277]/, "", s)
    if (length(s) > 80) {
      n = FILENAME
      if (index(n, root) == 1) n = substr(n, length(root) + 1)
      print n ":" FNR " (" length(s) ")"
    } }')" "wrapped at 80 characters"

# --- the firewall listing filter has one text -------------------
# rules/secrets.md -> Commands That Leak holds the filter that shows
# a rule's comment as `...`; the probes that run as one call carry a
# copy of it. A copy that drifts withholds less, and nothing in the
# output says so. A copy ends at its closing quote, wherever on the
# line that stands, and one that never closes is a finding too.
report "$(corpus_files | grep '\.md$' | tr '\n' '\0' \
  | xargs -0 awk -v root="$CORPUS_ROOT/" -v ref="$ROOT/rules/secrets.md" '
  function take(l) { sub(/^[ \t]+/, "", l); return l "\n" }
  function closes(l, first) {
    if (first) sub(/^[ \t]*fc=\047/, "", l)
    return index(l, "\047") > 0
  }
  function rel(n) {
    if (index(n, root) == 1) n = substr(n, length(root) + 1)
    return n
  }
  BEGIN {
    while ((getline l < ref) > 0) {
      first = 0
      if (!in_ref && l ~ /^[ \t]*fc=\047/) in_ref = first = 1
      if (in_ref) { want = want take(l); if (closes(l, first)) break }
    }
    close(ref)
    if (want == "") print "rules/secrets.md: no fc filter to compare with"
  }
  FNR == 1 && on { print rel(pf) ":" at ": fc never closes"; on = 0 }
  { pf = FILENAME; first = 0 }
  !on && /^[ \t]*fc=\047/ { on = first = 1; got = ""; at = FNR }
  on { got = got take($0)
    if (closes($0, first)) {
      on = 0
      if (got != want) print rel(FILENAME) ":" at ": fc differs from rules/secrets.md"
    } }
  END { if (on) print rel(pf) ":" at ": fc never closes" }')" \
  "one firewall listing filter"

# --- every required check is a CI job ---------------------------
# The ruleset names the checks a pull request waits for, ci.yml
# names the jobs that report them. Rename one without the other
# and every pull request waits for a check that never comes.
RULESET="$ROOT/.github/rulesets/main.json"
CONTEXTS=$(sed -n 's/.*"context": *"\([^"]*\)".*/\1/p' "$RULESET" 2>/dev/null)
if [ -z "$CONTEXTS" ]; then
  bad "main.json requires no check -- the ruleset is gone or this" \
      "check stopped matching"
else
  # One context per line: a job name may hold spaces.
  while IFS= read -r ctx; do
    # What GitHub reports is a job's `name:` if it has one, else its
    # key; and only under jobs: -- `on:` has two-space keys too.
    if awk '/^jobs:/ { j = 1; next }
        j && /^[^ ]/ { j = 0 }
        j && /^  [A-Za-z0-9_-]+:/ { k = $1; sub(/:$/, "", k); ctx[k] = k }
        j && k && /^    name:/ { n = $0; sub(/^    name: */, "", n)
                                gsub(/["\047]/, "", n); ctx[k] = n }
        END { for (k in ctx) print ctx[k] }' \
        "$ROOT/.github/workflows/ci.yml" | grep -qxF "$ctx"; then
      ok
    else
      bad "main.json requires check '$ctx', which no job in" \
        "ci.yml reports"
    fi
  done <<EOF
$CONTEXTS
EOF
fi

# --- appliance files hold to their contract ---------------------
# An appliance file is read on top of its family file the way an
# override is (rules/os-detection.md -> Layers). A `Replace:` or
# `Remove:` that names nothing in the base takes nothing out, and the
# family's advice then stands where it is wrong; detection reaches
# only the files the marker table of rules/first-detection.md
# lists. Whether the Base file exists is the pointer check's job
# above.
report "$(awk -v root="$ROOT/" -v table="$ROOT/rules/first-detection.md" \
  "$LOAD_AWK"'
  function done() {
    if (rel == "") return
    if (!based) print rel ": no Base line"
    else if (!hw) print rel ": no Hardware: vendor or any line under Base"
    if (!ha) print rel ": no ## Housekeeping and Audits section"
  }
  function body(p, sec,   l, h, on, t) {
    if ((p, sec) in BODY) return BODY[p, sec]
    while ((getline l < p) > 0) {
      if (l ~ /^## /) { h = l; sub(/^## +/, "", h); on = (h == sec); continue }
      if (on) t = t "\n" l
    }
    close(p); return BODY[p, sec] = t
  }
  function text(p,   l, t) {
    if (p in RAW) return RAW[p]
    while ((getline l < p) > 0) t = t "\n" l
    close(p); return RAW[p] = t
  }
  FNR == 1 {
    done(); FM = ""; based = ha = hw = hwline = 0; base = ""
    rel = substr(FILENAME, length(root) + 1)
    if (!index(text(table), "`" rel "`"))
      print rel ": not in the marker table of rules/first-detection.md"
  }
  fenced($0) { next }
  FNR == hwline && /^Hardware: (vendor|any)$/ { hw = 1 }
  /^Base: / {
    based = 1; hwline = FNR + 1; b = $2; gsub(/`/, "", b)
    if (b == "none") next
    if (b !~ /^rules\/os\/[a-z0-9-]+\.md$/) print rel ": Base " b " is no family file"
    else base = root b
    next
  }
  $0 == "## Housekeeping and Audits" { ha = 1 }
  /^## (Replace|Remove): / {
    sec = $0; sub(/^## [A-Za-z]+: */, "", sec); entry = ""
    if ((i = index(sec, " > "))) { entry = substr(sec, i + 3); sec = substr(sec, 1, i - 1) }
    if (base == "") { print rel ": " sec " has no base to take it from"; next }
    fm = FM; ok = load(base); FM = fm
    if (!ok) next
    for (i = 1; i <= NH[base]; i++) if (H[base, i] == sec) break
    if (i > NH[base]) print rel ": " sec " is no section of " substr(base, length(root) + 1)
    else if (entry != "" && !index(body(base, sec), entry))
      print rel ": " entry " is no entry of " sec
  }
  END { done() }' "$ROOT"/rules/appliance/*.md)" \
  "an appliance file that fits its base"

# --- platform files hold to theirs -------------------------------
# A platform file applies to whichever family detection found
# (rules/os-detection.md -> Layers), so a `Replace:` or `Remove:`
# may only name a section that every family file has; one only some
# have takes nothing out on the others, silently.
# The family list goes in through the environment: awk -v rejects a
# value with a newline in it.
report "$(FAMILIES="$(printf '%s\n' "$ROOT"/rules/os/*.md)" \
  awk -v root="$ROOT/" -v table="$ROOT/rules/first-detection.md" "$LOAD_AWK"'
  function done() {
    if (rel == "") return
    if (based) print rel ": a Base line, but it has no fixed base"
    if (!ha) print rel ": no ## Housekeeping and Audits section"
  }
  BEGIN {
    nfam = split(ENVIRON["FAMILIES"], F, "\n")
    for (f = 1; f <= nfam; f++)
      if (load(F[f])) for (i = 1; i <= NH[F[f]]; i++)
        if (!((F[f], H[F[f], i]) in SEEN)) { SEEN[F[f], H[F[f], i]]; N[H[F[f], i]]++ }
    while ((getline l < table) > 0) t = t "\n" l
    close(table)
  }
  FNR == 1 {
    done(); FM = ""; based = ha = 0
    rel = substr(FILENAME, length(root) + 1)
    if (!index(t, "`" rel "`"))
      print rel ": not in the marker table of rules/first-detection.md"
  }
  fenced($0) { next }
  /^Base: / { based = 1 }
  $0 == "## Housekeeping and Audits" { ha = 1 }
  /^## (Replace|Remove): / {
    sec = $0; sub(/^## [A-Za-z]+: */, "", sec)
    if ((i = index(sec, " > "))) sec = substr(sec, 1, i - 1)
    if (N[sec] != nfam) print rel ": " sec " is not a section of every family file"
  }
  END { done() }' "$ROOT"/rules/platform/*.md)" \
  "a platform file that fits every family"

# --- the ignore rules keep personal files out, and only those -----
# .gitignore ignores all of .claude/ but the shared configuration.
# Both directions fail silently otherwise: a tracked file the rules
# match is shared configuration someone forgot to un-ignore, and a
# personal file that stops matching is one `git add` from a public
# repo.
# The repository's own .gitignore files only: --exclude-standard
# would add .git/info/exclude and the contributor's global excludes,
# and a personal `.claude/` there must not fail this check.
TRACKED_IGNORED=$(git -C "$ROOT" ls-files -ci \
  --exclude-per-directory=.gitignore)
report "$TRACKED_IGNORED" "a tracked file, yet the ignore rules match it"
# The other direction the same way. check-ignore always reads
# info/exclude and the global excludes, where the same `.claude/`
# would stand in for a rule .gitignore has lost, so it asks an
# empty repository holding nothing but .gitignore.
IGN=$(mktemp -d)
git init -q --template= "$IGN" && cp "$ROOT/.gitignore" "$IGN/"
for p in .claude/settings.local.json .claude/worktrees/x \
         .claude/scheduled_tasks.json .claude/agent-memory-local/x \
         .claude/x.lock CLAUDE.local.md memory/user.md; do
  if git -C "$IGN" -c core.excludesFile=/dev/null check-ignore -q "$p"; then
    ok
  else
    bad ".gitignore no longer ignores $p"
  fi
done
rm -rf "$IGN"

echo "instruction layout tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
