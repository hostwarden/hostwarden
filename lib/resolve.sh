# shellcheck shell=sh
# resolve.sh — a name's addresses, IPv4 and IPv6 alike, the way
# rules/dns-aliases.md → Detection step 1 asks for them, and the
# access lists read the way rules/access-control.md → Shared File
# Format writes them, defined once for the scripts that check those
# lists themselves (bin/hostwarden-fleet-run, bin/hostwarden-impact).
#
# Sourced, never executed, so it carries no shebang and tells
# ShellCheck its dialect with the directive above instead.
#
# Defines:
#   hostwarden_resolver
#       sets HOSTWARDEN_RESOLVER to the first tool here that resolves
#       localhost: getent on Linux, dscacheutil on macOS, getaddrinfo
#       through python3 elsewhere, and dig only where none of those
#       answers; empty where none does. FreeBSD has a getent without
#       glibc's ahostsv4 database, so a tool counts only once it has
#       answered.
#   hostwarden_resolve <name> [<tool>]
#       prints every address, IPv4 and IPv6, <tool>, else
#       HOSTWARDEN_RESOLVER, gives <name>, one per line; nothing
#       where there is no tool or where <name> comes back empty —
#       genuinely empty and resolver-unreachable look the same
#       here, same as rules/dns-aliases.md → Detection step 1's own
#       collection. A caller that has to tell the two apart calls
#       hostwarden_resolve_ok once this comes back empty.
#   hostwarden_resolve_ok <name>
#       Only meaningful right after hostwarden_resolve <name> came
#       back empty. Asks the server the name is routed to, the way
#       Detection step 1 tells a resolver outage from a clean
#       negative: under split DNS or a VPN, the default servers can
#       answer cleanly for a name whose own scoped resolver is down.
#       On Linux, where `resolvectl domain` names a routing domain
#       that covers <name>, `resolvectl query` asks through it: exit
#       0 on one of the three negatives Detection step 1 lists,
#       exit 1 ("unreachable") on anything else. Otherwise dig asks
#       for <name>'s A and AAAA status — on macOS at the scoped
#       resolver `scutil --dns` gives for the longest domain <name>
#       ends in, elsewhere at the default servers, which are then
#       the system resolver's own: exit 0 where dig answered both
#       queries and every
#       status is NOERROR or NXDOMAIN — <name> genuinely has no
#       address. One query answering is not enough: dig omits a
#       query's status line entirely, rather than printing a bad
#       one, when that specific query got no response at all, so a
#       single clean line can mean either a genuine miss or one of
#       the two queries timing out silently — counted as unreachable
#       either way, the same way `rules/dns.md` → Checks already
#       treats no status line at all for its own, single-query dig
#       call. Exit 1 otherwise, with one word on stdout: "unreachable"
#       for a bad status, an incomplete answer, or dig itself timing
#       out with no status at all, and "no-dig" where dig is not
#       installed to tell the two apart in the first place — a
#       missing tool, not a resolver problem, same distinction
#       Detection step 1 draws. Where HOSTWARDEN_RESOLVE_CACHE names
#       a writable directory, the answer for <name> is cached there
#       for the rest of the process: a caller that checks the same
#       host many times in one run (hostwarden-impact's blocked,
#       called once per radius host; hostwarden-fleet-run's
#       blacklisted, called once per hop as well as per host) does
#       not re-ask dig for a name it has already settled.
#   hostwarden_resolve_or_unresolved <name>
#       hostwarden_resolve <name>, space-joined; where that comes
#       back empty and hostwarden_resolve_ok <name> finds it
#       ambiguous, one of $HOSTWARDEN_UNRESOLVED_NO_DIG or
#       $HOSTWARDEN_UNRESOLVED_UNREACHABLE instead, trailing space
#       either way — hostwarden_resolve_ok's own word, kept apart so
#       a caller can still say which (Detection step 1: a missing
#       tool is never called a resolver-unreachable result). The one
#       place callers that only see this function's output — already
#       flattened through a subshell, their own variables gone — get
#       the address-or-ambiguous decision, so hostwarden_list_entries
#       and every caller that resolves a single name for the
#       blacklist or read-only check share it instead of each
#       running the same two calls by hand.
#   hostwarden_list_entries <file>
#       prints the entries of an access list, each followed by
#       hostwarden_resolve_or_unresolved's output, on one line;
#       nothing where the file is missing.
#   hostwarden_listed <entries> <names>
#       true when one of the space-separated <names> is among the
#       space-separated <entries>. `hostwarden_listed <string>
#       "$HOSTWARDEN_UNRESOLVED_NO_DIG $HOSTWARDEN_UNRESOLVED_UNREACHABLE"`
#       is how a caller tests for either in a string this file built.
#   hostwarden_unresolved_words <string>
#       "resolver unreachable", "no dig here to tell a clean miss
#       from an outage", or both joined by ", and", from whichever of
#       the two tokens above <string> holds; empty where neither is. The one place that phrasing
#       is written, so a caller's message stays worded the way
#       Detection step 1 asks regardless of where it checks.

