# lib/hostwarden-heinzel-takeover/copy.sh — the copy of an item and
# the shared files. Sourced by bin/hostwarden-heinzel-takeover, in
# the order its PARTS lists, into the one shell every part shares;
# never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# Copy <src> to memory/<dst>, preserving symlinks —
# memory/machines/ holds DNS aliases as symlinks to the
# canonical directory (rules/dns-aliases.md), and
# resolving them would duplicate a host's memory.
# Local names only: sh has no scoping, and a plain
# SRC here would clobber the caller's loop variable.
# copy_item <src> memory/<dst> [link]
#
# `link` preserves a symlink source as a symlink —
# for DNS aliases under machines/, whose target is a
# validated sibling host. Everything else is copied
# by content: a shared file that is a link in the old
# checkout must arrive here as the file itself, since
# its target is not part of what gets copied.
copy_item() {
  ci_src="$1"
  ci_dst="memory/$2"
  ci_keeplink="$3"
  # --force means the old checkout's copy wins, so an
  # occupied destination is replaced, not merged: a
  # stale rules.md, todo.md or heinzel-inventory.md
  # left behind would outlive the host memory it
  # belongs to. A destination that holds only the
  # .gitkeep the repo ships is left alone, and a type
  # change (file where a directory was, or the other
  # way round) is replaced as well.
  if [ -n "$FORCE" ] && [ -e "$ci_dst" ] && [ ! -L "$ci_dst" ]; then
    if [ -d "$ci_src" ] && [ ! -d "$ci_dst" ]; then
      rm -rf "$ci_dst"
    elif [ ! -d "$ci_src" ] && [ -d "$ci_dst" ]; then
      rm -rf "$ci_dst"
    elif [ -d "$ci_dst" ] && [ -n "$(user_data "$ci_dst")" ]; then
      rm -rf "$ci_dst"
    fi
  fi
  # A destination symlink is replaced rather than
  # written through, or a copy would land in the
  # canonical host an alias points at. rm -rf, not
  # rm -f: the destination may be a real directory
  # where the source became an alias, and a failing
  # rm would abort the run half-copied.
  if [ -L "$ci_dst" ] || { [ -L "$ci_src" ] && [ -e "$ci_dst" ]; }; then
    rm -rf "$ci_dst"
  fi
  if [ -L "$ci_src" ] && [ -n "$ci_keeplink" ]; then
    ci_link=$(readlink "$ci_src")
    ln -s "$ci_link" "$ci_dst"
  elif [ -d "$ci_src" ]; then
    if [ -d "$ci_dst" ]; then
      cp -R "$ci_src/." "$ci_dst/"
    else
      cp -R "$ci_src" "$ci_dst"
    fi
  else
    cp "$ci_src" "$ci_dst"
  fi
}

# keep_heinzel_memory memory/machines/<host>
#
# Heinzel's memory.md becomes heinzel-memory.md, byte
# for byte. Left as memory.md, it would read as a
# Hostwarden memory file: the next connection would
# take the short subsequent-connection path and trust
# a narrative that was true when Heinzel wrote it.
# Without memory.md, every rule treats that connection
# as the first, which writes one in Hostwarden's form
# (rules/heinzel-takeover.md → Heinzel's memory). An
# alias is a link to its canonical host and is left
# alone.
keep_heinzel_memory() {
  [ -L "$1" ] && return 0
  [ -f "$1/memory.md" ] && [ ! -L "$1/memory.md" ] || return 0
  [ -e "$1/heinzel-memory.md" ] || [ -L "$1/heinzel-memory.md" ] \
    || mv "$1/memory.md" "$1/heinzel-memory.md"
  return 0
}

COPIED=""
NOTHING_LEFT=""
SKIPPED_HOST=""
HOSTS_PENDING=""
# Two outcomes, not one. A host that is already this
# clone's own is kept and the run is still a success;
# only a host that cannot be handled at all makes it
# a failure. The shared state has drawn that line
# since the beginning — see SHARED_PENDING.
keep_host() {
  echo "kept memory/machines/$1 — $2" >&2
  HOSTS_PENDING="$HOSTS_PENDING $1"
}
skip_host() {
  echo "skipped memory/machines/$1 — $2" >&2
  SKIPPED_HOST=yes
}
plan() { COPIED="$COPIED\n  memory/$1"; }

