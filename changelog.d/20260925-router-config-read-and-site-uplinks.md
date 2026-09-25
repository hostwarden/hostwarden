### Added

- **Hostwarden reads OPNsense, pfSense and UniFi OS network
  configuration, and records how each site reaches the internet.**
  Onboarding and housekeeping read a firewall's or gateway
  console's interfaces, VLANs, DHCP scopes, static routes and WAN
  interfaces over the SSH login already in place, printing only
  allow-listed fields and no free text, and fold them into
  `memory/topology.md`. Each site gets its uplinks: the stack, the
  IPv4 situation, static or dynamic, and the delegated IPv6 prefix.
  CGNAT is recorded only on your word.
  Onboarding asks about them once per site and offers to onboard a
  gateway it does not know yet. Exposing a service says first when
  CGNAT or DS-Lite rules out an IPv4 port forward, direct mail over
  a dynamic uplink becomes an INFO finding, and a Tailscale subnet
  router's line says whether it rewrites source addresses.
