### Fixed

- **DNS collision and drift checks missed IPv6 and could mistake a
  broken resolver for a free name.** The shared system-resolver
  lookup behind DNS alias detection, IP drift checks, a host
  rename's name check, and the pre- and post-creation checks in
  `hostwarden-new-guest` only ever asked for IPv4 addresses, so a
  name already claimed only by an AAAA record passed every check
  as free. The same lookup also could not tell a name that
  genuinely resolves to nothing from a resolver it could not reach
  at all, since the tools it used report both cases identically,
  so a DNS outage during an IP drift check could be read as a
  migrated or detached server. The lookup now collects IPv4 and
  IPv6 addresses together and falls back to `dig` to tell a
  resolver outage from a clean negative, and every check built on
  it treats the two differently instead of assuming a name is
  free or an address is gone.
