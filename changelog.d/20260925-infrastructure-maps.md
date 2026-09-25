### Added

- **Hostwarden draws the infrastructure as Mermaid maps, computed from
  memory alone.** `bin/hostwarden-map` writes `memory/maps/`: a WAN
  level of sites and the links between them (IPv4 and IPv6 ranges
  alike), one level per site showing its ranges and hosts, one per
  cluster showing its members and guests, and one per hypervisor
  outside a cluster. Every map pairs its diagram with a table of the
  full fields, links back into the memory it came from, and renders
  on GitHub and Forgejo with no build step. A recorded topology
  finding marks the host it names with a thick amber border, so a
  known problem stays visible on the map rather than only in the
  table below it. A gap in memory — a host with no site on record, a
  range no site claims — draws as "not known" rather than a guess.
  `bin/hostwarden-sync commit` redraws the maps before staging, so a
  map is committed together with the memory it came from.
