### Fixed

- **A forgotten `scripts/lab.sh` container no longer runs forever.**
  `scripts/lab.sh up` gives it a fixed lifetime,
  `HOSTWARDEN_LAB_TTL` seconds (default 6h), and the container
  engine removes it on its own once that ends, whether or not
  `down` is ever run. A container already running from before this
  change is replaced with one that has a lifetime the first time
  `up` sees it.
