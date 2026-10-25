# tests/bin/hostwarden-map/sites.sh — a site's map file is named by
# the site's name alone, whatever else its ## Sites line carries.
# Sourced by tests/bin/hostwarden-map.sh, in the order its PARTS
# lists, into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

R3="$TMP/repo3"
checkout "$R3"
M3="$R3/memory"

# muc has no description at all; ber has none and a sub-entry that
# alone passes the 255 bytes a file name may have; ams has a
# description of several lines; zrh has neither description nor
# provenance, only a sub-entry; Main (North) - Office carries a
# hyphen and parentheses of its own, which a host's Site: line names
# the same way, its provenance after them.
LONG="dual-stack · IPv4 198.51.100.7 on the WAN, provider CGNAT (user)"
LONG="$LONG · IPv4 dynamic (changed $FRESH) · IPv6 /56 delegated,"
LONG="$LONG dynamic (user) · IPv6 /48 on the second uplink, static"
LONG="$LONG (user) · failover to the LTE router, provider NAT (user)"
LONG="$LONG — from fw9 config, pve9, nas9, the provider's portal; $FRESH"
cat >"$M3/topology.md" <<EOF
## Sites

- muc (user, $FRESH)
- ber (user, $FRESH)
  - code: ber (user, $FRESH)
  - uplink fw9 wan: $LONG
- ams — a rented rack in a colocation hall on the city's west side,
  two uplinks from two carriers, a remote-hands contract for the
  weekdays, and a cage shared with a second customer's equipment,
  which the colocation's own staff alone may open (user, $FRESH)
- zrh
  - code: zrh (user, $FRESH)
- Main (North) - Office — the ground floor (user, $FRESH)

## Ranges

- 192.0.2.0/24 — site muc · VLAN untagged · DHCP on · suffix not
  known · no gateway seen — from web9; $FRESH
- 198.51.100.0/24 — site Main (North) - Office · VLAN untagged · DHCP on ·
  suffix not known · no gateway seen — from web8; $FRESH
- 203.0.113.0/24 — site not known · VLAN untagged · DHCP on · suffix
  not known · no gateway seen — from cam9; $FRESH
- 203.0.113.0/24 — site muc · VLAN untagged · DHCP on · suffix not
  known · no gateway seen — from web9; $FRESH
- 2001:db8:1::/64 — site muc · VLAN not known · static (1 host) · gateway
  fe80::1 (link-local) — from vm9; $FRESH

## Topology

- 203.0.113.0/24 → 10.60.0.0/24 on wg0, WAN — from gw9; $FRESH
EOF

# gw9 has no Site: and is named by neither 203.0.113.0/24 line, so
# its WAN entry has no site to start from.
mkdir -p "$M3/machines/gw9"
printf '%s\n' "# gw9" "- IP: 203.0.113.9" >"$M3/machines/gw9/memory.md"
mkdir -p "$M3/machines/web8.example.com"
printf '%s\n' "# web8.example.com" "- Site: Main (North) - Office (user)" \
  >"$M3/machines/web8.example.com/memory.md"

# A VM at a provider and a VM on a hypervisor Hostwarden does not
# manage are drawn in their site; a guest of a hypervisor in memory
# is drawn on that hypervisor's map only.
vm_memory() {
  mkdir -p "$M3/machines/$1"
  printf '%s\n' "# $1" "- IP: $2" "- Site: muc (user)" "- $3" \
    >"$M3/machines/$1/memory.md"
}
vm_memory vm9.example.com 192.0.2.19 "Runs on: Hetzner (cloud)"
vm_memory vm8.example.com 192.0.2.18 "Runs on: esx-office (user, not managed)"
vm_memory vm7.example.com 192.0.2.17 "Runs on: pve9.example.com (VM 107)"
vm_memory pve9.example.com 192.0.2.9 "Appliance: Proxmox VE 9.0"
vm_memory vm6.example.com 192.0.2.16 "Runs on: nas9.example.com (VM)"
vm_memory nas9.example.com 192.0.2.8 "Role: file server"
vm_memory esx9.example.com 192.0.2.7 "Appliance: ESXi 8.0"
printf '%s\n' "# Guests of pve9.example.com" "" \
  "- 107 vm7 (VM): running, autostart. 192.0.2.17. → vm7.example.com" \
  >"$M3/machines/pve9.example.com/guests.md"

