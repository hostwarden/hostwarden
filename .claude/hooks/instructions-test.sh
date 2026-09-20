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



# --- the corpus still covers the tree --------------------------
# A path that falls out of CORPUS_PATHS does not fail anything on
# its own: the scans simply stop reaching it and keep reporting
# success, which is indistinguishable from there being nothing
# wrong. So every tracked entry at the repository root and under
# .claude/ has to be named by one list or the other.
COVERED=0
# Both lists span several lines; flatten them so a name at the
# start of a line is still surrounded by spaces to match against.
KNOWN=" $(printf '%s %s' "$CORPUS_PATHS" "$CORPUS_EXEMPT" \
  | tr '\n' ' ') "
# From the index, not from HEAD: this file tells you to run it
# before committing, and a newly staged directory is invisible to
# a tree-ish. Cut to the first path segment, and to two under
# .claude/, to get the same entries a directory listing would.
for e in $(git -C "$ROOT" ls-files \
             | sed -E 's#^(\.claude/[^/]+|[^/]+).*#\1#' \
             | LC_ALL=C sort -u); do
  case "$KNOWN" in
    *" $e "*) continue ;;
  esac
  [ "$e" = ".claude" ] && continue
  bad "$e is in neither CORPUS_PATHS nor CORPUS_EXEMPT --" \
      "decide whether the instruction scans should read it"
  COVERED=1
done
[ "$COVERED" -eq 0 ] && ok

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
# destination does not exist relocates a customization to a path
# nothing reads -- the exact failure the table exists to prevent.
MIGRATE="$ROOT/bin/hostwarden-migrate"
if [ -f "$MIGRATE" ]; then
  BAD_MAP=$(
    sed -n "/^MAP='/,/'\$/p" "$MIGRATE" \
      | sed "s/^MAP='//; s/'\$//" \
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
# have been read simply is not, and nothing says so. Three more
# shapes of pointer exist, so three more checks.

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
report "$(printf '%s\n' "$SCAN" \
  | grep -v '^CHANGELOG\.md: ' \
  | grep -oE '^[^ ]+:|(^|[^a-z0-9/_.-])rules/[a-z0-9/_-]+\.md' \
  | sed -E 's#^[^a-z0-9/_.-]rules/#rules/#' \
  | awk '/:$/ { f = $0; next } { print f " " $0 }' \
  | while IFS=' ' read -r f r; do
      [ -f "$ROOT/$r" ] || echo "$f $r"
    done)" "a rule file that exists"

# Skills and subagents named in prose. Several rules point at
# one by name rather than by path, which a rename breaks without
# a trace. bin/hostwarden-* are scripts, not either.
report "$(printf '%s\n' "$SCAN" \
  | grep -v '^CHANGELOG\.md: ' \
  | grep -oE '^[^ ]+:|`hostwarden-[a-z-]+`' \
  | awk '/:$/ { f = $0; next } { print f " " $0 }' \
  | tr -d '`' \
  | grep -vE ' hostwarden-(migrate|update|backup)$' \
  | while IFS=' ' read -r f s; do
      [ -d "$ROOT/.agents/skills/$s" ] && continue
      [ -f "$CLAUDE_DIR/agents/$s.md" ] && continue
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
  | sed -E 's#([[:space:]])[vV]ersion [0-9]+(\.[0-9]+)+#\1#g
            s#([[:space:]])v[0-9]+(\.[0-9]+)+#\1#g' \
  | grep -oE '^[^ ]+:|\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' \
  | awk '/:$/ { f = $0; next } { print f " " $0 }' \
  | grep -vE ': (192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)' \
  | grep -vE ': (127\.|10\.|192\.168\.|169\.254\.|0\.0\.0\.0)' \
  | grep -vE ': 172\.(1[6-9]|2[0-9]|3[01])\.' \
  | grep -vE ': 255\.')" "an RFC 5737 documentation address"

# IPv6. Only 2001:db8::/32 is documentation space (RFC 3849).
# Matching every colon-hex string would catch timestamps and MAC
# addresses, so this looks for the global-unicast shape, including
# the compressed forms that end in `::`.
#
# The file prefix carries its trailing space here, and awk splits
# on `: ` rather than on a final colon: an address ending in `::`
# ends in a colon too, so the plain test read it as a filename and
# dropped it -- the one shape this check has to catch.
report "$(printf '%s\n' "$SCAN" \
  | grep -oiE '^[^ ]+: |\b[23][0-9a-f]{3}:[0-9a-f]*(:[0-9a-f]*)+' \
  | awk '/: $/ { f = $0; next } { print f $0 }' \
  | grep -viE ': 2001:0?db8:')" "an RFC 3849 documentation address"

# Mail addresses outside the reserved domains. Domain names are
# case-insensitive, so the comparison is too -- alice@Example.COM
# is the same example as alice@example.com and must not fail.
#
# openssh.com is exempt only where it does what it does in this
# corpus: suffix an algorithm name (umac-64-etm@openssh.com). A
# local part with no hyphen names a person, and an address of
# that shape at that domain is borrowed like any other.
report "$(printf '%s\n' "$SCAN" \
  | grep -oiE '^[^ ]+:|[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' \
  | awk '/:$/ { f = $0; next } { print f " " tolower($0) }' \
  | grep -vE '@(.*\.)?example\.(com|net|org)$' \
  | grep -vE '@([a-z0-9-]+\.)*(test|invalid)$' \
  | grep -vE ' [a-z0-9]+(-[a-z0-9]+)+@openssh\.com$')" \
  "an RFC 2606 example address"

# SSH targets. A hostname a command connects to may well be real
# infrastructure -- security.debian.org, time.apple.com -- and no
# pattern tells that from a borrowed example, so hostnames at
# large are a review matter. The target of an ssh or scp command
# never is: hostwarden only ever logs into a user's machine. Both
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
report "$(printf '%s\n' "$SCAN" \
  | grep -v '^CHANGELOG\.md: ' \
  | grep -oiE '^[^ ]+:|(^|[^a-z0-9_.-])(ssh|scp|ssh-copy-id)[[:blank:]]+[^|;&`]*' \
  | awk '/:$/ { f = $0; next } { print f " " tolower($0) }' \
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
  | grep -oiE '^[^ ]+:|[[:blank:]="'"'"']([a-z0-9._%+-]+@)*[a-z0-9][a-z0-9-]*(\.[a-z0-9-]+)+' \
  | awk '/:$/ { f = $0; next } { print f " " $0 }' \
  | sed -E 's#: [[:blank:]="'"'"']#: #; s#: .*@#: #' \
  | grep -E '\.[a-z]{2,}$' \
  | grep -vE '\.(md|conf|service|real|pub|txt|xz|json|ya?ml|log|key|d|bak|gz|img|sock)$' \
  | grep -vE ': ([a-z0-9-]+\.)*example\.(com|net|org)$' \
  | grep -vE ': ([a-z0-9-]+\.)*(test|invalid|example)$' \
  | grep -vE ': localhost$')" "an RFC 2606 example target"

echo "instruction layout tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
