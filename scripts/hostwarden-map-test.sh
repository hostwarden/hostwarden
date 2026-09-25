#!/bin/sh
# hostwarden-map-test.sh — golden-fixture matrix for bin/hostwarden-map:
# every level's Mermaid and table, determinism, and the palette's own
# contrast rule, computed here rather than eyeballed
# (rules/network-topology.md's design; .claude/rules/pull-requests.md
# → Checks runs this through CI, never on the workstation).
#
# The fixture's own dates are computed at run time, a fixed number of
# days back from today, so a host that must stay fresh or stale does
# so regardless of when this runs; a literal date in a fixture would
# drift into the other state and the golden files would go stale
# with it.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-map-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
has() { grep -qxF -- "$2" "$1" && ok || bad "$3 ($1)"; }
haspart() { grep -qF -- "$2" "$1" && ok || bad "$3 ($1)"; }
lacks() { grep -qF -- "$2" "$1" && bad "$3 ($1)" || ok; }
exists() { [ -f "$1" ] && ok || bad "$2 ($1)"; }
absent() { [ -f "$1" ] && bad "$2 ($1)" || ok; }

days_ago() {
  e=$(($(date +%s) - $1 * 86400))
  date -j -f %s "$e" +%Y-%m-%d 2>/dev/null || date -d "@$e" +%Y-%m-%d
}
FRESH=$(days_ago 5)
STALE=$(days_ago 100)

# --- the checkout -------------------------------------------------
R="$TMP/repo"
mkdir -p "$R/bin" "$R/.claude/hooks"
cp "$REPO/bin/hostwarden-map" "$R/bin/"
cp "$REPO/.claude/hooks/mode.sh" "$R/.claude/hooks/"
cp "$REPO/VERSION" "$R/VERSION"
git -C "$R" init --quiet
M="$R/memory"
mkdir -p "$M/machines" "$M/clusters/prod"
: >"$M/.hostwarden-workspace"

# server <name> <lines> — a memory.md with the lines given, plus a
# fresh Onboarded:/Housekeeping: pair unless the lines already carry
# their own.
server() {
  mkdir -p "$M/machines/$1"
  {
    echo "# $1"
    printf '%s\n' "$2"
  } >"$M/machines/$1/memory.md"
}

cat >"$M/topology.md" <<EOF
## Sites

- home — the house and the garage rack (user, $FRESH)
- colo-fra — rented rack, Frankfurt (user, $FRESH)
- colo-ams — a third site, touched by nothing but the
  203.0.113.0/24 ambiguity below and its own unambiguous range, so
  colo-fra's own "no WAN entry of its own" case stays provable on
  its own (user, $FRESH)

## Ranges

- 192.0.2.0/24 — site home · VLAN 10 · static only (DHCP off) ·
  suffix corp.example.com (DHCP option) · gateway 192.0.2.1
  (fw1.example.com), MAC 00:1a:2b:3c:4d:01 — from fw1 config,
  pve1, nas1; $FRESH
- 2001:db8::/64 — site home · VLAN 10 · SLAAC · suffix
  corp.example.com (DHCP option) · gateway 2001:db8::1
  (fw1.example.com), MAC 00:1a:2b:3c:4d:01 — from fw1 config; $FRESH
- 203.0.113.0/24 — site home · VLAN untagged · DHCP on ·
  suffix not known · no gateway seen — from pve1; $FRESH
- 203.0.113.0/24 — site colo-ams · VLAN untagged · DHCP on ·
  suffix not known · no gateway seen — from web2; $FRESH
- 10.30.0.0/24 — site colo-ams · VLAN untagged · DHCP on · suffix
  not known · no gateway seen — from web2; $FRESH
- 192.168.50.0/24 — site colo-fra · VLAN untagged · DHCP on ·
  suffix not known · no gateway seen — from web1; $FRESH
