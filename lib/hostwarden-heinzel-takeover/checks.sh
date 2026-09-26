# lib/hostwarden-heinzel-takeover/checks.sh — the checks on a link,
# a host name and what is already here. Sourced by
# bin/hostwarden-heinzel-takeover, in the order its PARTS lists,
# into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# The first symlink below <dir>, if there is one.
# cp -R keeps nested links as links, so a
# memory.md -> /outside/file in the old checkout
# would still point out of the tree here, and the
# next memory update would write there. Aliases are
# a top-level arrangement (rules/dns-aliases.md);
# anything nested is not one, and is refused rather
# than followed — dereferencing could pull in an
# unbounded amount of somebody else's files.
nested_link() {
  # Always succeeds: a non-zero status here would end
  # the run at `NESTED=$(nested_link ...)` under
  # set -e, and a plain file has no nested anything.
  # -H follows the starting point only: when the
  # item itself is a link to a directory, find would
  # otherwise not enter it and report nothing, while
  # cp -R "$src/." resolves the root and copies the
  # child links straight in.
  [ -d "$1" ] && find -H "$1" -mindepth 1 -type l -print 2>/dev/null | head -n 1
  return 0
}

# True when this clone already has the item itself:
# same content, and not through a symlink. A link
# whose target happens to match today is not the
# same thing — it keeps pointing somewhere else, and
# an edit there would silently change an access list
# nobody touched.
# Two entries are the same alias when they point at
# the same name. Only that — where the name resolves
# is the canonical host's business, checked there.
same_link() {
  [ -L "$1" ] && [ -L "$2" ] \
    && [ "$(readlink "$1")" = "$(readlink "$2")" ]
}

# A host name is one path component, and it must
# survive being put into the pipe-delimited sets this
# script matches against. Checked wherever a name
# enters — arguments, the directory listing, an alias
# target — not only at the command line.
valid_hostname() {
  case "$1" in
    ""|.|..|*/*) return 1 ;;
    *"|"*) return 1 ;;
    *[[:space:]]*) return 1 ;;
  esac
  return 0
}

already_taken_over() {
  # A destination link never counts: its target can
  # change under us, and two links with the same text
  # can resolve to different files in the two
  # checkouts — for an access list that would drop a
  # restriction while the hosts come across behind
  # it. Matching link text means something only for a
  # server alias, and the host loop says so there.
  [ -L "$2" ] && return 1
  same_content "$1" "$2"
}

# True when the destination holds something a
# non-force run must not touch: anything of the
# user's, a symlink of theirs (dangling or not), or a
# shape that does not match the source — a directory
# where a file belongs would otherwise have the
# source nested inside it as blacklist.md/blacklist.md
# and leave the host import running without an
# effective blacklist. A directory holding only the
# .gitkeep the repo ships is free.
occupied() {
  oc_src="$1"
  oc_dst="$2"
  [ -L "$oc_dst" ] && return 0
  [ -e "$oc_dst" ] || return 1
  if [ -d "$oc_src" ]; then
    [ -d "$oc_dst" ] || return 0
    [ -n "$(user_data "$oc_dst")" ]
  else
    return 0
  fi
}

# True when source and destination already match, so
# there is nothing to copy and nothing to conflict
# over. This is what lets a gradual migration work: a
# second --server run finds the access lists it wrote
# itself on the first one, and must not read them as
# a conflict.
same_content() {
  # Nothing there is not the same content, and
  # answering that without forking diff or cmp is the
  # difference on a fleet-sized tree.
  [ -e "$2" ] || return 1
  if [ -d "$1" ]; then
    # For a directory: everything the old checkout has
    # is here, unchanged. Extra entries on our side do
    # not count against it — a host gains its
    # heinzel-inventory.md, a todo, a longer log, and
    # a byte-for-byte test would call it a conflict
    # from the first session onwards. A file Hostwarden
    # has added to since, the log above all, differs
    # rather than being extra; it still matches as long
    # as the imported bytes come first, unchanged.
    # A host's memory.md matches its heinzel-memory.md
    # (keep_heinzel_memory, in copy.sh).
    diff -rq "$1" "$2" 2>/dev/null | while IFS= read -r sc_line; do
      case "$sc_line" in
        "Only in $2"*) continue ;;
        "Only in $1: memory.md" \
          | "Files $1/memory.md and $2/memory.md differ")
          [ -f "$2/heinzel-memory.md" ] && [ ! -L "$2/heinzel-memory.md" ] \
            && cmp -s "$1/memory.md" "$2/heinzel-memory.md" || exit 1 ;;
        "Files $1/"*" differ")
          sc_rel=${sc_line#"Files $1/"}
          sc_rel=${sc_rel%%" and $2/"*}
          sc_size=$(wc -c < "$1/$sc_rel")
          head -c "$sc_size" "$2/$sc_rel" \
            | cmp -s - "$1/$sc_rel" || exit 1 ;;
        *) exit 1 ;;
      esac
    done
  else
    cmp -s "$1" "$2" 2>/dev/null
  fi
}

# Anything below <dir> that the user could have
# written. Only .gitkeep and transient noise are the
# repo's. The shipped templates live directly in
# memory/, never inside the directories this is
# called with, so an *.example here is the user's.
#
# Symlinks count. A directory holding only links
# would otherwise read as empty, and a copy into it
# would follow them and write through to their
# targets — outside the repo, in the worst case.
user_data() {
  # The noise names are ignorable only as plain
  # files. A *symlink* called .gitkeep is not the
  # repo's placeholder, and calling the directory
  # empty over it would let cp -R follow that link
  # and write to its target outside the repo.
  find "$1" \( \
      \( -type f \
         ! -name '.gitkeep' \
         ! -name '.DS_Store' \
         ! -name '*.lock' \) \
      -o -type l \) \
    | head -n 1
}
