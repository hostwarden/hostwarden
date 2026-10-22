### Added

- **Mail DNS checks for a host that sends or receives mail.** The
  agent reads SPF, the DKIM selector's key length, DMARC, MTA-STS,
  TLS reporting, reverse DNS against the HELO name and CAA, mostly
  from the workstation, and rates each finding. Housekeeping runs
  it for a host with a mail server, and a missing record comes with
  the one to add. Strict values
  such as DMARC `reject` are recommendations, never a baseline
  failure, and a parked domain gets a null MX, `v=spf1 -all` and
  DMARC `reject` as a proposal. It changes no zone.

### Changed

- **A removed host leaves no record behind.** When a guest
  or host is deleted, the answer ends with the DNS records
  that name it: A, AAAA, CNAMEs that target it, MX and PTR. The user
  removes them, or Hostwarden does where the zone is set to `write`.
