# lib/hostwarden-map/wan.sh — step 5: the WAN level. Sourced by
# bin/hostwarden-map, in the order its PARTS lists, into the one
# shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- step 5: the WAN level -------------------------------------------
# esc_sh <text> -- esc(), from the shell, for a label built outside
# awk.
esc_sh() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/"/\&quot;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# site_of_prefix <prefix> [<reporting host>] -- the site RANGES
# gives a range prefix, empty when the prefix is not one this
# workspace records OR when more than one Ranges row carries it and
# neither disambiguation below settles which: a definite site drawn
# for a prefix two sites both claim is a guess dressed as a fact,
# and "A gap in memory draws as 'not known', never a guess" is this
# feature's own rule (rules/network-topology.md → Range identity:
# 192.168.1.0/24 at a dozen sites is exactly the case the store
# keeps as separate lines rather than merging). The row whose own
# "from <hosts>" names <reporting host> wins first, then the row
# whose site matches that host'"'"'s own Site:; only a genuinely
# unambiguous single row resolves with no hint at all.
site_of_prefix() {
  sop_p=$1 sop_h=${2:-}
  awk -F '\t' -v p="$sop_p" -v h="$sop_h" -v hostfile="$HOSTS" '
    BEGIN {
      if (h != "") {
        while ((getline hl < hostfile) > 0) {
          split(hl, hf, "\t")
          if (hf[1] == h) { hsite = hf[2]; break }
        }
      }
    }
    $1 == p {
      n++; site[n] = $2; raw[n] = $6
      if (first == "") first = $2
    }
    END {
      if (h != "") {
        for (i = 1; i <= n; i++) {
          # A source token is "<host>" or "<host> config"
          # (rules/network-topology.md): a plain word match, not an
          # exact one, so "fw1 config" still answers for "fw1".
          m = raw[i]; sub(/.*from /, "", m); sub(/;.*/, "", m)
          if (match(m, "(^|, )" h "( |,|$)")) { print site[i]; exit }
        }
        for (i = 1; i <= n; i++) if (site[i] == hsite) { print site[i]; exit }
      }
      if (n <= 1) print first
    }
  ' "$RANGES"
}

# ip2int <a.b.c.d> -- an IPv4 address as one integer on stdout;
# fails on anything else, IPv6 included -- ranges.tsv'"'"'s own grammar
# is IPv4 only (rules/network-topology.md).
ip2int() {
  IFS=. read -r o1 o2 o3 o4 <<EOF
$1
EOF
  case $o1.$o2.$o3.$o4 in *[!0-9.]* | '.'*) return 1 ;; esac
  [ -n "$o4" ] || return 1
  echo $((o1 * 16777216 + o2 * 65536 + o3 * 256 + o4))
}

# in_cidr4 <ip> <prefix> -- exit 0 when <ip> falls inside <prefix>
# (a.b.c.d/n); integer division only, no bitwise ops, so the one
# true awk this reasons the same way could follow it line for line.
in_cidr4() {
  net=${2%/*}; bits=${2#*/}
  case $bits in '' | *[!0-9]*) return 1 ;; esac
  [ "$bits" -ge 0 ] && [ "$bits" -le 32 ] || return 1
  ipn=$(ip2int "$1") || return 1
  netn=$(ip2int "$net") || return 1
  block=1 i=0
  while [ "$i" -lt $((32 - bits)) ]; do block=$((block * 2)); i=$((i + 1)); done
  [ $((ipn / block)) -eq $((netn / block)) ]
}

# in_cidr6 <ip> <prefix> -- exit 0 when <ip> falls inside an IPv6
# <prefix> (a:b::c/n; rules/network-topology.md → Sites allows an
# IPv6 prefix same as an IPv4 one). No 128-bit arithmetic either:
# each address is expanded to its 32 lowercase hex digits (a plain
# string), the whole hex digits up to the prefix compared as text,
# and a partial digit at the boundary compared as the small integer
# it is, the same block trick in_cidr4 uses one nibble at a time.
in_cidr6() {
  awk -v ip="$1" -v prefix="$2" '
    function hexval(h,   c, d) { c = tolower(h); d = index("0123456789abcdef", c) - 1; return d }
    function expand6(addr,   halves, l, r, lp, rp, gp, groups, i, n, pad, g, out) {
      if (index(addr, "::") > 0) {
        n = split(addr, halves, "::")
        if (n > 2) return ""
        l = (halves[1] == "") ? 0 : split(halves[1], lp, ":")
        r = (halves[2] == "") ? 0 : split(halves[2], rp, ":")
        pad = 8 - l - r
        if (pad < 0) return ""
        n = 0
        for (i = 1; i <= l; i++) groups[++n] = lp[i]
        for (i = 1; i <= pad; i++) groups[++n] = "0"
        for (i = 1; i <= r; i++) groups[++n] = rp[i]
      } else {
        n = split(addr, gp, ":")
        if (n != 8) return ""
        for (i = 1; i <= n; i++) groups[i] = gp[i]
      }
      out = ""
      for (i = 1; i <= 8; i++) {
        g = (i in groups) ? groups[i] : "0"
        if (g !~ /^[0-9A-Fa-f]{1,4}$/) return ""
        while (length(g) < 4) g = "0" g
        out = out tolower(g)
      }
      return out
    }
    BEGIN {
      split(prefix, pp, "/")
      bits = pp[2] + 0
      if (pp[2] !~ /^[0-9]+$/ || bits < 0 || bits > 128) exit 1
      iph = expand6(ip); neth = expand6(pp[1])
      if (iph == "" || neth == "") exit 1
      full = int(bits / 4)
      if (full > 0 && substr(iph, 1, full) != substr(neth, 1, full)) exit 1
      rem = bits % 4
      if (rem == 0) exit 0
      a = hexval(substr(iph, full + 1, 1)); b = hexval(substr(neth, full + 1, 1))
      block = 2 ^ (4 - rem)
      exit (int(a / block) == int(b / block)) ? 0 : 1
    }
  ' </dev/null
}

