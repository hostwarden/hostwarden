### Added

- **Hostwarden records where the fleet's DNS names come from, and
  proposes the records a new host or service needs.** Onboarding and
  housekeeping read the zones, views, forwards and local records of
  a DNS server Hostwarden manages into `memory/dns.md`, one line per
  name space with its source, DNSSEC state and who manages it. A new
  guest and a host rename get the exact record set to add — a
  service name as a CNAME to its host, A and AAAA only where DNS
  requires them, a private address in internal views only. Checks
  report a DS that matches no key, resolvers of one set that answer
  differently (fleet audit), a local record that shadows a forwarded
  zone, and a private address in an external view. Hostwarden writes
  no DNS record itself.
