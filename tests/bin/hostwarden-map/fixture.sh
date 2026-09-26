# tests/bin/hostwarden-map/fixture.sh — the checkout and the fixture
# memory every check reads. Sourced by tests/bin/hostwarden-map.sh,
# in the order its PARTS lists, into the one shell every part
# shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the checkout -------------------------------------------------
R="$TMP/repo"
mkdir -p "$R/bin" "$R/lib"
cp "$REPO/bin/hostwarden-map" "$R/bin/"
cp "$REPO/lib/mode.sh" "$R/lib/"
cp -R "$REPO/lib/hostwarden-map" "$R/lib/"
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
