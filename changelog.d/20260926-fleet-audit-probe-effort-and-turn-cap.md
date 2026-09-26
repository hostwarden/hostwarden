### Changed

- **The fleet audit's per-host probe runs at medium effort and stops
  after 60 turns.** It still uses the session's model. A probe that
  hits the cap is continued once to finish its row; one that still
  has no status gets no column, and the audit puts that host to the
  user.