# Which shared files this clone would keep. Decided
# before anything is copied, because the access-list
# check below can refuse the run, and refusing after
# half the shared state has been written leaves a
# clone that cannot be described or re-run cleanly.
# What this run will not copy, and — when one of the
# access lists is among it — why the hosts may not
# follow. One list and one reason: every skip has the
# same two consequences, whatever caused it.
SHARED_SKIP=""
SHARED_PENDING=""
BLOCK_REASON=""
skip_shared() {
  SHARED_SKIP="$SHARED_SKIP $1"
  case "$1" in
    blacklist.md|readonly.md)
      [ -n "$SHARED_ONLY" ] || BLOCK_REASON="$2" ;;
  esac
}
for ITEM in $SHARED; do
  # A link in the old checkout that does not resolve
  # has no content to copy. Silently skipping it
  # would be how a host arrives here with no
  # blacklist behind it.
  if [ -L "$OLD/memory/$ITEM" ] && [ ! -e "$OLD/memory/$ITEM" ]; then
    echo "skipped memory/$ITEM — a link in the old checkout that does not resolve" >&2
    skip_shared "$ITEM" "is not a readable list file in the old checkout"
    continue
  fi
  [ -e "$OLD/memory/$ITEM" ] || continue
  # And the right shape. rules/access-control.md
  # reads blacklist.md and readonly.md as plain list
  # files: a directory of that name would be copied
  # as a directory, and every host would arrive here
  # unrestricted.
  case "$ITEM" in
    custom-rules) [ -d "$OLD/memory/$ITEM" ] ;;
    *) [ -f "$OLD/memory/$ITEM" ] ;;
  esac || {
    echo "skipped memory/$ITEM — not the kind of entry its name promises" >&2
    skip_shared "$ITEM" "is not a readable list file in the old checkout"
    continue
  }
  NESTED=$(nested_link "$OLD/memory/$ITEM")
  if [ -n "$NESTED" ]; then
    echo "skipped memory/$ITEM — $NESTED is a link out of the old checkout" >&2
    skip_shared "$ITEM" "is not a readable list file in the old checkout"
    continue
  fi
  if already_taken_over "$OLD/memory/$ITEM" "memory/$ITEM"; then
    SHARED_SKIP="$SHARED_SKIP $ITEM"
    NOTHING_LEFT=yes
    continue
  fi
  if occupied "$OLD/memory/$ITEM" "memory/$ITEM" && [ -z "$FORCE" ]; then
    SHARED_PENDING="$SHARED_PENDING $ITEM"
    skip_shared "$ITEM" "is already here in a version of this clone's own"
  fi
done

# What the old memory/ holds beyond the shared state,
# the servers and known_hosts — Claude's auto-memory,
# notes, a brand directory — named before anything can
# stop the run, so a dry run shows it too. None
# of it has a place of its own here, and copying it
# whole would put a second, unread memory beside this
# one. The skill sorts it item by item.
set +f
for E in "$OLD"/memory/* "$OLD"/memory/.[!.]*; do
  { [ -e "$E" ] || [ -L "$E" ]; } || continue
  N=${E##*/}
  case "$N" in
    servers|known_hosts|MEMORY.md|*.example|.git|.gitignore|.gitkeep|.DS_Store|.heinzel*) continue ;;
  esac
  case "$NL$SHARED$NL" in *"$NL$N$NL"*) continue ;; esac
  if [ -d "$E" ]; then
    echo "not copied: memory/$N/"
  else
    echo "not copied: memory/$N"
  fi
done
set -f

# The invariant from the header: a host may not come
# across while the lists that say whether it may be
# touched stayed behind. A kept blacklist or
# read-only list therefore stops the host import —
# before the first write. A dry run reports it and
# carries on; it changes nothing either way.
if [ -n "$BLOCK_REASON" ]; then
  echo "memory/blacklist.md or memory/readonly.md $BLOCK_REASON." >&2
  echo "A host denied or read-only in the old checkout would arrive here" >&2
  echo "without that restriction, so no host is copied. Fix it in the old" >&2
  echo "checkout, merge the lists by hand, or re-run with --force to take" >&2
  echo "the old checkout's." >&2
  # A dry run stops here too: everything after this
  # point is disabled, so listing it would describe a
  # plan that cannot run with these arguments.
  if [ -n "$LIST" ]; then
    echo "nothing would be copied until this is resolved" >&2
    exit 0
  fi
  echo "error: nothing was copied" >&2
  exit 1
fi

# Shared state first, always: a per-machine takeover
# without the blacklist and the read-only list would
# work on hosts whose access rules stayed behind.
[ -n "$LIST" ] || mkdir -p memory
for ITEM in $SHARED; do
  [ -e "$OLD/memory/$ITEM" ] || continue
  case " $SHARED_SKIP " in
    *" $ITEM "*) continue ;;
  esac
  plan "$ITEM"
  [ -n "$LIST" ] || copy_item "$OLD/memory/$ITEM" "$ITEM"
done
