### Fixed

- **A community script's application is version-checked against what is
  installed.** Housekeeping counted such a guest's application among
  the software it always checks, but memory held only the script's
  name, so there was nothing to compare. Memory now also says where
  the version is read, worked out from the script's install and update
  code, and again every 14 days. Each check reads the version from the
  guest, where the script's engine keeps it, and before the guest's
  first update from the file the install script wrote. An application
  the script installs from a package repository is left to the pending
  updates, until a script's update function moves it to a deploy helper
  and the file is there; one it builds from source has no version to
  read.
