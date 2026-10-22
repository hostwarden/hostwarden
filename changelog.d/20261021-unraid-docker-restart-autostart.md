### Added

- **On Unraid, Docker is restarted over SSH without the session's
  `XDG_RUNTIME_DIR`.** Restarted as it is, dockerd keeps a runtime
  directory that goes away with root's last SSH session, after which
  every `docker exec` and health check fails; the rule gives the safe
  restart and a check for a daemon already caught that way. It also
  says that the Docker tab's autostart list, not the restart policy,
  decides which Unraid-managed containers come back after a reboot,
  that a staged NVIDIA driver differing from the loaded one means a
  reboot is pending, and where to see whether a User Script ran.
