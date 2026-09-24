#!/bin/sh
# changelog-release.sh — fold the changelog fragments into
# CHANGELOG.md for the release VERSION names.
#
# Usage:
#   sh scripts/changelog-release.sh          Fold changelog.d/*.md
#                                            into a new section
#                                            of CHANGELOG.md and
#                                            delete them
#   sh scripts/changelog-release.sh --check  Check the fragments'
#                                            form, change nothing
#   sh scripts/changelog-release.sh --help   Show this help
#
# Run it after bumping VERSION, smooth the wording of the new
# section, and commit the three together: the bump, CHANGELOG.md
# and the deleted fragments (.claude/rules/repo-release.md →
# CHANGELOG.md). A `## Unreleased` section still in CHANGELOG.md
# becomes the new section, and the fragments' entries follow it.
# Run again after a rebase, it adds what merged since to the
# section it wrote, as long as no tag names the release yet.
set -e

cd "$(dirname "$0")/.."

# Keep a Changelog's sections, in its order.
SECTIONS="Added Changed Deprecated Removed Fixed Security"

usage() {
  awk 'NR == 1 { next } /^[^#]/ { exit } { sub(/^# ?/, ""); print }' \
    scripts/changelog-release.sh
}

# Fragment names are a date and a slug, which carry no space.
FRAGS=$(for f in changelog.d/*.md; do
  [ ! -e "$f" ] || printf '%s\n' "$f"
done)

# check [fold] — every fragment is one or more `### <Section>` headings,
# each followed by entries; an entry starts with "- **", its lead
# clause closes with "**" before a blank line, and its further
# lines indent by two spaces. No code block: a command quoted as
# history would meet the guard matrix, which exempts only
# CHANGELOG.md.
check() {
  rc=0
  fold=${1:-}
  # A file the glob above does not see would never be folded.
  # No changelog.d/ at all is the state every release leaves.
  STRAY=
  [ ! -d changelog.d ] || STRAY=$(find changelog.d -type f \
    \( -path 'changelog.d/*/*' -o ! -name '*.md' \))
  if [ -n "$STRAY" ]; then
    # shellcheck disable=SC2086 # one argument per file
    printf '%s: a fragment is changelog.d/<date>-<slug>.md\n' \
      $STRAY >&2
    rc=1
  fi
  if [ -z "$fold" ]; then
    for f in $(left_out); do
      echo "$f: older than the bump to $VERSION, and left out of its" \
        "section: run the fold again" >&2
      rc=1
    done
  fi
  [ -n "$FRAGS" ] || return $rc
  for f in $FRAGS; do
    [ -s "$f" ] || { echo "$f: empty" >&2; rc=1; }
  done
  # shellcheck disable=SC2086 # one argument per fragment
  awk -v secs="$SECTIONS" '
    function bad(m) {
      print FILENAME ":" FNR ": " m > "/dev/stderr"; rc = 1
    }
    function close_lead() {
      if (open) {
        print file ":" open ": the lead clause never closes with **" \
          > "/dev/stderr"; rc = 1
      }
      open = 0
    }
    function close_sec() {
      close_lead()
      if (sec != "" && !n) {
        print file ": ### " sec " has no entry" > "/dev/stderr"; rc = 1
      }
    }
    FNR == 1 { close_sec(); file = FILENAME; sec = ""; n = 0 }
    !NF { close_lead(); next }
    /^### / {
      close_sec(); sec = substr($0, 5); n = 0
      if (index(" " secs " ", " " sec " ") == 0 || sec ~ / /)
        bad("\"" sec "\" is none of: " secs)
      next
    }
    sec == "" { bad("text before the first ### heading"); next }
    /^[ \t]*(```|~~~)/ { bad("an entry is prose, without a code block"); next }
    /^- \*\*[^*]/ {
      close_lead(); n++
      if (!index(substr($0, 6), "**")) open = FNR
      next
    }
    /^  [^ ]/ && n { if (index($0, "**")) open = 0; next }
    { bad("an entry starts with \"- **\", and its further lines" \
        " indent by two spaces") }
    END { close_sec(); exit rc }
  ' $FRAGS || rc=1
  return $rc
}

VERSION=$(cat VERSION 2>/dev/null || true)
# The heading of VERSION's section, or nothing.
section() { grep -E "^## \[?$VERSION\]?( |$)" CHANGELOG.md | head -n 1; }
# released_untagged — true when VERSION's section is written and no
# tag names it yet: the release pull request, before it merges.
released_untagged() {
  [ -n "$(section)" ] && ! git rev-parse -q --verify "refs/tags/v$VERSION" \
    >/dev/null
}
# left_out — the fragments a release not tagged yet left out: those
# committed before the commit that bumped VERSION, which a rebase
# of the release pull request brings in. One committed after the
# bump, a pull request queued behind the release, ships after it.
left_out() {
  [ -n "$FRAGS" ] && released_untagged || return 0
  BUMP=$(git log -1 --format=%H -- VERSION 2>/dev/null) || return 0
  [ -n "$BUMP" ] || return 0
  for f in $FRAGS; do
    ADDED=$(git log -1 --diff-filter=A --format=%H -- "$f" 2>/dev/null)
    [ -n "$ADDED" ] && [ "$ADDED" != "$BUMP" ] &&
      git merge-base --is-ancestor "$ADDED" "$BUMP" 2>/dev/null &&
      printf '%s\n' "$f"
  done
  return 0
}

case "${1:-}" in
--help | -h) usage; exit 0 ;;
--check) check; exit ;;
"") ;;
*) usage >&2; exit 1 ;;
esac

if ! printf '%s\n' "$VERSION" | grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+'; then
  echo "VERSION is no X.Y.Z: $VERSION" >&2
  exit 1
fi
# A release pull request folds again after each rebase: the section
# it already wrote takes what merged since.
TARGET='## Unreleased'
if [ -n "$(section)" ]; then
  if ! released_untagged; then
    echo "CHANGELOG.md already has a section for $VERSION;" \
      "bump VERSION first" >&2
    exit 1
  fi
  TARGET=$(section)
fi
check fold || { echo "fix the fragments above first" >&2; exit 1; }
if [ -z "$FRAGS" ] && { [ "$TARGET" != '## Unreleased' ] ||
  ! grep -qxF "$TARGET" CHANGELOG.md; }; then
  echo "changelog.d/ has no fragment, and CHANGELOG.md no" \
    "## Unreleased: nothing to fold" >&2
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-changelog.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

# The entries of every fragment, blank lines dropped, grouped by
# section in Keep a Changelog's order.
: > "$TMP/block"
# shellcheck disable=SC2086 # one argument per fragment
[ -z "$FRAGS" ] || awk -v secs="$SECTIONS" '
  /^### / { sec = substr($0, 5); next }
  NF { e[sec] = e[sec] $0 "\n" }
  END {
    n = split(secs, order, " ")
    for (i = 1; i <= n; i++) {
      if (!(order[i] in e)) continue
      if (out) printf "\n"
      printf "### %s\n\n%s", order[i], e[order[i]]; out = 1
    }
  }
' $FRAGS > "$TMP/block"

# The new section takes the place of `## Unreleased`, or goes
# above the newest release; the entries end it, or end the section
# a first fold of this release wrote.
awk -v head="## $VERSION - $(date -u +%Y-%m-%d)" -v target="$TARGET" \
  -v blockf="$TMP/block" '
  # block <more> — the entries, after a blank line; another one
  # after them when more of the file follows.
  function block(more,   l, any) {
    while ((getline l < blockf) > 0) {
      if (!any && !blank) print ""
      print l; any = 1
    }
    close(blockf)
    if (any && more) print ""
  }
  state == 0 && $0 == target {
    print (target == "## Unreleased" ? head : $0); state = 1; blank = 0
    next
  }
  state == 0 && /^## / { print head; blank = 0; block(1); state = 2 }
  state == 1 && /^## / { block(1); state = 2 }
  { print; blank = !NF }
  END {
    if (state == 0) {
      if (NR && !blank) print ""
      print head; blank = 0; block(0)
    } else if (state == 1) block(0)
  }
' CHANGELOG.md > "$TMP/CHANGELOG.md"
cat "$TMP/CHANGELOG.md" > CHANGELOG.md

N=$(printf '%s' "$FRAGS" | grep -c . || true)
if [ -n "$FRAGS" ]; then
  # shellcheck disable=SC2086 # one argument per fragment
  git rm -q -f --ignore-unmatch -- $FRAGS
  # shellcheck disable=SC2086
  rm -f -- $FRAGS
fi
echo "CHANGELOG.md: section $VERSION from $N fragment(s)."
echo "Smooth its wording, then commit it with VERSION and the"
echo "deleted fragments in one commit."
