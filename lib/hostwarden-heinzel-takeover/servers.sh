# lib/hostwarden-heinzel-takeover/servers.sh — each host's memory.
# Sourced by bin/hostwarden-heinzel-takeover, in the order its PARTS
# lists, into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

if [ -z "$SHARED_ONLY" ] && [ -d "$OLD/memory/servers" ]; then
  if [ -z "$HOSTS" ]; then
    # Globbing, briefly and deliberately: it is the
    # one listing that does not split a name on
    # whitespace the way ls output does.
    set +f
    for E in "$OLD"/memory/servers/*; do
      { [ -e "$E" ] || [ -L "$E" ]; } || continue
      HOSTS="$HOSTS${E##*/}$NL"
    done
    set -f
  fi
  [ -n "$LIST" ] || mkdir -p memory/machines
  # One walk of the whole servers tree instead of a
  # find per host: the fork is the cost, and over a
  # fleet that is the difference between seconds and
  # milliseconds. The result is the set of hosts that
  # hold a link pointing out of the old checkout.
  # Run find from inside the directory: a checkout
  # path holding the sed delimiter would otherwise
  # break the program, and a broken scan reports no
  # escaping links at all.
  ESCAPING="|$(cd "$OLD/memory/servers" 2>/dev/null \
    && find -H . -mindepth 2 -type l 2>/dev/null \
    | sed -e 's|^\./||' -e 's|/.*||' \
    | LC_ALL=C sort -u | tr '\n' '|')"
  # Hosts this run already handled, so one pulled in
  # as an alias's canonical target is not reported as
  # a conflict with itself afterwards.
  DONE_HOSTS="|"
  for H in $HOSTS; do
    valid_hostname "$H" || {
      skip_host "$H" "not a plain host name"
      continue
    }
    SRC="$OLD/memory/servers/$H"
    DST="memory/machines/$H"
    { [ -e "$SRC" ] || [ -L "$SRC" ]; } || continue
    case "$DONE_HOSTS" in *"|$H|"*) continue ;; esac

    # A DNS alias is a symlink to a sibling host
    # (rules/dns-aliases.md). Resolve and validate the
    # name once, here, so everything below works with
    # a target that is known to be a host name.
    CANON=""
    if [ -L "$SRC" ]; then
      CANON=$(readlink "$SRC")
      valid_hostname "$CANON" || {
        skip_host "$H" "alias points outside memory/servers/: $CANON"
        continue
      }
    fi

    # new        — nothing of this host is here yet
    # repair     — the alias is here and right, the
    #              memory behind it may not be
    # taken_over — this host is already here as it is
    STATE=new
    CANON_SAME=""
    if [ -n "$CANON" ]; then
      if same_link "$SRC" "$DST"; then
        STATE=repair
        case "$DONE_HOSTS" in
          *"|$CANON|"*)
            STATE=taken_over ;;
          *)
            if already_taken_over "$OLD/memory/servers/$CANON" \
                "memory/machines/$CANON"; then
              STATE=taken_over
            else
              CANON_SAME=no
            fi ;;
        esac
      fi
    elif already_taken_over "$SRC" "$DST"; then
      STATE=taken_over
    fi

    # Also under --force: everything the old checkout
    # has is here unchanged, so it has already won,
    # and what is extra — a longer log, a todo, the
    # inventory — is this clone's work since, which
    # replacing the directory would throw away.
    if [ "$STATE" = taken_over ]; then
      # Named on stdout: the hostwarden-heinzel-takeover skill builds an
      # inventory for the hosts a run selected, and a
      # repeat run copies none of them.
      echo "already taken over: memory/machines/$H"
      # A memory.md identical to the old checkout's is
      # still Heinzel's, whatever copied it here.
      if [ -z "$LIST" ]; then
        for AD in "memory/machines/$H" ${CANON:+"memory/machines/$CANON"}; do
          AD_SRC="$OLD/memory/servers/${AD##*/}"
          cmp -s "$AD_SRC/memory.md" "$AD/memory.md" 2>/dev/null \
            && keep_heinzel_memory "$AD"
        done
      fi
      DONE_HOSTS="$DONE_HOSTS$H|"
      [ -z "$CANON" ] || DONE_HOSTS="$DONE_HOSTS$CANON|"
      NOTHING_LEFT=yes
      continue
    fi

    # An alias here that already points at the same
    # name is not in the way — only the memory behind
    # it is missing, and that gets repaired below. An
    # alias whose name is taken here is kept only
    # after its canonical host: the hostwarden-heinzel-takeover skill builds
    # the inventory for that host, which it cannot do
    # in a directory that never arrived.
    KEEP=""
    if [ "$STATE" = new ] && occupied "$SRC" "$DST" \
        && [ -z "$FORCE" ]; then
      KEEP=yes
    fi

    if [ -n "$CANON" ]; then
      # The canonical entry in the old checkout has to
      # be the host itself. A chain — alias ->
      # canonical, canonical -> /tmp/x — would leave
      # both links pointing out of the tree.
      if [ ! -e "$OLD/memory/servers/$CANON" ]; then
        skip_host "$H" "alias to $CANON, which the old checkout does not have"
        continue
      fi
      if [ -L "$OLD/memory/servers/$CANON" ] \
          || [ ! -d "$OLD/memory/servers/$CANON" ]; then
        skip_host "$H" "alias to $CANON, which is not a host directory"
        continue
      fi
      case "$ESCAPING" in
        *"|$CANON|"*)
          skip_host "$H" "$CANON holds a link out of the old checkout"
          continue ;;
      esac
      # And here it has to be a real directory, or the
      # alias would resolve to a file or follow a link
      # of theirs out of memory/servers/.
      DST_CANON="memory/machines/$CANON"
      if [ -z "$FORCE" ] \
          && { [ -L "$DST_CANON" ] \
            || { [ -e "$DST_CANON" ] && [ ! -d "$DST_CANON" ]; }; }; then
        keep_host "$H" "$DST_CANON is not a host directory here, use --force to replace it"
        continue
      fi
      # An alias is only worth having if it resolves
      # to the host it names. A canonical directory
      # already here with different content is not
      # that host, and an alias pointing at this
      # clone's older memory is worse than none.
      if [ -z "$FORCE" ] && [ -d "$DST_CANON" ] && [ ! -L "$DST_CANON" ]; then
        if [ "$CANON_SAME" = no ] \
            || ! same_content "$OLD/memory/servers/$CANON" "$DST_CANON"; then
          keep_host "$H" "$DST_CANON differs from the old checkout's, use --force"
          continue
        fi
      fi
      if [ ! -d "$DST_CANON" ] || [ -L "$DST_CANON" ] \
          || [ -n "$FORCE" ]; then
        plan "machines/$CANON (canonical host of $H)"
        DONE_HOSTS="$DONE_HOSTS$CANON|"
        if [ -z "$LIST" ]; then
          copy_item "$OLD/memory/servers/$CANON" "machines/$CANON" link
          keep_heinzel_memory "memory/machines/$CANON"
        fi
      fi
    fi
    if [ -n "$KEEP" ]; then
      keep_host "$H" "already here, use --force to overwrite"
      continue
    fi

    case "$ESCAPING" in
      *"|$H|"*)
        skip_host "$H" "it holds a link out of the old checkout"
        continue ;;
    esac
    plan "machines/$H"
    DONE_HOSTS="$DONE_HOSTS$H|"
    if [ -z "$LIST" ]; then
      copy_item "$SRC" "machines/$H" link
      keep_heinzel_memory "memory/machines/$H"
    fi
  done
fi
