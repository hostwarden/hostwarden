### Fixed

- **A map that cannot be written fails `bin/hostwarden-map`.** A
  read-only `memory/maps`, a full disk or a file name too long
  printed one line and the run still ended with exit 0, so
  `hostwarden-sync commit` took half-redrawn maps for current. Each
  map, the index and the overview page are now written through a
  temporary file and moved into place, the file that failed is named
  in a `hostwarden-map:` line, the run exits non-zero and the old
  file stays whole. `hostwarden-sync commit` still commits your own
  files, adds no maps on top and says that the maps are stale.
