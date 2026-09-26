### Fixed

- **Commands on a host answer in English, whatever its language.**
  On a host set to another language, a translated label broke a
  check without an error: German `ufw` names its policy line
  `Voreinstellung:`, so the default-deny check found nothing, and
  `sudo -V`, `apt-cache policy` and `free -h` changed their labels
  and decimal points the same way. Each call to a host now sets
  `LC_ALL=C` first, in the call itself rather than forwarded by SSH.