- 192.168.50.0/24 — site colo-fra · VLAN untagged · DHCP on ·
  suffix not known · no gateway seen, same prefix as the line from
  web1, not shown to be one network — from pve3; $FRESH
- 10.50.0.0/24 — site colo-fra · VLAN untagged · DHCP on · suffix
  not known · no gateway seen — from web1; $FRESH

## Topology

- 192.0.2.0/24 → 198.51.100.0/24 on wg0, WAN — from pve1; $FRESH
- 192.0.2.0/24 → 203.0.113.0/24 on wg1, WAN — from pve1; $FRESH
- 10.30.0.0/24 → 203.0.113.0/24 on wg2, WAN — from web2; $FRESH
- 192.0.2.0/24, from 192.0.2.5 → 10.40.0.0/24 on wg3, WAN — from
  pve1; $FRESH
- 192.168.50.0/24 → 10.50.0.0/24 via 192.168.50.1, LAN hop — from
  web1; $FRESH

## Topology findings

- WARN: nas1 routes 10.8.0.0/24 via 192.0.2.5 (pve1), and pve1's
  IPv4 forwarding is off (profile of $FRESH).
EOF

server fw1.example.com "- IP: 192.0.2.1
- Site: home (user)
- Appliance: OPNsense 25.7
- Onboarded: $FRESH
- Housekeeping: $FRESH"

server pve1.example.com "- IP: 192.0.2.5
- Site: home (user)
- Cluster: prod (Proxmox VE)
- Appliance: Proxmox VE 9.0.3
- Onboarded: $FRESH
- Housekeeping: $FRESH"

cat >"$M/machines/pve1.example.com/guests.md" <<EOF
# Guests on pve1.example.com

- Inventoried: $FRESH

- 101 web1 (VM): running on pve1, HA. Debian 13 (agent),
  192.0.2.21. mac bc:24:11:00:01:01
- 102 db1 (container): running on pve1. 192.0.2.22.
  mac bc:24:11:00:01:02
EOF

server nas1.example.com "- IP: 192.0.2.30
- Site: home (user)
- Appliance: TrueNAS SCALE 25.04
- Onboarded: $FRESH
- Housekeeping: $FRESH"

server web1.example.com "- IP: 198.51.100.10
- Site: colo-fra (user)
- Onboarded: $STALE
- Housekeeping: $STALE"

server pve3.example.com "- IP: 198.51.100.20
- Site: colo-fra (user)
- Appliance: Proxmox VE 9.0.3
- Onboarded: $FRESH
- Housekeeping: $FRESH"

cat >"$M/machines/pve3.example.com/guests.md" <<EOF
# Guests on pve3.example.com

- Inventoried: $FRESH

- 201 app1 (container): running, autostart. 198.51.100.21.
  mac bc:24:11:00:02:01 → app1.example.com
- web (jail): running, autostart. vnet, 198.51.100.22.
  mac 58:9c:fc:0a:1b:2b, path /usr/local/bastille/jails/web/root
- 202 db3 (container): running, autostart. 2001:db8:1::22.
  mac bc:24:11:00:02:02
EOF

server app1.example.com "- IP: 198.51.100.21
- Runs on: pve3.example.com (container app1)
- Onboarded: $FRESH
- Housekeeping: $FRESH"

server unas1.example.com "- IP: 192.0.2.40
- Site: home (user)
- Appliance: UniFi OS 5.1.2, UNAS Pro
- Onboarded: $FRESH
- Housekeeping: $FRESH"

server udm1.example.com "- IP: 192.0.2.41
- Site: home (user)
- Appliance: UniFi OS 5.1.2, Dream Machine Pro
- Onboarded: $FRESH
- Housekeeping: $FRESH"

