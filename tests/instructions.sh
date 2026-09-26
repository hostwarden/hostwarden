#!/bin/sh
# tests/instructions.sh — dev-only structural checks on the
# instruction layer. CI runs it through scripts/check.sh, and
# `check.sh --pre-commit` on what is staged
# (.claude/rules/pull-requests.md → Checks). Not invoked by Claude
# Code at runtime.
#
# What the content of an instruction says is a matter of judgement.
# Where it lives is not, and neither is whether the mechanism that
# loads it still points at it. That is what this file asserts.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC2034 # read by the parts in instructions/
ROOT=$REPO CLAUDE_DIR="$REPO/.claude"
# shellcheck source=helpers.sh
. "$REPO/tests/helpers.sh"
# shellcheck source=corpus.sh
. "$REPO/tests/corpus.sh"

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

# The checks, one file per kind, in this order.
for part in settings skills pointers examples layout; do
  # shellcheck source=/dev/null
  . "$REPO/tests/instructions/$part.sh"
done

finish "instruction layout tests"
