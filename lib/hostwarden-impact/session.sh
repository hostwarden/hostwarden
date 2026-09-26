# lib/hostwarden-impact/session.sh — this session, the impact
# entries and the SSH user, for every subcommand. Sourced by
# bin/hostwarden-impact, in the order its PARTS lists, into the one
# shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# fields — every "- Key: value" line of every host's memory.md, its
# continuation lines joined, as <host><TAB><key><TAB><value>. A
# symlinked directory is a DNS alias and is read once, as its host.
# Defined here, before bin/hostwarden-impact's dispatcher, since
# status (via window_status) needs it and exits from inside that
# dispatcher, never reaching radius's own setup after it.
fields() {
  set --
  for f in "$M"/machines/*/memory.md; do
    [ -f "$f" ] && [ ! -L "${f%/memory.md}" ] && set -- "$@" "$f"
  done
  [ $# -gt 0 ] || return 0
  awk '
    function flush() { if (key != "") print h "\t" key "\t" val; key = "" }
    FNR == 1 { flush(); h = FILENAME; sub(/\/memory\.md$/, "", h); sub(/.*\//, "", h) }
    /^- [A-Za-z][A-Za-z0-9 _-]*:/ {
      flush(); key = substr($0, 3); sub(/:.*/, "", key)
      val = $0; sub(/^- [^:]*:[ \t]*/, "", val); next
    }
    /^[ \t]+[^ \t]/ && key != "" { v = $0; sub(/^[ \t]+/, "", v); val = val " " v; next }
    { flush() }
    END { flush() }' "$@"
}

# impact_session — this session's id: $HOSTWARDEN_SESSION where
# session-mode.sh set it (the same id presence.sh reads from its
# own hook input), a fallback that correlates with nothing
# otherwise. Sanitized (coord-lib.sh) to the characters an entry
# name may hold.
impact_session() {
  hostwarden_coord_sanitize "${HOSTWARDEN_SESSION:-manual-$$}"
}

# impact_prune — removes every impact/ entry whose window ended
# more than 30 minutes ago: the same staleness rules/parallel-
# sessions.md gives a register entry, so nobody has to mark it
# done for it to stop covering a host.
impact_prune() {
  ip_now=$(date +%s)
  for ip_d in "$HOSTWARDEN_CACHE"/impact/*; do
    [ -d "$ip_d" ] || continue
    ip_u=$(printf '%s' "${ip_d##*/}" | cut -d+ -f4)
    case $ip_u in *[!0-9]* | '') continue ;; esac
    [ $((ip_now - ip_u)) -gt 1800 ] && rm -rf "$ip_d"
  done
}

# impact_dir_for_id <id> — the impact/ directory whose name starts
# with <id>+, on stdout; fails when there is none.
impact_dir_for_id() {
  for ip_d in "$HOSTWARDEN_CACHE/impact/$1+"*; do
    [ -d "$ip_d" ] && { printf '%s\n' "$ip_d"; return 0; }
  done
  return 1
}

# user_for <key> — the SSH user memory/user.md gives <key>: its own
# entry, else the default (rules/ssh-user.md).
user_for() {
  awk -v k="$1" '
    /^[-*[:space:]]*Default:/ && d == "" {
      d = $0; sub(/^[-*[:space:]]*Default:[[:space:]]*/, "", d); sub(/[[:space:]].*/, "", d)
    }
    index($0, "- " k ":") == 1 {
      u = substr($0, length(k) + 4); sub(/^[[:space:]]+/, "", u); sub(/[[:space:]].*/, "", u)
    }
    END { print (u != "" ? u : d) }' "$M/user.md" 2>/dev/null
}