# Personal, never shared -- rules/machine-memory.md → Personal versus
# shared, rules/network-topology.md → Excluded from the store.
server localhost "- IP: 127.0.0.1
- Role: workstation (inferred: macOS)
- Onboarded: $FRESH
- Housekeeping: $FRESH"
server laptop.example.com "- IP: 192.0.2.99
- Site: home (user)
- Role: workstation (inferred: macOS)
- Onboarded: $FRESH
- Housekeeping: $FRESH"
# Its own name resolved (rules/machine-memory.md), and a Role: the
# user set to server, the way a Mac mini a team builds on would be
# (rules/first-detection.md → Roles) -- Mode: local is what has to
# keep it off the map, since Role: no longer will.
server buildbox.example.com "- IP: 192.0.2.98
- Mode: local
- Role: server (user)
- Onboarded: $FRESH
- Housekeeping: $FRESH"

# A Cloud Key alone does not say whether it runs UniFi Network or
# only Protect (rules/appliance/unifi-os.md) -- neither is guessed.
server ck1.example.com "- IP: 192.0.2.42
- Site: home (user)
- Appliance: UniFi OS 5.1.2, Cloud Key Gen2 Plus
- Onboarded: $FRESH
- Housekeeping: $FRESH"

# A day that does not exist: both GNU and BSD date silently roll it
# into the next month instead of failing, unless epoch_of catches
# it with a round trip.
server badcal.example.com "- IP: 192.0.2.43
- Site: home (user)
- Onboarded: 2026-02-30
- Housekeeping: 2026-02-30"

# No Site: line at all -- a gap the WAN level still has to show,
# not a host that silently disappears from the fleet.
server nosite.example.com "- IP: 192.0.2.44
- Onboarded: $FRESH
- Housekeeping: $FRESH"

# An IPv6-only address inside the site's own IPv6 range.
server v6host.example.com "- IP: 2001:db8::10
- Site: home (user)
- Onboarded: $FRESH
- Housekeeping: $FRESH"

# A Site: value memory/topology.md's own ## Sites never declared --
# not the same gap as no Site: line at all, but still a gap.
server orphan.example.com "- IP: 192.0.2.45
- Site: mystery (user)
- Onboarded: $FRESH
- Housekeeping: $FRESH"

# 192.168.50.0/24 is recorded twice at colo-fra, from two different
# hosts, "not shown to be one network" -- dup1's IP falls inside it,
# but which of the two unconfirmed records it is actually on is not
# something this workspace has said.
server dup1.example.com "- IP: 192.168.50.5
- Site: colo-fra (user)
- Onboarded: $FRESH
- Housekeeping: $FRESH"

# pve10 exists so a member match against "pve1" cannot succeed by
# an unanchored substring alone -- "on pve10" contains "on pve1".
cat >"$M/clusters/prod/cluster.md" <<EOF
# Cluster prod (Proxmox VE)
- Members: pve1 → pve1.example.com, pve2 (no memory),
  pve10 (no memory)
- HA: on, 3 guests
EOF

cat >"$M/clusters/prod/guests.md" <<EOF
# Guests of cluster prod

- Checked: $FRESH

- 101 web1 (VM): running on pve1, HA. 192.0.2.21.
- 301 onpve10 (VM): running on pve10, HA. 192.0.2.41.
EOF

# --- a personal file, never to be read or quoted -------------------
cat >"$M/user.md" <<'EOF'
Default: alice
- fw1.example.com: root-do-not-quote-me
EOF

# --- run it twice: the second run must write the same bytes --------
( cd "$R" && sh bin/hostwarden-map ) || bad "hostwarden-map exited non-zero"
FIRST="$TMP/first"
cp -r "$M/maps" "$FIRST"
( cd "$R" && sh bin/hostwarden-map ) || bad "second run exited non-zero"
if diff -r "$FIRST" "$M/maps" >"$TMP/diff.txt" 2>&1; then ok
else bad "a same-day rerun over unchanged memory changed output"; cat "$TMP/diff.txt"
fi

MAPS="$M/maps"

