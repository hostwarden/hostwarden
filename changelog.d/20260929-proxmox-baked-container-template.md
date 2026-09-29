### Changed

- **Proxmox VE containers start lean.** The baseline template now has the
  baseline baked in and no cloud-init, for Debian, Ubuntu, the RHEL family from
  release 9 (not Fedora), openSUSE and Alpine, whichever official template you
  pick:
  a small first-boot service (systemd or OpenRC) places the SSH login before
  sshd first
  starts and runs the first upgrade, so a container carries no cloud-init
  and boots faster. Housekeeping warns when a node's archive differs
  from the recorded checksum, so every node keeps the same template.

### Added

- **A container template you built yourself can be adopted.** A
  baked archive on a Proxmox VE node, Heinzel's included, is read
  and measured against the baseline, packages, login, keys and
  updates, instead of rebuilt; onboarding and the Heinzel takeover
  offer it.
