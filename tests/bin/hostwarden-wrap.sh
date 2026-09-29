#!/bin/sh
# tests/bin/hostwarden-wrap.sh — fixture matrix for
# bin/hostwarden-wrap, the hook that runs it,
# .claude/hooks/wrap-markdown.sh, and the rewrap in
# bin/hostwarden-sync commit. CI runs it through scripts/check.sh;
# an agent session leaves it to CI (.claude/rules/pull-requests.md →
# Checks).
#
# The reflow runs under every awk this machine has of the four it
# has to work with — BWK awk, gawk, mawk and busybox — each put
# first on PATH in turn, since the script calls awk by name.

cd "$(dirname "$0")/../.." || exit 2
ROOT=$(pwd -P)
WRAP="$ROOT/bin/hostwarden-wrap"
# shellcheck source=../helpers.sh
. "$ROOT/tests/helpers.sh"
test_tmp wrap

# fixture <name> [<exit code>] -- stdin holds the input, a line
# `=== want`, and the output wanted; without that line, the input
# is wanted back unchanged. Checks the filter's output and exit
# code, and that its output passes through unchanged again.
fixture() {
  name=$1 want_rc=${2:-0}
  awk -v i="$TMP/in" -v w="$TMP/want" '
    $0 == "=== want" { on = 1; next }
    { print > (on ? w : i) }
    END { if (!on) { close(i); while ((getline l < i) > 0) print l > w }
          else if (!NR) printf "" > i }'
  [ -f "$TMP/want" ] || : > "$TMP/want"
  sh "$WRAP" < "$TMP/in" > "$TMP/got" 2> "$TMP/err"
  rc=$?
  if ! cmp -s "$TMP/want" "$TMP/got"; then
    bad "$AWKNAME: $name"
    diff "$TMP/want" "$TMP/got" | sed 's/^/    /'
  elif [ "$rc" -ne "$want_rc" ]; then
    bad "$AWKNAME: $name (exit $rc, want $want_rc)"
  else
    ok
  fi
  sh "$WRAP" < "$TMP/got" > "$TMP/again" 2>/dev/null
  cmp -s "$TMP/got" "$TMP/again" || bad "$AWKNAME: $name is not stable"
  rm -f "$TMP/in" "$TMP/want" "$TMP/got" "$TMP/again" "$TMP/err"
}

# The rest lives in tests/bin/hostwarden-wrap/, one file per stage,
# sourced in this order into this shell: each reads what the ones
# before it set.
PARTS='fixtures command-line hook'
for part in $PARTS; do
  [ -f "$ROOT/tests/bin/hostwarden-wrap/$part.sh" ] || {
    echo "${0##*/}: tests/bin/hostwarden-wrap/$part.sh is missing" >&2
    exit 1
  }
done
for part in $PARTS; do
  # shellcheck source=/dev/null
  . "$ROOT/tests/bin/hostwarden-wrap/$part.sh"
done

finish "wrap tests"