# --- the files every level writes ----------------------------------
exists "$MAPS/README.md" "the index"
exists "$MAPS/wan.md" "the WAN level"
exists "$MAPS/sites/home.md" "the home site"
exists "$MAPS/sites/colo-fra.md" "the colo-fra site, filename keeping its hyphen"
exists "$MAPS/clusters/prod.md" "the prod cluster"
exists "$MAPS/hosts/pve3.example.com.md" "pve3's own level, filename keeping its dots"
absent "$MAPS/hosts/pve1.example.com.md" "pve1 is a cluster member, not a standalone hypervisor level"

# --- the generated-file marker, so hostwarden-wrap skips them ------
for f in "$MAPS/README.md" "$MAPS/wan.md" "$MAPS/sites/home.md" \
  "$MAPS/clusters/prod.md" "$MAPS/hosts/pve3.example.com.md"; do
  head -1 "$f" | grep -qE '^<!-- Generated by bin/hostwarden-map .* Do not edit by hand\. -->$' \
    && ok || bad "missing hostwarden-wrap's own skip marker in $f"
done

# --- WAN: shape, class and colour follow each host's own kind ------
WAN="$MAPS/wan.md"
haspart "$WAN" 'h_fw1_example_com{{"fw1.example.com<br/>OPNsense 25.7"}}' \
  "fw1 draws as a router hexagon, appliance as its second line"
has "$WAN" '    class h_fw1_example_com router' "fw1 carries the router class"
haspart "$WAN" 'h_nas1_example_com[("nas1.example.com<br/>TrueNAS SCALE 25.04")]' \
  "nas1 draws as a storage cylinder"
has "$WAN" '    class h_nas1_example_com storage-finding' \
  "nas1 carries the storage-finding class: it is named in the WARN finding below"
haspart "$WAN" 'h_pve1_example_com["pve1.example.com<br/>Proxmox VE 9.0.3"]' \
  "pve1 draws as a hypervisor rectangle"
has "$WAN" '    class h_pve1_example_com host-finding' \
  "pve1 carries the host-finding class, its short name matched in the WARN finding's prose despite the host's own key being its FQDN"
haspart "$WAN" 'h_web1_example_com("web1.example.com<br/>host")' \
  "web1, a plain host with no Appliance:, falls back to its kind as the label's second line"
has "$WAN" '    class h_web1_example_com host-stale' \
  "web1's 100-day-old record makes it host-stale"
has "$WAN" '  site_home === inet' \
  "the WAN-tagged Topology entry from home resolves to no known site, so it draws to Internet"
has "$WAN" '  site_colo_fra -.- inet' \
  "colo-fra has no WAN-tagged entry of its own: a dashed not-known line to Internet, not a missing one"
haspart "$WAN" 'linkStyle' "the not-known link carries its own linkStyle line"

# --- WAN: an ambiguous prefix's destination is never guessed --------
# 203.0.113.0/24 is claimed by two Ranges rows, home (from pve1) and
# colo-ams (from web2): neither reporting host's own hint reaches
# the far side, so the true destination cannot be told from a wrong
# one, and the honest answer is "not known", not a coin flip.
lacks "$WAN" '  site_home === site_home' \
  "the reporting host's own hint must not be applied to the edge's far side too, or an ambiguous destination would resolve back onto its own site"
lacks "$WAN" '  site_home === site_colo_ams' \
  "an ambiguous destination is not resolved by picking whichever site sorts first either -- that is still a guess, just a differently-flavoured one"
lacks "$WAN" '  site_colo_ams === site_home' \
  "same guess, from the other direction"
lacks "$WAN" '  site_colo_ams === site_colo_ams' \
  "colo-ams's own report of the ambiguous prefix must not self-loop any more than home's does"
has "$WAN" '  site_colo_ams === inet' \
  "colo-ams's own WAN entry (10.30.0.0/24, unambiguous) still draws -- only the ambiguous far end falls back to not known, not the whole edge"
lacks "$WAN" '  site_colo_ams -.- inet' \
  "colo-ams has a real WAN entry now, so it does not also get the dashed no-entry-at-all fallback line"

