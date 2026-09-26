#!/bin/sh
# tests/bin/hostwarden-fleet-run.sh — dev-only fixture matrix for
# bin/hostwarden-fleet-run, the unattended housekeeping of an
# operations host. CI runs it through scripts/check.sh; an agent
# session leaves it to CI (.claude/rules/pull-requests.md →
# Checks).
#
# Everything runs in a throwaway operations checkout under a temp
# directory, with a real signed bundle and stand-ins for ssh and
# claude: the ssh stand-in answers "collect" with a fixed output
# per host and records "log", the claude stand-in returns a fixed
# verdict and keeps the prompt it was given.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp fleet-run

has() { grep -qF -- "$2" "$1" && ok || bad "$3"; }
lacks() { grep -qF -- "$2" "$1" && bad "$3" || ok; }

export GIT_AUTHOR_NAME=alice GIT_AUTHOR_EMAIL=alice@example.com
export GIT_COMMITTER_NAME=alice GIT_COMMITTER_EMAIL=alice@example.com
export XDG_STATE_HOME="$TMP/state" HOSTWARDEN_FLEET_RUN_FRESH=1
unset HOSTWARDEN_FLEET_MODEL

# The rest lives in tests/bin/hostwarden-fleet-run/, one file per stage,
# sourced in this order into this shell: each reads what the ones
# before it set.
PARTS='checkout stand-ins dry-run real-run'
for part in $PARTS; do
  [ -f "$REPO/tests/bin/hostwarden-fleet-run/$part.sh" ] || {
    echo "${0##*/}: tests/bin/hostwarden-fleet-run/$part.sh is missing" >&2
    exit 1
  }
done
for part in $PARTS; do
  # shellcheck source=/dev/null
  . "$REPO/tests/bin/hostwarden-fleet-run/$part.sh"
done

finish fleet-run