( cd "$R3" && sh bin/hostwarden-map ) >"$TMP/repo3.out" 2>"$TMP/repo3.err" \
  && ok || bad "hostwarden-map exited non-zero on sites without a description"
# A file it cannot create is an error on stderr, not an exit status.
if [ -s "$TMP/repo3.err" ]; then
  bad "hostwarden-map wrote to stderr:"; cat "$TMP/repo3.err"
else ok
fi
LC_ALL=C ls "$M3/maps/sites" >"$TMP/repo3.sites"
printf '%s\n' ams.md ber.md 'main (north) - office.md' muc.md zrh.md >"$TMP/repo3.want"
if cmp -s "$TMP/repo3.want" "$TMP/repo3.sites"; then ok
else bad "site map files are not named by the site's name alone:"; cat "$TMP/repo3.sites"
fi
haspart "$M3/maps/sites/muc.md" "192.0.2.0/24" \
  "a range's \"site muc\" reaches the site muc keys as"
haspart "$M3/maps/sites/muc.md" 'click h_vm9_example_com "../../machines/vm9.example.com/memory.md" _top' \
  "a VM at a provider is drawn in its site"
haspart "$M3/maps/sites/muc.md" 'click h_vm8_example_com "../../machines/vm8.example.com/memory.md" _top' \
  "a VM on a hypervisor that is not managed is drawn in its site"
has "$M3/maps/sites/muc.md" "| vm9.example.com | host | 192.0.2.19 | [memory](../../machines/vm9.example.com/memory.md) |" \
  "a VM at a provider has a row in its site's hosts table"
lacks "$M3/maps/sites/muc.md" "vm7.example.com" \
  "a guest of a hypervisor in memory is left to that hypervisor's map"
haspart "$M3/maps/hosts/pve9.example.com.md" 'click g_107_vm7 "../../machines/vm7.example.com/memory.md" _top' \
  "a guest of a hypervisor in memory is drawn on the hypervisor's map"
lacks "$M3/maps/sites/muc.md" "subgraph range_2001_db8_1___64" \
  "a range none of the site's hosts is placed in is not an empty subgraph"
haspart "$M3/maps/sites/muc.md" "range_2001_db8_1___64[" \
  "a range none of the site's hosts is placed in is drawn as one node"
lacks "$M3/maps/wan.md" "subgraph site_ams[" \
  "a site none of whose hosts is drawn is not an empty subgraph on the WAN map"
haspart "$M3/maps/wan.md" "site_ams[" \
  "a site none of whose hosts is drawn is one node on the WAN map"
haspart "$M3/maps/sites/muc.md" 'click h_vm6_example_com "../../machines/vm6.example.com/memory.md" _top' \
  "a VM whose Runs on: host draws no map of its own is drawn in its site"
haspart "$M3/maps/hosts/esx9.example.com.md" 'h_esx9_example_com["esx9.example.com<br/>no guest drawn"]' \
  "a hypervisor with no guest is one box, not an empty subgraph"
lacks "$M3/maps/hosts/esx9.example.com.md" "subgraph h_esx9_example_com" \
  "a hypervisor with no guest is not an empty subgraph"
has "$M3/maps/wan.md" "| muc | (user, $FRESH) | [maps](sites/muc.md) |" \
  "a site without a description keeps its provenance, not its name, as the description"
haspart "$M3/maps/wan.md" "| ams | a rented rack in a colocation hall" \
  "a long description stays the description"
haspart "$M3/maps/sites/main (north) - office.md" "web8.example.com" \
  "a host whose Site: names a site of several words lands on that site's map"
haspart "$M3/maps/sites/main (north) - office.md" "198.51.100.0/24" \
  "a range's site of several words reaches that site's map"
has "$M3/maps/wan.md" "| ber | (user, $FRESH) | [maps](sites/ber.md) |" \
  "a site's description and date come from its own line, not its sub-entries"
has "$M3/maps/wan.md" "| zrh |  | [maps](sites/zrh.md) |" \
  "a site with only a sub-entry has no description"
lacks "$M3/maps/wan.md" "site_not_known ===" \
  "a range's \"site not known\" and a host with no Site: are never one site"
