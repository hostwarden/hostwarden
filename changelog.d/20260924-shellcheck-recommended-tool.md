### Added

- **`bin/hostwarden-doctor` reports `shellcheck` as a recommended
  tool in an operations checkout.** A shell script written for a
  host — a deployed file or a `memory/tools/<name>` one — is
  linted with it first, before it reaches a host, when the doctor
  reports it installed.
