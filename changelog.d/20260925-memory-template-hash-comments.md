### Fixed

- **The service policy and user preference templates no longer
  render as a wall of headings.** `service-policy.md.example` and
  `user.md.example` used a shell-style `#` prefix for comment
  lines and commented-out examples; in Markdown a line starting
  with `#` is a heading, so every comment line rendered as one.
  Both templates, and the `rules/service-reload.md` example they
  mirror, now explain themselves in plain prose under real
  section headings.
