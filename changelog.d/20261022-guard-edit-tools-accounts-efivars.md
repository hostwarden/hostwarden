### Changed

- **The guard also blocks the edit tools on the account files and
  the EFI variables.** Writing `/etc/passwd`, `shadow`, `group`,
  `gshadow`, `master.passwd` or a file under
  `/sys/firmware/efi/efivars` with Edit or Write was denied only as a
  shell command; now the tool call is denied too, in every mode.

### Fixed

- **`mount | grep … efivars` is no longer denied.** Listing the EFI
  variables mount is a read; only a remount or a read-write mount of
  it is blocked.
