#!/bin/sh
# review-tier.sh — the tier of a change, light or full, from the
# files it touches, as .claude/rules/pull-requests.md → The own
# review says. The own review's tier and the review record's fix
# line both read it here. LIGHT below is the rule's light list,
# word for word; tests/scripts/review-record.sh fails when the two differ.
#
#   sh scripts/review-tier.sh <old> [<new>]
#
# What `git diff` takes: a range such as `hostwarden/main...HEAD`
# alone, or two commits, whose trees it compares. Prints `light`,
# or `full` and then each file that made it full, one a line. A
# rename counts both its names, so moving a script into docs/ is
# full. Exits 0 with the tier, 1 when git cannot read the commits,
# 2 on a usage error.

# A directory ends in `/` and holds everything below it, a new
# file included; any other entry is one file. The rule file itself
# is never light, so a change to the review is reviewed in full.
LIGHT='docs/ README.md CONTRIBUTING.md SECURITY.md CHANGELOG.md changelog.d/ .claude/rules/'
NEVER=.claude/rules/pull-requests.md

usage() {
  echo "usage: sh scripts/review-tier.sh <old> [<new>]" >&2
  exit 2
}
case $# in 1 | 2) ;; *) usage ;; esac
for a; do case $a in '' | -*) usage ;; esac; done

light() {
  [ "$1" != "$NEVER" ] || return 1
  for l in $LIGHT; do
    case $l in
      */) case $1 in "$l"*) return 0 ;; esac ;;
      "$1") return 0 ;;
    esac
  done
  return 1
}

# Only the names are read: no blob, no diff driver, no textconv.
# A name git still quotes — one with a quote, a backslash or a
# control character — starts with `"` and so counts as full.
files=$(git -c core.quotePath=false diff --no-ext-diff --no-textconv \
  --no-renames --name-only "$@" --) || exit 1

full=
while IFS= read -r f; do
  [ -z "$f" ] || light "$f" || full="$full$f
"
done <<EOF
$files
EOF

if [ -z "$full" ]; then
  echo light
else
  echo full
  printf '%s' "$full"
fi
