# lib/hostwarden-heinzel-takeover/summary.sh — what was copied, kept
# or refused. Sourced by bin/hostwarden-heinzel-takeover, in the
# order its PARTS lists, into the one shell every part shares; never
# run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

if [ -n "$SHARED_PENDING" ]; then
  echo "kept this clone's version of:$SHARED_PENDING" >&2
  echo "(use --force to take the old checkout's instead)" >&2
fi

if [ -z "$COPIED" ]; then
  # A host that could not be handled is a failure. A
  # host that is simply already here is not: a gradual
  # migration re-runs these commands, and a loop over
  # hosts must not die on a repeat.
  if [ -n "$SKIPPED_HOST" ]; then
    if [ -n "$NOTHING_LEFT" ] || [ -n "$HOSTS_PENDING" ]; then
      echo "error: the rest is already here, but the hosts above could not be handled" >&2
    else
      echo "error: nothing was copied — see the skipped hosts above" >&2
    fi
    exit 1
  fi
  if [ -n "$NOTHING_LEFT" ] || [ -n "$HOSTS_PENDING" ]; then
    echo "nothing left to copy from $OLD"
    exit 0
  fi
  echo "nothing to copy from $OLD/memory" >&2
  exit 1
fi

if [ -n "$LIST" ]; then
  printf "would copy from %s:%b\n" "$OLD" "$COPIED"
  exit 0
fi

printf "copied from %s:%b\n" "$OLD" "$COPIED"

# One line, once per installation: the fact that this
# clone came from Heinzel. rules/first-connection.md
# reads it to decide whether the per-host legacy check
# has any reason to run at all.
if ! grep -q '^Taken over from heinzel:' memory/user.md 2>/dev/null; then
  printf 'Taken over from heinzel: %s (%s)\n' \
    "$(date +%Y-%m-%d)" "$OLD" >> memory/user.md
fi

# Renames skill overrides heinzel-* → hostwarden-*
# and creates directories new versions need.
sh bin/hostwarden-migrate

echo "The old checkout was not modified."
echo "Next: the hostwarden-heinzel-takeover skill reads the copied"
echo "memory and changelogs into a per-host inventory of"
echo "what Heinzel left on the servers, then onboards each"
echo "host as on its first connection."