has "$WAN" '| 192.0.2.0/24 | 10.40.0.0/24 | WAN | pve1 | '"$FRESH"' |' \
  "a from-range's own policy-routing source address (\", from 192.0.2.5\") is stripped before the prefix is looked up -- the table's From column is the bare prefix, not the whole clause a Ranges row never equals"
has "$WAN" '    class h_fw1_example_com router' \
  "fw1 is not named in the WARN finding's text, so it keeps its plain router class"
has "$WAN" '| WARN | nas1 routes 10.8.0.0/24 via 192.0.2.5 (pve1), and pve1'"'"'s IPv4 forwarding is off (profile of '"$FRESH"'). | '"$FRESH"' |' \
  "the recorded Topology findings entry appears in its own table, not silently dropped"
haspart "$WAN" 'subgraph unmapped_sites["Site not known"]' \
  "a host with no Site: line at all still gets a subgraph, not silent omission"
haspart "$WAN" 'h_nosite_example_com("nosite.example.com<br/>host")' \
  "nosite.example.com itself appears inside the site-not-known group"
haspart "$WAN" 'h_orphan_example_com("orphan.example.com<br/>host")' \
  "orphan.example.com's Site: mystery is not declared anywhere under memory/topology.md's own ## Sites, so it groups with the never-said-it hosts, not a silent drop"
haspart "$WAN" 'h_unas1_example_com[("unas1.example.com<br/>UniFi OS 5.1.2, UNAS Pro")]' \
  "a UniFi OS console naming a NAS model draws as storage, not a router"
has "$WAN" '    class h_unas1_example_com storage' "unas1 carries the storage class"
haspart "$WAN" 'h_udm1_example_com{{"udm1.example.com<br/>UniFi OS 5.1.2, Dream Mach"}}' \
  "a UniFi OS console naming a gateway model still draws as a router"
has "$WAN" '    class h_udm1_example_com router' "udm1 carries the router class"
lacks "$WAN" 'localhost' \
  "the localhost directory .gitignore always excludes never reaches a map"
lacks "$WAN" 'laptop' \
  "a Role: workstation host is personal and never reaches a map, whatever it is named"
lacks "$WAN" 'buildbox' \
  "a Mode: local host is personal and never reaches a map, even with Role: server"
haspart "$WAN" 'h_ck1_example_com("ck1.example.com<br/>UniFi OS 5.1.2, Cloud Key ")' \
  "a Cloud Key is neither guessed as a router nor as a plain host's storage: it falls to the host default"
has "$WAN" '    class h_ck1_example_com host' \
  "ck1 carries the plain host class, not router or storage"
haspart "$WAN" 'h_badcal_example_com("badcal.example.com<br/>host")' \
  "badcal.example.com still draws -- an impossible date is a gap, not a crash"
has "$WAN" '    class h_badcal_example_com host' \
  "2026-02-30 does not round-trip through date, so it is \"not known\", never silently rolled into a real date and judged fresh or stale by it"

# --- Site: range grouping by CIDR, the "Other hosts" fallback -------
HOME="$MAPS/sites/home.md"
haspart "$HOME" 'subgraph range_192_0_2_0_24["192.0.2.0/24<br/>VLAN 10"]' \
  "home's one range becomes one subgraph, labelled with its VLAN"
haspart "$HOME" 'h_fw1_example_com{{"fw1.example.com<br/>OPNsense 25.7"}}' \
  "fw1's IP places it inside the range subgraph, not the fallback"
haspart "$HOME" 'subgraph range_2001_db8___64["2001:db8::/64<br/>VLAN 10"]' \
  "home's IPv6 range gets its own subgraph the same way its IPv4 one does"
haspart "$HOME" 'h_v6host_example_com("v6host.example.com<br/>host")' \
  "v6host's IPv6 address places it inside the IPv6 range subgraph, not the fallback"
