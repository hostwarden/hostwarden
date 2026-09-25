### Added

- **Hostwarden can write DNS records itself, over SSH, where the
  user has said so.** A name space needs an explicit
  `Hostwarden: write` in `memory/dns.md`, set only on the user's own
  word, and every write is still asked for first with the exact
  record set. A static BIND zone file is edited, checked and
  reloaded; a dynamic or inline-signed BIND zone takes `nsupdate
  -l`; PowerDNS and Knot get their own tools; a resolver set is
  written one member at a time, and a hidden primary's secondaries
  are checked for a lagging serial afterward. Every write is backed
  up first and verified through the resolvers clients actually use,
  not only the authoritative server. A new guest and a host rename
  now write their DNS record set where a name space allows it. A
  zone managed as code, a DS at the registrar, and a DNSSEC key stay
  the user's to change.
