### Added

- **The workspace opens on an overview page.** `bin/hostwarden-map`
  also writes `memory/README.md`: the sites with their maps, the open
  findings of each host's last housekeeping run and security audit,
  and the hosts not reached within their cadence — nightly for a host
  fleet read reaches, 90 days for any other. Services, critical hosts,
  expiry dates and untested backups each say in one line that memory
  does not record them yet. The page counts and links, never copying
  a host's detail, and a `memory/README.md` you wrote yourself is left
  alone. `bin/hostwarden-sync commit` commits it with the maps; where
  two machines both redrew one, a pull keeps the version pulled and
  the next commit draws it again.
