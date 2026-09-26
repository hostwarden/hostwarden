#!/bin/sh
# tests/scripts/review-record.sh — fixture matrix for
# scripts/review-record.sh and scripts/review-tier.sh. CI runs it
# through scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# Runs from scripts/, where the two scripts it checks live.

cd "$(dirname "$0")/../../scripts" || exit 2
# shellcheck source=../helpers.sh
. ../tests/helpers.sh

A=1111111111111111111111111111111111111111
# shellcheck disable=SC2034 # read by the parts
B=2222222222222222222222222222222222222222
# shellcheck disable=SC2034 # read by the parts
C=3333333333333333333333333333333333333333

HERE=$(pwd)
IN=.
BASE=

# expect <exit code> <head> <what> -- the body on stdin, the checker
# run in $IN, where a fix line's commits are read, and given $BASE
# as the head's merge base where it is set
expect() {
  want=$1 head=$2
  shift 2
  (cd "$IN" && sh "$HERE/review-record.sh" "$head" ${BASE:+"$BASE"}) \
    >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then
    ok
  else
    bad "$* (exit $got, want $want)"
  fi
}

expect 0 "$A" "a clean run on the head" <<EOF
## Review

Codex gpt-6-sol medium, local, $A: no findings, 7d 8% used
EOF

expect 0 "$A" "a list marker" <<EOF
## Review
- Codex gpt-6-sol medium, local, $A: no findings, 7d 8% used
EOF

# The rest lives in tests/scripts/review-record/, one file per stage,
# sourced in this order into this shell: each reads what the ones
# before it set.
PARTS='lines blocks fixes own-review'
for part in $PARTS; do
  [ -f "$HERE/../tests/scripts/review-record/$part.sh" ] || {
    echo "${0##*/}: tests/scripts/review-record/$part.sh is missing" >&2
    exit 1
  }
done
for part in $PARTS; do
  # shellcheck source=/dev/null
  . "$HERE/../tests/scripts/review-record/$part.sh"
done

finish "review record tests"
