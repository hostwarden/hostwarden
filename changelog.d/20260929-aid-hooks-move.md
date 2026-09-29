### Changed

- **Two hooks moved to `.claude/hooks/aid/`.** The authoring note
  and the skills check decide nothing and now live apart from the
  hooks that guard. A session that was running during the update names
  the old paths until it is started again, and reports a hook it
  cannot find.
