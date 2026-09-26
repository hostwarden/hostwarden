# tests/instructions/pointers.sh — override paths and every pointer
# between instruction files. Sourced by tests/instructions.sh, in
# its order, into the one shell every part shares; never run on its
# own.
# shellcheck shell=sh

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
# CHANGELOG.md and the fragments in changelog.d/ that become it
# are out of scope, and so are the decision records in docs/adr/.
# They record what was true on a date -- the release rule in
# `.claude/rules/` says so -- which means they name paths, skills
# and terms that later moved or were retired, by design.
HISTORY='^(CHANGELOG\.md|changelog\.d/[^ ]*|docs/adr/[^ ]*): '
report "$(scan \
  | grep -vE "$HISTORY" \
  | tag '(^|[^a-z0-9/_.-])rules/[a-z0-9/_-]+\.md' \
  | sed -E 's#^([^ ]+:) [^a-z0-9/_.-]?rules/#\1 rules/#' \
  | while IFS=' ' read -r f r; do
      [ -f "$ROOT/$r" ] || echo "$f $r"
    done)" "a rule file that exists"

# Skills and subagents named in prose. Several rules point at
# one by name rather than by path, which a rename breaks without
# a trace. A script in bin/ is neither and counts as existing, and
# so does hostwarden-workspace, the repository name
# website/docs/running-it/team/shared-workspace.md recommends for the
# workspace remote.
report "$(scan \
  | grep -vE "$HISTORY" \
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

# load(path) -- awk, for the checks below: reads the ATX headings
# of a Markdown file once into H[path, 1..NH[path]] and returns
# whether the file could be read. Each target is named by dozens
# of pointers; reading it once per pointer tripled the runtime of
# this file. A heading inside an HTML comment renders as nothing,
# so a section parked in one has no anchor either.
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
}
# ensure_slugs(p) -- awk: fills SLUG[p, <slug>] with every anchor
# GitHub, or Docusaurus, derives from a loaded page'"'"'s headings --
# the shared half of the two anchor checks below, which differ
# only in how they resolve a link to the page p. load(p) must have
# already run. Memoised the same way load() is, and for the same
# reason: a page linked from several places is sluggged once.
function ensure_slugs(p,   i, s, t, c, b) {
  if (p in SLUGGED) return
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
}'

