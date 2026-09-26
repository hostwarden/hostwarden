### Changed

- **A managed machine's memory lives under `memory/machines/`, not
  `memory/servers/`.** A server, a workstation and a guest were
  always filed the same way; the directory name generalizes to
  match, since a workstation running Hostwarden is never actually a
  server. An existing workspace's `memory/servers/` moves to
  `memory/machines/` by hand — `git -C memory mv servers machines`.
  Its `memory/.gitattributes` changelog merge rule updates itself
  on the next pull.
