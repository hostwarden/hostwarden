### Changed

- **The workspace's `README.md` opens with how to put the workspace
  to use.** The generated overview page now says first that the
  repository is Hostwarden's memory alone, and how it becomes the
  `memory/` of a Hostwarden checkout: clone Hostwarden, run
  `bin/hostwarden-init --clone` with the workspace's URL, start a
  session. The Hostwarden it names is the one the checkout that
  wrote the page was cloned from, so a team that keeps its own copy,
  a fork or a mirror, is sent there and not to the upstream project;
  a checkout cloned from upstream says where a team's own copy would
  take precedence.