# Never real entries: valid hostnames and addresses do not look like
# this, so they are safe as tokens in the same space-separated soup
# hostwarden_listed matches over.
HOSTWARDEN_UNRESOLVED_NO_DIG=HOSTWARDEN_UNRESOLVED_NO_DIG
HOSTWARDEN_UNRESOLVED_UNREACHABLE=HOSTWARDEN_UNRESOLVED_UNREACHABLE

hostwarden_resolve() {
  case ${2:-${HOSTWARDEN_RESOLVER:-}} in
    getent) { getent ahostsv4 "$1" 2>/dev/null | awk '{ print $1 }'
      getent ahostsv6 "$1" 2>/dev/null | awk '{ print $1 }' \
        | grep -v '^::ffff:'; } | sort -u ;;
    dscacheutil) dscacheutil -q host -a name "$1" 2>/dev/null \
      | awk '$1 == "ip_address:" || $1 == "ipv6_address:" { print $2 }' \
      | sort -u ;;
    python3) python3 -c 'import socket, sys
for a in sorted({i[4][0] for i in
        socket.getaddrinfo(sys.argv[1], None)}):
    print(a)' "$1" 2>/dev/null ;;
    dig) dig +short +time=2 +tries=1 "$1" A "$1" AAAA 2>/dev/null \
      | grep -E '^[0-9a-fA-F.:]+$' ;;
  esac
}

hostwarden_resolve_ok() {
  hr_c=''
  if [ -n "${HOSTWARDEN_RESOLVE_CACHE:-}" ]; then
    hr_c="$HOSTWARDEN_RESOLVE_CACHE/ok.$(printf '%s' "$1" \
      | cksum | cut -d' ' -f1)"
    if [ -f "$hr_c" ]; then
      hr_v=$(cat "$hr_c")
      [ "$hr_v" = ok ] && return 0
      printf '%s' "$hr_v"
      return 1
    fi
  fi
  hr_v=$(hostwarden_resolve_ask "$1")
  [ -z "$hr_c" ] || printf '%s' "$hr_v" >"$hr_c"
  [ "$hr_v" = ok ] && return 0
  echo "$hr_v"
  return 1
}

