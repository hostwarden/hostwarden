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

# What opens or closes a fenced block. Inside one, a `#` line is a
# shell comment rather than a heading, and a long line is a command
# rather than prose -- the wrap check below reads it too.
FENCE_RE='^[ \t]*(```|~~~)'

# load(path) -- awk, for the two checks below: reads the ATX
# headings of a Markdown file once into H[path, 1..NH[path]] and
# returns whether the file could be read. Each target is named by
# dozens of pointers; reading it once per pointer tripled the
# runtime of this file.
LOAD_AWK='
function load(p,   l, fence, h) {
  if (p in NH) return NH[p] >= 0
  NH[p] = -1
  if ((getline l < p) <= 0) return 0
  NH[p] = 0
  do {
    if (l ~ FENCE) { fence = !fence; continue }
    if (!fence && l ~ /^#+[ \t]/) {
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
# own directory. Someone else's README ("its README", "heinzel's
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
  | awk -v sep="$SEP" -v root="$ROOT/" -v FENCE="$FENCE_RE" "$LOAD_AWK"'
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
# spaces to `-`, a repeat numbered from -1. A dead anchor still
# opens the page, at the top, which is why nobody notices.
report "$(scan \
  | grep -E '^((README|CONTRIBUTING|SECURITY)\.md|docs/[^/]*\.md): ' \
  | tag '\]\([^):[:space:]]*#[^)[:space:]]+\)' \
  | sed -E 's#^([^ ]+): \]\(([^#]*)\#(.*)\)$#\1|\2|\3#' \
  | LC_ALL=C awk -F'|' -v root="$ROOT/" -v FENCE="$FENCE_RE" "$LOAD_AWK"'
    {
      f = $1; dir = f; sub(/[^\/]*$/, "", dir)
      p = root ($2 == "" ? f : dir $2)
      if (!load(p)) { print f ": " $2 " (no such file)"; next }
      if (!(p in SLUGGED)) {
        SLUGGED[p] = 1
        for (i = 1; i <= NH[p]; i++) {
          s = tolower(H[p, i])
          gsub(/\342\200[\223\224]/, "", s)
          gsub(/[^a-z0-9 _\200-\377-]/, "", s)
          gsub(/ /, "-", s)
          n = SEEN[p, s]++
          SLUG[p, n ? s "-" n : s] = 1
        }
      }
      if (!((p, $3) in SLUG)) print f ": " $2 "#" $3 }')" \
  "an anchor GitHub renders"

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
report "$(scan \
  | sed -E 's#([[:space:]])[vV]ersion [0-9]+(\.[0-9]+)+#\1#g
            s#([[:space:]])v[0-9]+(\.[0-9]+)+#\1#g' \
  | tag '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' \
  | grep -vE ': (192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)' \
  | grep -vE ': (127\.|10\.|192\.168\.|169\.254\.|0\.0\.0\.0)' \
  | grep -vE ': 172\.(1[6-9]|2[0-9]|3[01])\.' \
  | grep -vE ': 255\.')" "an RFC 5737 documentation address"

# IPv6. Only 2001:db8::/32 is documentation space (RFC 3849).
# Matching every colon-hex string would catch timestamps and MAC
# addresses, so this looks for the global-unicast shape, including
# the compressed forms that end in `::` -- which is why `tag`
# splits on `: ` and not on a final colon.
report "$(scan \
  | tag_i '\b[23][0-9a-f]{3}:[0-9a-f]*(:[0-9a-f]*)+' \
  | grep -vE ': 2001:0?db8:')" "an RFC 3849 documentation address"

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
  | LC_ALL=C xargs -0 awk -v root="$CORPUS_ROOT/" -v FENCE="$FENCE_RE" '
  FNR == 1 { fence = 0 }
  $0 ~ FENCE { fence = !fence; next }
  fence { next }
  { s = $0
    gsub(/\]\([^)]*\)/, "]", s)
    gsub(/https?:\/\/[^ )>`]*/, "", s)
    gsub(/[\200-\277]/, "", s)
    if (length(s) > 80) {
      n = FILENAME
      if (index(n, root) == 1) n = substr(n, length(root) + 1)
      print n ":" FNR " (" length(s) ")"
    } }')" "wrapped at 80 characters"

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
for p in .claude/settings.local.json .claude/worktrees/x \
         .claude/scheduled_tasks.json .claude/agent-memory-local/x \
         .claude/x.lock CLAUDE.local.md memory/user.md; do
  if git -C "$ROOT" check-ignore -q "$p"; then
    ok
  else
    bad ".gitignore no longer ignores $p"
  fi
done

echo "instruction layout tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
