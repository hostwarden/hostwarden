### Fixed

- **The macOS route probe could mistake a connected network for a
  tunnel's peer route.** Its filter cannot tell the two apart by
  flags there, so the reading notes now point to the `ifconfig`
  cross-reference instead of claiming the filter already leaves
  every connected route out on every platform.
- **OPNsense's automatic per-WAN gateway went missing from a
  network profile with no explanation.** A gateway OPNsense builds
  on its own for a DHCP or PPPoE WAN never reaches `config.xml`, so
  the read now says where its live address comes from instead of
  leaving the gap unexplained.
