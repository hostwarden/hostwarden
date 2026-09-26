# lib/hostwarden-heinzel-takeover/args.sh — the arguments, the old
# checkout and the hosts to take over. Sourced by
# bin/hostwarden-heinzel-takeover, in the order its PARTS lists,
# into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

NL="
"
OLD=""
LIST=""
FORCE=""
SHARED_ONLY=""
HOSTS=""
WANT_SERVER=""
for ARG in "$@"; do
  if [ -n "$WANT_SERVER" ]; then
    HOSTS="$HOSTS$ARG$NL"
    WANT_SERVER=""
    continue
  fi
  case "$ARG" in
    --help|-h) usage; exit 0 ;;
    --list) LIST=yes ;;
    --force) FORCE=yes ;;
    --shared) SHARED_ONLY=yes ;;
    --server) WANT_SERVER=yes ;;
    --*) echo "error: unknown option: $ARG" >&2; exit 2 ;;
    *) OLD="$ARG" ;;
  esac
done

if [ -n "$WANT_SERVER" ]; then
  echo "error: --server needs a hostname" >&2
  exit 2
fi

IFS=$NL

if [ -n "$SHARED_ONLY" ] && [ -n "$HOSTS" ]; then
  echo "error: --shared and --server are exclusive" >&2
  exit 2
fi

if [ -z "$OLD" ]; then
  echo "error: no Heinzel checkout given" >&2
  echo "run 'hostwarden-heinzel-takeover --help' for usage" >&2
  exit 2
fi

OLD=$(cd "$OLD" 2>/dev/null && pwd) || {
  echo "error: not a directory: $OLD" >&2
  exit 1
}

if [ "$OLD" = "$REPO_DIR" ]; then
  echo "error: that is this checkout" >&2
  exit 1
fi

if [ ! -d "$OLD/memory" ] || [ ! -d "$OLD/rules" ]; then
  echo "error: $OLD has no memory/ and rules/ — not a Heinzel checkout" >&2
  exit 1
fi

# shellcheck disable=SC2164 # the entry point runs under set -e
cd "$REPO_DIR"

# Access lists and machine memory copied from Heinzel are operations
# state (AGENTS.md → Development or Operations). A
# development checkout or a worktree can neither keep
# them nor onboard a host, so it gets nothing; a dry
# run writes nothing and may look.
# shellcheck source=../lib/mode.sh
. lib/mode.sh
hostwarden_mode "$REPO_DIR"
if [ "$HOSTWARDEN_MODE" != operations ] && [ -z "$LIST" ]; then
  echo "error: this is not an operations checkout — run the takeover in one" >&2
  echo "  (the main checkout of a worktree, or bin/hostwarden-init)" >&2
  exit 1
fi

# An ln -s that cannot link fails, and set -e would stop the run
# with some hosts copied and others not. Find out before the first
# copy instead. A dry run creates nothing.
# In the destination itself: a temporary directory can sit on a
# filesystem that links when this one does not.
if [ -z "$LIST" ]; then
  mkdir -p memory/machines
  probe=$(mktemp -d memory/machines/.link-probe.XXXXXX)
  # ".", not "$probe": that path is relative and would dangle
  # from inside.
  ln -s . "$probe/l" 2>/dev/null || :
  linked=''
  [ -L "$probe/l" ] && linked=yes
  rm -rf "$probe"
  if [ -z "$linked" ]; then
    echo "error: this filesystem cannot hold symbolic links, and DNS" >&2
    echo "  aliases need them — see" >&2
    echo "  https://hostwarden.github.io/docs/getting-started/install#symbolic-links" >&2
    exit 1
  fi
fi

# A host name is one path component. Interpolated
# into both the source and the destination path, a
# value with a slash or .. would read and write
# outside memory/machines/ — `--server ../../bin/foo`
# would land in the repo root.
for H in $HOSTS; do
  valid_hostname "$H" || {
    echo "error: --server takes one plain host name: $H" >&2
    exit 2
  }
done

# Named hosts must exist in the source, or a typo
# would look like a host with no memory. -e follows
# symlinks, so an alias whose target is gone needs
# -L as well — it exists, and the host loop reports
# why it cannot be used.
for H in $HOSTS; do
  if [ ! -e "$OLD/memory/servers/$H" ] \
      && [ ! -L "$OLD/memory/servers/$H" ]; then
    echo "error: $OLD/memory/servers/$H does not exist" >&2
    exit 1
  fi
done