lacks "$HOME" 'subgraph other[' \
  "every home host's IP -- IPv6 included -- resolves to a known range, so there is no fallback group"

COLO="$MAPS/sites/colo-fra.md"
haspart "$COLO" 'subgraph other["Other hosts, range not known"]' \
  "web1's site has no Ranges entry at all: it falls into the honestly-labelled group"
haspart "$COLO" 'h_web1_example_com("web1.example.com<br/>host")' \
  "web1 itself still appears, inside the fallback group"

# --- Site: two Ranges rows sharing one prefix, "not shown to be one
# network" -- distinct subgraphs, and dup1 (which the prefix alone
# cannot tell apart) falls to "Other hosts" rather than being
# guessed into either or drawn in both --------------------------
n=$(grep -c 'subgraph range_192_168_50_0_24' "$COLO")
[ "$n" -eq 2 ] && ok \
  || bad "192.168.50.0/24's two unconfirmed Ranges rows must draw as two distinct subgraphs, not $n (a shared ID merges them into one)"
haspart "$COLO" 'same prefix, not shown to be one network' \
  "each of the two subgraphs says plainly why there are two of them"
n=$(grep -c 'h_dup1_example_com(' "$COLO")
[ "$n" -eq 1 ] && ok \
  || bad "dup1 must appear exactly once, in the Other-hosts fallback -- $n occurrences means it was placed in an ambiguous range subgraph instead"
haspart "$COLO" 'h_dup1_example_com("dup1.example.com<br/>host")' \
  "dup1 itself is still on the map, just honestly unplaced"
haspart "$COLO" 'subgraph range_10_50_0_0_24["10.50.0.0/24' \
  "the LAN hop's other, unambiguous end still gets its own ordinary range subgraph"
lacks "$COLO" 'range_192_168_50_0_24 --- range_10_50_0_0_24' \
  "a LAN hop naming an ambiguous prefix must not connect to range_<prefix> -- id_sh never gave that exact id a subgraph once the prefix split into row-suffixed ones, and Mermaid would invent a bare extra node for it"

# --- Cluster: a guest placed by "running on <short name>" -----------
PROD="$MAPS/clusters/prod.md"
haspart "$PROD" 'subgraph m_pve1["pve1"]' "pve1's member subgraph uses cluster.md's short name"
haspart "$PROD" 'g_101_web1("101 web1<br/>running")' "web1 draws as a VM, rounded"
lacks "$PROD" 'subgraph unplaced[' \
  "web1's \"running on pve1\" resolves it onto a member, leaving nothing unplaced"
has "$PROD" '| pve2 | not known |' \
  "pve2, a cluster member with no memory of its own, is still listed"
haspart "$PROD" 'subgraph m_pve10["pve10"]' "pve10 gets its own member subgraph"
n=$(grep -c 'g_301_onpve10(' "$PROD")
[ "$n" -eq 1 ] && ok \
  || bad "onpve10 (\"running on pve10\") node drawn $n times, not once -- an unanchored \"on pve1\" match would also place it under pve1"

# --- Hypervisor: a container guest, and its own click link ---------
PVE3="$MAPS/hosts/pve3.example.com.md"
haspart "$PVE3" 'g_201_app1[["201 app1<br/>running"]]' "app1, a container, draws as a subroutine shape"
haspart "$PVE3" 'click g_201_app1 "../../machines/app1.example.com/memory.md"' \
  "app1's own memory is one click away, resolved through guests.md's → link"
haspart "$PVE3" 'g_web_web[["web web<br/>running"]]' \
  "a jail is named, not numbered: its one token is both id and name, not the whole rest of the line"
has "$PVE3" '| 202 | db3 | container | running | 2001:db8:1::22 | none |' \
  "db3's only address is IPv6; it lands in the guest table, not \"not known\""

