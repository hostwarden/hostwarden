### Changed

- **Log queries stay inside the time limit.** The agent bounds every
  journal or log read by `--since` or `-n` and filters with field
  matches and `-g` instead of piping a whole journal through `grep`
  or `tail`. A precise answer is reported as it is, and a query that
  timed out is narrowed, not repeated.
