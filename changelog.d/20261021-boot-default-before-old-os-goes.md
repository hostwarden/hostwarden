### Changed

- **An OS replacement makes the new system the boot default before
  the old one goes.** After the one-shot test boot, the new entry is
  set as the permanent default, read back and booted once without
  the one-shot; only then is the old system removed, so a plain
  reboot can no longer land in a loader with nothing behind it.
- **Hostwarden works with the disk a machine has.** It never grows a
  disk, volume or VM at the provider or in the hypervisor, and does
  not propose it for a space problem unless you bring it up. Sizing
  a new guest at creation is unchanged.
