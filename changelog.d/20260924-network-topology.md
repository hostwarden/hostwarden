### Added

- **Hostwarden records the networks its hosts share.** A host's
  full network profile now feeds `memory/topology.md` with the IP
  ranges it sits on, each range's site, VLAN, DHCP state, DNS
  suffix and gateway, and the routes between ranges, read-only and
  from the hosts alone; an appliance adds what its configuration
  says once its file reads one. Onboarding asks which site a host
  is at, the network probe reads the routing table, the gateway's
  MAC, the host's VLAN tags and any routing daemon, and a routing
  daemon is recorded as `Dynamic routing:`. A short name that
  resolves nowhere is offered under the suffixes the ranges record.
