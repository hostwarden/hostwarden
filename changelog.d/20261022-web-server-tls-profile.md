### Added

- **Web servers get a TLS and header profile.** Installing or
  changing nginx, Apache, Caddy or HAProxy as a web server or
  reverse proxy now follows Mozilla's Intermediate profile: TLS 1.2
  and 1.3 with forward-secret AEAD suites, a certificate from ACME,
  port 80 only redirecting, HSTS, and no version in `Server`. The
  security audit probes the same from the host itself, with a
  deadline on its probes where the host has `timeout`, and rates what it finds.
  HSTS preload, re-encrypting to backends, TLS 1.3
  only and cache limits are offered once and become a decision
  only when you say so.
