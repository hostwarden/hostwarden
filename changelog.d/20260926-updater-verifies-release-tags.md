### Security

- **The updater checks out only a release tag whose signature
  verifies.** In an operations checkout, `hostwarden-update` checks
  each release tag against the release key of the version it is on
  before moving to it, and refuses one that does not verify: the
  update reports it, stops, and the checkout stays where it is.
  `--check` names such a tag too.