# Headings named in prose: `AGENTS.md` → SSH Options,
# `rules/dns-aliases.md` § Detection, and the ASCII spelling
# `AGENTS.md - Critical Safety Rules` a hook's printf uses. A renamed heading leaves every one of them pointing at a
# section the reader then cannot find, and nothing says so.
#
# Such a pointer wraps wherever the sentence does, often between
# the filename and the arrow, or between the arrow and the heading,
# and a comment or an echo line wraps without the backslash the
# scan joins on. So every line that names a file is read together
# with the lines of its own paragraph that follow it, minus the
# comment marker or the echo that opens each one -- a joined pointer
# that names a quoted heading can run past the very next line, as
# `.agents/skills/hostwarden-os-install/references/partition-staging.md`
# does. A separator marks each seam.
#
# A seam can fall right where the pattern expects only blanks --
# between a closing backtick and the arrow -- and a wrap there is
# an arrow or a section sign starting the next line, never the
# ASCII " - " spelling: that three-character run also opens a
# Markdown list item, and a bullet that merely follows a paragraph
# naming some other file is not a pointer at it. So crossing a seam
# takes its own branch, arrow or section sign only, rather than
# widening the blank class itself, which would let the same three
# characters match a list item across the seam as if it were the
# ASCII arrow. Once that branch has matched, the rest of the
# pattern is `.*`, which does not care how many further seams the
# rest of the paragraph holds.
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
PTR_RE="(^|[^A-Za-z0-9_./<>-])(its |[A-Za-z]+'s )?\`?([A-Za-z0-9_./-]*[A-Za-z0-9_-]\\.md|README)\`?[[:blank:]]*((${SEP}[[:blank:]]*)?(→|§)| - ).*"
POINTERS=$(scan \
  | grep -vE "$HISTORY" \
  | awk -v sep="$SEP" '
    { line[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        c = index(line[i], ": "); f = substr(line[i], 1, c - 1)
        t = substr(line[i], c + 2)
        if (!(index(t, ".md") || index(t, "README"))) continue
        joined = t
        for (j = i + 1; j <= NR; j++) {
          c2 = index(line[j], ": "); f2 = substr(line[j], 1, c2 - 1)
          if (f2 != f) break
          n = substr(line[j], c2 + 2)
          if (n ~ /^[ \t]*$/) break
          sub(/^[ \t]*(#+|\/\/)?[ \t]*((echo|printf)[ \t]+)?["\047]?/, "", n)
          joined = joined sep " " n
        }
        print f ": " joined
      }
    }' \
  | tag "$PTR_RE")
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
      ensure_slugs(p)
      if (!((p, $3) in SLUG)) print f ": " $2 "#" $3 }')" \
  "an anchor GitHub renders"

# The same, for a link that names the page by an absolute
# https://hostwarden.github.io/docs/... URL instead of a relative
# path -- the shape README.md and CONTRIBUTING.md use to reach
# website/docs/, which stays out of a relative reach from either
# file's own top-level directory. The corpus-wide gsub at the top
# of this file strips a URL's scheme and host from $SCAN before any
# check reads it, which is right for the identifier checks below
# but throws away exactly the text the check above matches on, so
# an anchor written this way never reaches it. This one reads the
# corpus fresh -- unstripped -- for that one reason, and resolves
# the path GitHub Pages serves against the website/docs/ file that
# actually holds it, slugging it the same way.
#
# CHANGELOG.md and docs/adr/*.md are historical and excluded the
# same way the pointer check above excludes them ($HISTORY):
# a record from before a page moved names where it lived then.
UNSTRIPPED=$(corpus_files | tr '\n' '\0' \
  | xargs -0 awk -v root="$CORPUS_ROOT/" '
  { n = FILENAME
    if (index(n, root) == 1) n = substr(n, length(root) + 1)
    print n ": " $0 }')
GH_URL_RE='https://hostwarden\.github\.io/docs/[a-z0-9/_-]+#[a-z0-9_-]+'
report "$(printf '%s\n' "$UNSTRIPPED" \
  | grep -vE "$HISTORY" \
  | awk "$FENCE_AWK"'
    { f = $0; sub(/: .*/, "", f)
      if (f != last) { FM = CM = ""; last = f }
      t = $0; sub(/^[^ ]+: /, "", t)
      if (!commented(t) && !fenced(t)) print }' \
  | tag "$GH_URL_RE" \
  | sed -E 's@^([^ ]+): https://hostwarden\.github\.io/docs/([a-z0-9/_-]+)#([a-z0-9_-]+)$@\1|\2|\3@' \
  | LC_ALL=C awk -F'|' -v root="$ROOT/" "$LOAD_AWK"'
    {
      f = $1; path = $2; anchor = $3
      p = root "website/docs/" path ".md"
      if (!load(p)) { print f ": " path "#" anchor " (no such file)"; next }
      ensure_slugs(p)
      if (!((p, anchor) in SLUG)) print f ": " path "#" anchor }')" \
  "an anchor the docs site renders"

# Every page under docs/, subdirectories included, is listed in its
# index. The README points there instead of keeping a list of its
# own, so a page the index leaves out is a page no link reaches.
# The records in docs/adr/ are listed in docs/adr/README.md, which
# scripts/decisions.py generates and checks, and which is listed
# here like any other page.
UNLISTED=$(cd "$ROOT/docs" && find . -name '*.md' ! -path ./README.md \
  ! -path './adr/[0-9]*' \
  | sed 's#^\./##' | sort | while read -r n; do
    grep -qF -e "]($n)" -e "]($n#" -e "]($n " README.md \
      || echo "docs/$n"
  done)
report "$UNLISTED" "listed in docs/README.md"