# hostwarden_resolve_ask <name> — ok, unreachable or no-dig, asked
# fresh each time; hostwarden_resolve_ok's uncached half.
hostwarden_resolve_ask() {
  # DNS names match without regard to case or a final dot: without
  # this, WEB.corp.example.net or web.corp.example.net. would miss
  # the ~corp.example.net route and be asked at the default servers.
  hr_n=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/\.$//')
  if command -v resolvectl >/dev/null 2>&1 \
    && resolvectl domain 2>/dev/null | awk -v n="$hr_n" '
      { sub(/^[^:]*:[[:space:]]*/, "")
        for (i = 1; i <= NF; i++) {
          d = tolower($i); sub(/^~/, "", d); sub(/\.$/, "", d)
          if (d == "" || n == d || substr(n, length(n) - length(d)) == "." d) f = 1
        } }
      END { exit !f }'; then
    hr_q=$(resolvectl query --synthesize=no --cache=no "$1" 2>&1)
    case $hr_q in
      *"' does not have any RR of the requested type"* \
        | *"Name '"*"' not found"* \
        | *"No appropriate name servers or networks for name found"*)
        echo ok ;;
      *) echo unreachable ;;
    esac
    return
  fi
  command -v dig >/dev/null 2>&1 || { echo no-dig; return; }
  hr_s='' hr_p=''
  if command -v scutil >/dev/null 2>&1; then
    # shellcheck disable=SC2046 # one word each: server, port
    set -- "$1" $(scutil --dns 2>/dev/null | awk -v n="$hr_n" '
      function pick() {
        if (a != "" && d != "" && length(d) > b &&
            (n == d || substr(n, length(n) - length(d)) == "." d)) {
          b = length(d); s = a " " p }
        d = a = p = "" }
      /^DNS configuration \(for scoped/ { pick(); exit }
      /^resolver/ { pick() }
      $1 == "domain" { d = tolower($3); sub(/\.$/, "", d) }
      $1 == "nameserver[0]" { a = $3 }
      $1 == "port" { p = $3 }
      END { pick(); print s }')
    hr_s=${2:-} hr_p=${3:-}
  fi
  hr_status=$(dig +time=2 +tries=1 +noall +comments ${hr_s:+"@$hr_s"} \
    ${hr_p:+-p "$hr_p"} "$1" A "$1" AAAA 2>&1 \
    | awk '/status:/ { sub(/,/, "", $6); print $6 }')
  if [ "$(printf '%s\n' "$hr_status" | grep -c .)" -eq 2 ] \
    && ! printf '%s\n' "$hr_status" | grep -qvE '^(NOERROR|NXDOMAIN)$'; then
    echo ok
  else
    echo unreachable
  fi
}

# hostwarden_resolve_or_unresolved <name> — see Defines above.
hostwarden_resolve_or_unresolved() {
  hru_a=$(hostwarden_resolve "$1")
  if [ -n "$hru_a" ]; then
    printf '%s ' $hru_a
    return
  fi
  hru_r=$(hostwarden_resolve_ok "$1") && return
  case $hru_r in
    no-dig) printf '%s ' "$HOSTWARDEN_UNRESOLVED_NO_DIG" ;;
    *) printf '%s ' "$HOSTWARDEN_UNRESOLVED_UNREACHABLE" ;;
  esac
}

# hostwarden_unresolved_words <string> — see Defines above.
hostwarden_unresolved_words() {
  hw_w=''
  hostwarden_listed "$1" "$HOSTWARDEN_UNRESOLVED_UNREACHABLE" \
    && hw_w='resolver unreachable'
  hostwarden_listed "$1" "$HOSTWARDEN_UNRESOLVED_NO_DIG" \
    && hw_w="${hw_w:+$hw_w, and }no dig here to tell a clean miss from an outage"
  [ -z "$hw_w" ] || echo "$hw_w"
}

hostwarden_resolver() {
  case $(uname -s) in
    Linux) hr_try='getent python3' ;;
    Darwin) hr_try='dscacheutil python3' ;;
    *) hr_try='python3' ;;
  esac
  HOSTWARDEN_RESOLVER=
  for hr_t in $hr_try; do
    command -v "$hr_t" >/dev/null 2>&1 || continue
    [ -n "$(hostwarden_resolve localhost "$hr_t")" ] \
      && { HOSTWARDEN_RESOLVER=$hr_t; return 0; }
  done
  command -v dig >/dev/null 2>&1 && HOSTWARDEN_RESOLVER=dig
  return 0
}

hostwarden_list_entries() {
  [ -f "$1" ] || return 0
  # Read, never word-split: an unquoted expansion would turn the
  # entry * into the names of the files here. A last line without its
  # newline still counts.
  sed -e 's/#.*//' -e 's/^[[:space:]]*-[[:space:]]*//' "$1" \
    | while read -r hl_e _ || [ -n "$hl_e" ]; do
        [ -n "$hl_e" ] || continue
        # * (memory/readonly.md only) is a literal wildcard, matched
        # by string alone (rules/access-control.md → Shared File
        # Format): resolving it answers a question no lookup asks.
        if [ "$hl_e" = '*' ]; then
          printf '%s ' "$hl_e"
        else
          printf '%s %s ' "$hl_e" "$(hostwarden_resolve_or_unresolved "$hl_e")"
        fi
      done
}

hostwarden_listed() {
  for hl_n in $2; do
    case " $1 " in *" $hl_n "*) return 0 ;; esac
  done
  return 1
}
