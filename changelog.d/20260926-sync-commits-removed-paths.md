### Fixed

- **A workspace commit takes a removed file with the rest.**
  `bin/hostwarden-sync commit` failed when a named path had already
  left the index, by `git rm` or as the old name of a `git mv`, so a
  host's removals needed a commit of their own; they now go in the
  host's one commit, and a path the workspace never held is named
  and skipped.
