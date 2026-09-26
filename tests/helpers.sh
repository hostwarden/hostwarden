# shellcheck shell=sh
# helpers.sh — the counters every matrix under tests/ keeps, and the
# line it ends with. Sourced, never executed; the matrix sets REPO to
# the checkout's root first and sources "$REPO/tests/helpers.sh".
#
#   ok                   one check passed
#   bad <message…>       one check failed, and says which
#   test_tmp <name>      makes TMP, a directory removed on exit
#   finish <name>        prints "<name>: N passed, M failed" and
#                        exits 0 only when nothing failed
#
# A matrix that needs more — fixtures run in parallel batches, a
# trap of its own — keeps it in its own file.

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

test_tmp() {
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-$1-test.XXXXXX") || exit 2
  trap 'rm -rf "$TMP"' EXIT INT TERM
}

finish() {
  echo "$1: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
  exit
}
