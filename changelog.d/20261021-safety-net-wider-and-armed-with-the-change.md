### Changed

- **The SSH safety net covers more and never runs unarmed.** The
  timed undo now also guards PAM, VPN and tunnel, and network sysctl
  changes, not only firewall, network and login shell. It is armed in
  the same command that applies the change, so the change cannot run
  without it, and on a host with systemd the apply runs detached from
  the SSH session. A key login does not test a PAM auth stack, and
  the rule now says so. When
  a change moves the host's address, the confirming login goes to the
  new address and the timer is cancelled only through it. The rule
  also lists the failures that show later, such as `fstab`, units,
  cron and renewals, to check before any reboot, and forbids a
  reboot inside the window.
