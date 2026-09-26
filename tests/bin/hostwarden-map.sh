#!/bin/sh
# tests/bin/hostwarden-map.sh — golden-fixture matrix for bin/hostwarden-map:
# every level's Mermaid and table, determinism, and the palette's own
# contrast rule, computed here rather than eyeballed
# (rules/network-topology.md's design; .claude/rules/pull-requests.md
# → Checks runs this through CI, never on the workstation).
#
# The fixture's own dates are computed at run time, a fixed number of
# days back from today, so a host that must stay fresh or stale does
# so regardless of when this runs; a literal date in a fixture would
# drift into the other state and the golden files would go stale
# with it.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp map

has() { grep -qxF -- "$2" "$1" && ok || bad "$3 ($1)"; }
haspart() { grep -qF -- "$2" "$1" && ok || bad "$3 ($1)"; }
lacks() { grep -qF -- "$2" "$1" && bad "$3 ($1)" || ok; }
exists() { [ -f "$1" ] && ok || bad "$2 ($1)"; }
absent() { [ -f "$1" ] && bad "$2 ($1)" || ok; }

days_ago() {
  e=$(($(date +%s) - $1 * 86400))
  date -j -f %s "$e" +%Y-%m-%d 2>/dev/null || date -d "@$e" +%Y-%m-%d
}
# shellcheck disable=SC2034 # read by the parts
FRESH=$(days_ago 5) STALE=$(days_ago 100)

# The rest lives in tests/bin/hostwarden-map/, one file per stage,
# sourced in this order into this shell: each reads what the ones
# before it set.
PARTS='fixture levels overview palette'
for part in $PARTS; do
  [ -f "$REPO/tests/bin/hostwarden-map/$part.sh" ] || {
    echo "hostwarden-map.sh: tests/bin/hostwarden-map/$part.sh is missing" >&2
    exit 1
  }
done
for part in $PARTS; do
  # shellcheck source=/dev/null
  . "$REPO/tests/bin/hostwarden-map/$part.sh"
done

finish hostwarden-map
