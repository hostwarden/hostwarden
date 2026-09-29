### Fixed

- **A community script's application is version-checked against what is
  installed.** Housekeeping counted such a guest's application among
  the software it always checks, but memory held only the script's
  name, so there was nothing to compare. Memory now also says where
  the version is read, worked out once from the script, and each
  check reads it from the guest, where the script's engine keeps it.
  An application the script installs from a package repository is left
  to the pending updates, and one it builds from source has no version
  to read. The read prints nothing but a line shaped like a version,
  and never from a link or a file that is not world-readable.
