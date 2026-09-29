### Changed

- **A version check says `UNKNOWN` where it cannot read what is
  installed.** Software that memory names without a version is read
  from the host, and where that fails the housekeeping report shows
  `UNKNOWN` with the reason, as `INFO`, in place of a comparison that
  never took place.
