# shellcheck shell=sh
# resolve.sh — a name's IPv4 addresses the way
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
#   hostwarden_resolve4 <name> [<tool>]
#       prints every IPv4 address <tool>, else HOSTWARDEN_RESOLVER,
#       gives <name>, one per line; nothing where there is no tool.
#   hostwarden_list_entries <file>
#       prints the entries of an access list, each followed by the
#       addresses it resolves to, on one line; nothing where the file
#       is missing.
#   hostwarden_listed <entries> <names>
#       true when one of the space-separated <names> is among the
#       space-separated <entries>.

hostwarden_resolve4() {
  case ${2:-${HOSTWARDEN_RESOLVER:-}} in
    getent) getent ahostsv4 "$1" 2>/dev/null | awk '{ print $1 }' | sort -u ;;
    dscacheutil) dscacheutil -q host -a name "$1" 2>/dev/null \
      | awk '$1 == "ip_address:" { print $2 }' | sort -u ;;
    python3) python3 -c 'import socket, sys
for a in sorted({i[4][0] for i in socket.getaddrinfo(
        sys.argv[1], None, socket.AF_INET)}):
    print(a)' "$1" 2>/dev/null ;;
    dig) dig +short +time=2 +tries=1 A "$1" | grep -E '^[0-9.]+$' ;;
  esac
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
    [ -n "$(hostwarden_resolve4 localhost "$hr_t")" ] \
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
        printf '%s %s ' "$hl_e" "$(hostwarden_resolve4 "$hl_e" | tr '\n' ' ')"
      done
}

hostwarden_listed() {
  for hl_n in $2; do
    case " $1 " in *" $hl_n "*) return 0 ;; esac
  done
  return 1
}
