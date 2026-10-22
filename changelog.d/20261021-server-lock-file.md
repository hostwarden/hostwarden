### Added

- **A server can lock itself against changes.** `allow_changes = false`
  in `/etc/hostwarden.conf`, or in `/etc/heinzel.conf` as Heinzel
  reads it, puts every session into read-only mode for that host,
  local mode included. An unreadable or empty file, any value other
  than `true` and a missing end marker lock too. Hostwarden never
  writes, moves or deletes either file, and the taboo guard denies
  those writes under the spellings of the name a pattern can recognise.
