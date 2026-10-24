### Added

- **Hostwarden's own key can log in with a certificate from your
  SSH CA.** Recorded in `memory/user.md`, the certificate is offered
  to the hosts you record as taking it, with no `authorized_keys`
  line there; session start reads how long it is still valid and names
  your renewal command before it runs out. Hostwarden never signs
  or renews it, and the key ID it carries now shows in the audits'
  login counts.
