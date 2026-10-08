### Added

- **On Unraid, the User Scripts and Unassigned Devices plugins run
  from a copy of their settings in `/tmp`.** The rule says so, and
  that User Scripts' named frequencies fire at the stock Slackware
  `run-parts` times rather than at the time the web UI shows, that
  `update_cron` overwrites `/etc/cron.d/root`, and that a flash boot
  device's vfat mask makes every file on it 0600. All of it is
  observed on Unraid 7.3.2 with plugin versions from September 2026,
  reported in Heinzel issue wintermeyer/heinzel#54.
