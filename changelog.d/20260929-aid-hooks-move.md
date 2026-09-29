### Changed

- **Four hooks moved to `.claude/hooks/aid/`.** The Markdown wrap,
  the authoring note, the development tools and the skills check
  guard nothing and now live apart from the hooks that do. A session
  that was running during the update names the old paths until it
  is started again, and reports a hook it cannot find.
