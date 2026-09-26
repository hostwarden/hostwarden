### Changed

- **After an update, the session shows what every release in between
  brought and asks before going on.** The update lists the lead
  clause of each entry, grouped by version, from the `CHANGELOG.md`
  at each release's tag, and the session asks whether to go on
  before any server work; the full text is there on request. A run
  no person answers, such as `claude -p` or the operations host's
  nightly run, asks nothing and goes on; the nightly run writes the
  list to the timer's log.