# --- links back into memory: every one resolves --------------------
for f in "$MAPS/wan.md" "$MAPS/sites/home.md" "$MAPS/sites/colo-fra.md" \
  "$MAPS/clusters/prod.md" "$MAPS/hosts/pve3.example.com.md"; do
  d=$(dirname "$f")
  grep -oE '\]\(\.\./[^)]+\.md\)|\]\(\.\./\.\./[^)]+\.md\)' "$f" | tr -d '][)(' \
    | sed 's/^]//' | while IFS= read -r rel; do
    [ -f "$d/$rel" ] && ok || bad "dangling link $rel in $f" >>"$TMP/link-fail"
  done
done
[ -s "$TMP/link-fail" ] && { FAIL=$((FAIL + 1)); cat "$TMP/link-fail"; } || ok

# --- personal memory never reaches a generated file -----------------
for f in "$MAPS/README.md" "$MAPS/wan.md" "$MAPS/sites/home.md" \
  "$MAPS/sites/colo-fra.md" "$MAPS/clusters/prod.md" \
  "$MAPS/hosts/pve3.example.com.md"; do
  lacks "$f" "root-do-not-quote-me" "memory/user.md leaked into $f"
done

# --- size: well inside Forgejo's own default, MERMAID_MAX_SOURCE_-
# CHARACTERS = 50000 (codeberg.org/forgejo/forgejo, forgejo branch,
# custom/conf/app.example.ini, [markup] section) -- verified live,
# not from memory (AGENTS.md → Verify Before Running).
for f in "$MAPS/wan.md" "$MAPS/sites/home.md" "$MAPS/clusters/prod.md"; do
  n=$(awk '/^```mermaid$/,/^```$/' "$f" | wc -c | tr -d ' ')
  [ "$n" -lt 20000 ] && ok || bad "$f's Mermaid block is $n characters, over the safety margin"
done

