### Added

- **A login notice for a pending reboot on Debian and Ubuntu.** The
  baseline deploys `/etc/update-motd.d/91-hostwarden-restart`: at
  the next login on the console or over SSH it names the reboot and
  why, whether a package asked for it, a newer kernel is installed
  or CPU microcode waits, and lists the services that still run
  replaced libraries, so a host kept on needrestart's list mode does
  not leave a restart unnoticed. It prints nothing when nothing
  waits, and leaves `/etc/motd` and other motd scripts alone.
  Housekeeping reports a host without it as INFO; a new guest gets
  it from its first boot.
