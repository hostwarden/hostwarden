### Fixed

- **Housekeeping checks every Time Machine destination on its own.**
  A Mac that backs up to a local disk and a network share gets one
  state per destination; one that is not mounted or unplugged reads
  "last backup unknown", not "no backup", and the backup is never
  rated CRITICAL while Time Machine is set up.