# --- the palette: every stroke reaches 3:1 against both GitHub
# canvases, every fill/colour pair 4.5:1 against its own fill -------
awk -v light=1 '
  function lin(c,   v) { v = c / 255; return (v <= 0.03928) ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
  function hexval(h,   i, c, v, d) {
    v = 0
    for (i = 1; i <= length(h); i++) { c = tolower(substr(h, i, 1)); d = index("0123456789abcdef", c) - 1; v = v * 16 + d }
    return v
  }
  function lum(hex,   h) { h = hex; sub(/^#/, "", h); return 0.2126 * lin(hexval(substr(h, 1, 2))) + 0.7152 * lin(hexval(substr(h, 3, 2))) + 0.0722 * lin(hexval(substr(h, 5, 2))) }
  function contrast(h1, h2,   l1, l2, t) {
    l1 = lum(h1); l2 = lum(h2)
    if (l1 < l2) { t = l1; l1 = l2; l2 = t }
    return (l1 + 0.05) / (l2 + 0.05)
  }
  /^  classDef / {
    name = $2; fill = ""; stroke = ""; color = ""
    if (match($0, /fill:#[0-9A-Fa-f]{6}/)) fill = substr($0, RSTART + 5, 7)
    if (match($0, /stroke:#[0-9A-Fa-f]{6}/)) stroke = substr($0, RSTART + 7, 7)
    if (match($0, /color:#[0-9A-Fa-f]{6}/)) color = substr($0, RSTART + 6, 7)
    if (stroke != "") {
      cw = contrast(stroke, "#ffffff"); cd = contrast(stroke, "#0d1117")
      if (cw < 3) { print "FAIL: classDef " name "'"'"'s stroke " stroke " is only " cw ":1 against white"; bad++ }
      if (cd < 3) { print "FAIL: classDef " name "'"'"'s stroke " stroke " is only " cd ":1 against #0d1117"; bad++ }
      if (cw >= 3 && cd >= 3) good++
    }
    if (fill != "" && color != "") {
      cf = contrast(fill, color)
      if (cf < 4.5) { print "FAIL: classDef " name "'"'"'s text " color " on " fill " is only " cf ":1"; bad++ }
      else good++
    }
  }
  END {
    print good " palette checks passed, " (bad + 0) " failed"
    exit (bad + 0 > 0)
  }
' "$MAPS/wan.md" && ok || bad "the palette failed its own contrast rule"

# --- a hypervisor removed from memory loses its stale map ----------
rm -rf "$M/machines/pve3.example.com" "$M/machines/app1.example.com"
( cd "$R" && sh bin/hostwarden-map ) || bad "third run exited non-zero"
absent "$MAPS/hosts/pve3.example.com.md" \
  "pve3 is gone from memory; its old map is not left behind as though it were still current"
exists "$MAPS/wan.md" "wan.md itself is untouched by the prune"

# --- topology.md gone: a transient miss on ITS OWN read must not
# prune the site maps just because every host's own memory.md still
# reads fine -- $HOSTS alone would not have caught this, only
# $SITES actually coming back empty does -------------------------
mv "$M/topology.md" "$TMP/topology.md.aside"
( cd "$R" && sh bin/hostwarden-map ) || bad "fourth run exited non-zero"
exists "$MAPS/sites/home.md" \
  "topology.md going missing must not prune every site map: \$SITES coming back empty is not the same as no sites existing, and \$HOSTS alone can't tell the two apart"
exists "$MAPS/sites/colo-fra.md" \
  "colo-fra's map survives topology.md's absence the same way home's does"

# --- a second, separate workspace: sites declared but zero WAN-
# tagged Topology entries at all, the ordinary state before any
# inter-site link has been profiled. grep -c prints its count even
# on no match, exiting 1 only -- a "|| echo 0" fallback fires on
# that exit and appends a second, stray zero, corrupting link_idx
# and aborting the dashed-fallback loop after its first site -------
R2="$TMP/repo2"
mkdir -p "$R2/bin" "$R2/.claude/hooks"
cp "$REPO/bin/hostwarden-map" "$R2/bin/"
cp "$REPO/.claude/hooks/mode.sh" "$R2/.claude/hooks/"
cp "$REPO/VERSION" "$R2/VERSION"
git -C "$R2" init --quiet
M2="$R2/memory"
mkdir -p "$M2/machines/a1.example.com" "$M2/machines/b1.example.com"
: >"$M2/.hostwarden-workspace"
cat >"$M2/topology.md" <<EOF
## Sites

- alpha — first site, no WAN link profiled yet (user, $FRESH)
- beta — second site, same (user, $FRESH)
EOF
{
  echo "# a1.example.com"
  printf '%s\n' "- IP: 10.1.0.1
- Site: alpha (user)
- Onboarded: $FRESH
- Housekeeping: $FRESH"
} >"$M2/machines/a1.example.com/memory.md"
{
  echo "# b1.example.com"
  printf '%s\n' "- IP: 10.2.0.1
- Site: beta (user)
- Onboarded: $FRESH
- Housekeeping: $FRESH"
} >"$M2/machines/b1.example.com/memory.md"
( cd "$R2" && sh bin/hostwarden-map ) >"$TMP/repo2.out" 2>"$TMP/repo2.err"
rc2=$?
[ "$rc2" -eq 0 ] && ok || bad "a workspace with sites but zero WAN Topology entries must not fail the run"
[ -s "$TMP/repo2.err" ] && bad "it must not print to stderr either: $(cat "$TMP/repo2.err")" || ok
WAN2="$M2/maps/wan.md"
exists "$WAN2" "the no-WAN-edges workspace still produces wan.md"
has "$WAN2" '  site_alpha -.- inet' \
  "alpha gets its dashed not-known line when there are zero WAN edges at all, not a corrupted linkStyle"
has "$WAN2" '  site_beta -.- inet' \
  "beta gets its own dashed line too -- the corrupted link_idx used to abort the loop after the first site, silently dropping every one after it"

echo "hostwarden-map: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
