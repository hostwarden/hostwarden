### Added

- **A new workspace is asked once where it lives: on a private remote
  or on this machine only.** `bin/hostwarden-init` asks in a terminal,
  and the first session asks where that was left open: publish to a
  new private repository, join an existing workspace, keep it local,
  or not now. `bin/hostwarden-init --remote <url> --create` refuses a
  repository anyone can read or one that already holds commits,
  creates a missing GitHub repository private with gh or says how to
  create it, then commits and pushes the workspace. `--clone` now also
  takes the place of a workspace nothing has been written to yet, and
  `--local` records `Workspace remote: none`.
