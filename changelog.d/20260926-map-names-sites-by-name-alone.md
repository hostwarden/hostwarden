### Fixed

- **A site's map is named by the site alone.** `bin/hostwarden-map`
  named the map of a `## Sites` line without a description after the
  whole line, its sub-entries included, which gave broken file names
  and, with a long uplink line, failed with "File name too long". It
  now reads name, description and date from the site's own line, and
  a site name of several words matches its hosts' `Site:` and its
  ranges whole.
