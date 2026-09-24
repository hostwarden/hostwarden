#!/bin/sh
# review-record.sh — whether a pull request body records the second
# review of its head, as .claude/rules/pull-requests.md → The review
# record says.
#
#   sh scripts/review-record.sh <head sha> < <body>
#
# Exits 0 when the record is there, 1 with what is missing, 2 on a
# usage error. It proves the record exists, not that the review was
# any good. The review-record workflow runs it, the default
# branch's copy, on a pull request that is not a draft.

[ $# -eq 1 ] && printf '%s\n' "$1" | grep -qxE '[0-9a-f]{40}' || {
  echo "usage: sh scripts/review-record.sh <full head sha> < <body>" >&2
  exit 2
}
HEAD_SHA=$1

# A body edited in the browser arrives with CRLF line ends.
BODY=$(tr -d '\r')

# section <heading> -- the lines under one `## ` heading, up to the
# next heading of level one or two, each without a list marker. A
# fenced block is an example: a heading in it is none, and it ends
# no section.
section() {
  printf '%s\n' "$BODY" | awk -v h="$1" '
    /^[ \t]*(```|~~~)/ { f = !f; next }
    f { next }
    /^##? / { t = $0; sub(/[ \t]+$/, "", t); on = (t == h); next }
    on' | sed -E 's/^[[:space:]]*([-*][[:space:]]+)?//'
}

REVIEW=$(section '## Review')
SKIP=$(section '## Second review skipped')

fail=
missing() { echo "review record: $*"; fail=1; }

# The heads a run or a skip names, each where its line puts it: a
# run's `<reviewer> <model> <effort>, <where>, <sha>: <k> findings,
# <left>…`, a skip's `<sha>: <reason>, resets <time>; <who>
# decided`.
SHAPE='^[^,]+, ([^,]+), ([0-9a-f]{40}): (no findings|1 finding|[0-9]+ findings)'
RUN="$SHAPE, [^ ]"
RUNS=$(printf '%s\n' "$REVIEW" | sed -nE "s/$RUN.*$/\\2/p")
SKIPS=$(printf '%s\n' "$SKIP" \
  | sed -nE 's/^([0-9a-f]{40}): .+, resets [^;]+; .+ decided[[:space:]]*$/\1/p')

# A local run's line carries one answer per finding, a clause
# `<title> (<path:line>): class <n>, <answer>` each, told apart by
# title and place: the line is cut after each answer, and a clause
# starts after the last `; `, `. ` or ` — ` before its place. A
# GitHub run's answers are its threads, which this does not read.
PLACE='\([^()]*:[0-9]+(-[0-9]+)?\): class [0-9]+(/[0-9]+)*, '
ANSWER='(fixed in `?[0-9a-f]{7,40}|not a bug: |deferred to a follow-up PR)'
while IFS= read -r line; do
  run=$(printf '%s\n' "$line" | sed -nE "s/$SHAPE.*$/\\1 \\2 \\3/p")
  [ -n "$run" ] || continue
  # shellcheck disable=SC2086 # three words, none with a blank
  set -- $run
  # A run line short of its shape is a run all the same: its
  # findings still want their answers.
  printf '%s\n' "$line" | grep -qE "$RUN" \
    || missing "the run line on $2 lacks what is left, ', <left>'"
  case $1 in [Gg][Ii][Tt][Hh][Uu][Bb]) continue ;; esac
  [ "$3" != no ] || continue
  answered=$(printf '%s\n' "$line" | sed -E "s#$PLACE$ANSWER#&\\
#g" | grep -E "$PLACE$ANSWER\$" \
    | sed -E 's#\): class .*##; s#.*(; |\. | — )##' | sort -u | grep -c .)
  [ "$answered" -ge "$3" ] \
    || missing "the run on $2 has $3 findings, $answered answered"
done <<EOF
$REVIEW
EOF

# The head is covered when a run or a skip names it, or a rebase or
# squash line leads to it from one that is, with its closing words.
covered() {
  c=$1 i=0
  while [ $i -lt 100 ]; do
    printf '%s\n%s\n' "$RUNS" "$SKIPS" | grep -qx "$c" && return 0
    c=$(printf '%s\n' "$REVIEW" \
      | sed -nE -e "s/^rebase, $c: from ([0-9a-f]{40}), range-diff checked[[:space:]]*$/\\1/p" \
        -e "s/^squash, $c: from ([0-9a-f]{40}), tree unchanged[[:space:]]*$/\\1/p" \
      | head -1)
    [ -n "$c" ] || return 1
    i=$((i + 1))
  done
  return 1
}
covered "$HEAD_SHA" \
  || missing "no run or skip line names the head $HEAD_SHA, and no" \
    "rebase or squash line leads to it from one that does"

[ -z "$fail" ] || exit 1
echo "review record: the head $HEAD_SHA is covered"
