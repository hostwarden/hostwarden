### Fixed

- **A partial journal is no longer read as the full answer.** When
  the session is a user outside `systemd-journal`, `adm` and `wheel`,
  the agent checks that it can read the whole journal before it
  draws a conclusion from any journal query, not only from an empty
  one, runs the query under sudo where that works, and otherwise
  reports the result as incomplete.
