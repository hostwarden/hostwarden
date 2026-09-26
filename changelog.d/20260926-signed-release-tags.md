### Security

- **Release tags are signed.** Every release from v1.0.0 on is an
  annotated tag signed with Hostwarden's release key; the updates
  page publishes the key and its fingerprint, so a checkout can
  check a tag with `git verify-tag` before trusting it.