# in_cidr <ip> <prefix> -- exit 0 when <ip> falls inside <prefix>,
# IPv4 or IPv6, told apart by the one character an IPv6 address
# always has and an IPv4 one never does.
in_cidr() {
  case $1 in *:*) in_cidr6 "$1" "$2" ;; *) in_cidr4 "$1" "$2" ;; esac
}

render_wan() {
  wan_flow="$WORK/wan-flow.mmd"
  wan_table="$WORK/wan-table.md"
  wan_date="" link_idx=0

  {
    echo "flowchart LR"
    echo '  inet(("Internet"))'
    echo "  class inet internet"
    sort -t "$US" -k1,1 "$SITES.us" | while IFS="$US" read -r s desc sdate; do
      [ -n "$s" ] || continue
      sid="site_$(id_sh "$s")"
      printf '  subgraph %s["%s"]\n' "$sid" "$(esc_sh "$s")"
      echo "    direction TB"
      # shellcheck disable=SC2034 # hs is the row's own site; not needed once filtered to it
      awk -F '\t' -v s="$s" '$2 == s && $8 == "" { print }' "$HOSTS" \
        | LC_ALL=C sort -t '	' -k1,1 | tr '\t' "$US" \
        | while IFS="$US" read -r h hs c k a ip d ro hf st; do
          host_node "    " "$h" "$k" "$a" "$st" "../machines" "$hf"
        done
      echo "  end"
    done

    # A host with no Site: line at all, and one whose Site: names
    # somewhere memory/topology.md's own ## Sites never declared,
    # are both "not known" here -- neither reaches the loop above,
    # which only ever iterates the sites that loop actually knows.
    awk -F '\t' -v sitesfile="$SITES" '
      BEGIN { while ((getline sl < sitesfile) > 0) { split(sl, sf, "\t"); known[sf[1]] = 1 } }
      !($2 in known) && $8 == "" { print }
    ' "$HOSTS" \
      | LC_ALL=C sort -t '	' -k1,1 | tr '\t' "$US" \
      | while IFS="$US" read -r h hs c k a ip d ro hf st; do
        host_node "    " "$h" "$k" "$a" "$st" "../machines" "$hf"
      done >"$WORK/wan-unknown-hosts.mmd"
    if [ -s "$WORK/wan-unknown-hosts.mmd" ]; then
      # Never "site_" + anything: every real site's own subgraph ID
      # is exactly that prefix plus id_sh() of its name, and id_sh()
      # can turn any site name into any lowercase/digit/underscore
      # string, so a synthetic ID sharing that prefix could collide
      # with one a site is actually named -- "not known" itself,
      # said plainly, included.
      echo '  subgraph unmapped_sites["Site not known"]'
      echo "    direction TB"
      cat "$WORK/wan-unknown-hosts.mmd"
      echo "  end"
    fi

    # Mermaid drops a `class` on a subgraph that later gets an edge
    # to a node outside it -- verified with the diagram-render tool:
    # the class survives only when it comes after every edge that
    # touches the subgraph. So every "class <site> site" line waits
    # until the edges below are written, not the subgraph'"'"'s own
    # `end`.

    # WAN-tagged Topology entries, resolved through Ranges to a site
    # on each side; one drawn edge per (site, site) pair, the site
    # with no such entry getting one dashed line to the Internet
    # instead, so a gap in #273'"'"'s uplink data still shows as one.
    : >"$WORK/wan-wired"
    # shellcheck disable=SC2034 # eraw is read to consume the row; edate is not used here
    sort -t "$US" -k1,1 "$EDGES.us" | while IFS="$US" read -r efrom eto etag ehost edate eraw; do
      [ "$etag" = WAN ] || continue
      # The hint is only good for the reporting host'"'"'s own side: it
      # is on efrom (that is whose routing table this is), not on
      # eto, so hinting the far side with the same host would find
      # its own range every time a shared prefix put it there too,
      # turning an ambiguous destination into a wrong one instead
      # of the honest guess site_of_prefix already falls back to.
      fs=$(site_of_prefix "$efrom" "$ehost")
      [ -n "$fs" ] || continue
      ts=$(site_of_prefix "$eto")
      key="$fs|${ts:-Internet}"
      grep -qxF "$key" "$WORK/wan-wired" 2>/dev/null && continue
      echo "$key" >>"$WORK/wan-wired"
      echo "$fs" >>"$WORK/wan-wired.sites"
      [ -n "$ts" ] && echo "$ts" >>"$WORK/wan-wired.sites"
      a="site_$(id_sh "$fs")"
      b="inet"; [ -n "$ts" ] && b="site_$(id_sh "$ts")"
      printf '  %s === %s\n' "$a" "$b"
    done >"$WORK/wan-edges1.mmd"
    cat "$WORK/wan-edges1.mmd"
    # grep -c prints the count on stdout even for zero matches -- it
    # only exits 1 then, which command substitution ignores. The
    # "|| echo 0" this used to have fired on that same exit 1 and
    # appended a second, stray "0" line, corrupting link_idx into
    # "0\n0" whenever a workspace has sites but no WAN-tagged
    # Topology entry yet -- an ordinary early state, not a partial
    # read.
    link_idx=$(grep -c ' === ' "$WORK/wan-edges1.mmd" 2>/dev/null)

    cut -f1 "$SITES" | LC_ALL=C sort -u | while IFS='	' read -r s; do
      [ -n "$s" ] || continue
      [ -f "$WORK/wan-wired.sites" ] && grep -qxF "$s" "$WORK/wan-wired.sites" && continue
      printf '  site_%s -.- inet\n' "$(id_sh "$s")"
      printf '  linkStyle %s stroke:#8a8a8a,stroke-dasharray:4 3\n' "$link_idx"
      link_idx=$((link_idx + 1))
    done

    cut -f1 "$SITES" | LC_ALL=C sort -u | while IFS='	' read -r s; do
      [ -n "$s" ] || continue
      printf '  class site_%s site\n' "$(id_sh "$s")"
    done
    [ -s "$WORK/wan-unknown-hosts.mmd" ] && echo '  class unmapped_sites site'
  } >"$wan_flow"

  {
    echo "### Sites"
    echo
    echo "| Site | Description | Memory |"
    echo "| :--- | :--- | :--- |"
    while IFS="$US" read -r s desc sdate; do
      [ -n "$s" ] || continue
      printf '| %s | %s | [maps](sites/%s.md) |\n' "$s" "$desc" "$(slug_sh "$s")"
      wan_date=$(date_max "$wan_date" "$sdate")
    done <"$SITES.us"
    echo
    echo "### Site-to-site links"
    echo
    echo "| From | To | Tag | Source | Date |"
    echo "| :--- | :--- | :--- | :--- | :--- |"
    # shellcheck disable=SC2034 # raw is the full line, unused here
    while IFS="$US" read -r from to tag host edate raw; do
      [ -n "$from" ] || continue
      printf '| %s | %s | %s | %s | %s |\n' "$from" "$to" "$tag" "$host" "$edate"
      wan_date=$(date_max "$wan_date" "$edate")
    done <"$EDGES.us"
    if [ -s "$FINDINGS.us" ]; then
      echo
      echo "### Topology findings"
      echo
      echo "| Severity | Finding | Date |"
      echo "| :--- | :--- | :--- |"
      # shellcheck disable=SC2034 # fraw is the full line, unused here
      while IFS="$US" read -r sev text fdate fraw; do
        [ -n "$sev" ] || continue
        printf '| %s | %s | %s |\n' "$sev" "$(esc_sh "$text")" "$fdate"
        wan_date=$(date_max "$wan_date" "$fdate")
      done <"$FINDINGS.us"
    fi
  } >"$wan_table"

  # shellcheck disable=SC2034 # only h and d matter for the newest date
  while IFS="$US" read -r h s c k a ip d ro hf st; do
    [ -n "$h" ] || continue
    wan_date=$(date_max "$wan_date" "$d")
  done <"$HOSTS.us"

  write_map_file "$MAPS/wan.md" \
    "memory/topology.md and every host's memory.md" \
    "WAN" "[Index](README.md)" "$wan_flow" "$wan_table"
  WAN_DATE=$wan_date
}
