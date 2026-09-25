### Added

- **Hostwarden writes a DNS record through an API where a name
  space allows it.** A provider's zone (Cloudflare, Hetzner, INWX,
  a registrar) is written through its own API, with a token scoped
  to the one zone where the provider offers that; a router
  appliance's host overrides (OPNsense, pfSense, UniFi OS) go
  through its own write access, set up only where the user asked
  for it. Both ask each time with the exact record set, back up
  first, and never touch a zone managed as code, a DS record at the
  registrar, or a DNSSEC key.
