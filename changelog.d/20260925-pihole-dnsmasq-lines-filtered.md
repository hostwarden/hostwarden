### Security

- **The security audit no longer prints Pi-hole's custom dnsmasq
  lines whole.** It printed every line of `misc.dnsmasq_lines`,
  including any token in a `txt-record=`; it now reads only the
  `local-service`, `listen-address`, `interface`,
  `except-interface` and `auth-server` lines it judges exposure by.
