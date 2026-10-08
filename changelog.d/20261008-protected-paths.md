### Added

- **Protected paths on a writable host.** Two glob lists in a host's
  `memory/machines/<hostname>/rules.md`, or in
  `memory/custom-rules/all.md` for every host, keep single paths
  safe where the host itself is not read-only: a `readonly` path is
  read, listed and stat'ed but never written, deleted, moved or
  re-permissioned by any command of Hostwarden's own that reaches
  it, and a `confirm` path is
  touched only after the exact command was shown and answered with
  the literal word CONFIRM. The blacklist and the read-only list
  still win over both. The idea comes from Heinzel issue 55
  (https://github.com/wintermeyer/heinzel/issues/55).
