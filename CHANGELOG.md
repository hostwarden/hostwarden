# Changelog

The notes of this release only. Earlier releases: the `CHANGELOG.md`
at their tag, or
[GitHub Releases](https://github.com/hostwarden/hostwarden/releases).

## 1.2.0 - 2026-10-08

### Added

- **Password logins for hosts that take no SSH key.** You store the
  password yourself with `bin/hostwarden-password set`, in the macOS
  keychain or an encrypted file, or link a 1Password, Bitwarden or
  Vaultwarden entry through an identity that sees nothing else; ssh gets it from
  `bin/hostwarden-askpass`, and the session never sees it. Each login
  of each host has its own line in `memory/user.md`. A host whose SSH
  server offers key logins gets no password: Hostwarden asks it and
  refuses.
- **DrayTek Vigor routers on DrayOS 3.x and 4.x.** Hostwarden logs in
  by password, reads their command line for housekeeping and the
  security audit, checks the firmware against DrayTek's advisories,
  and changes nothing without an explicit request.
- **Community scripts are read as recipes on Proxmox VE and Incus.**
  Before installing a service on such a host or in one of its guests,
  and before creating a guest for one, Hostwarden looks the
  application up at community-scripts.org and offers to read its
  script: dependencies, source, paths, ports and container defaults
  come from there, while versions, firewall, login and the guest
  itself follow Hostwarden's own rules. It never runs a script or a
  guest's `update` command, and says why when asked to. The guest
  inventory marks a guest a script built, which gets a
  `Community script:` line in memory.
- **Choose a personal local SSH agent for SSH and Git signatures.** A socket
  selection in unsynchronized `memory/user.md` overrides inherited agents;
  automatic selection respects SSH configuration and reports unavailable agents.
  An invalid saved choice is reported without keeping the host blocks out of
  `memory/ssh_config`. Workspace Git signatures use the selected socket without
  changing the agent used to authenticate a fetch, including with custom
  signing programs and default-key commands. OpenPGP, X.509 and unsigned Git
  operations retain their existing setup. Interactive workspace setup offers
  optional signing configuration once, detecting existing signatures and
  preserving them when setup is deferred.
- **An operations host can read one area of the fleet instead of
  everything.** `bin/hostwarden-fleet-run --section <key>`, repeatable,
  sends each host `collect <key>…`, and the fleet-read wrapper runs
  only those sections of the signed bundle and its floors. The
  signature still covers the whole bundle, the wrapper runs nothing
  outside it, and a key the bundle's new `SECTIONS=` line does not
  carry refuses the request before anything runs. A run by section is
  always a dry run. Bundles built in the earlier layout, without the
  line, keep running whole; a rebuild adds the line.
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
- **On Unraid, the User Scripts and Unassigned Devices plugins run
  from a copy of their settings in `/tmp`.** The rule says so, and
  that User Scripts' named frequencies fire at the stock Slackware
  `run-parts` times rather than at the time the web UI shows, that
  `update_cron` overwrites `/etc/cron.d/root`, and that a flash boot
  device's vfat mask makes every file on it 0600. All of it is
  observed on Unraid 7.3.2 with plugin versions from September 2026,
  reported in Heinzel issue wintermeyer/heinzel#54.

### Changed

- **The access-control page says which of its protections to pick
  for which need.** Fleet read is the one the host enforces, so
  unattended runs take it; the read-only list and the protected
  paths are rules the agent follows, for an interactive session on
  a writable host, a diagnosis with commands of its own included;
  and a hard guarantee for one path
  exists only on the host itself — an SSH user without write
  permission plus narrow sudo rules, `chattr +i`, a read-only ZFS
  or Btrfs dataset. The scheduled-housekeeping page points there.
- **An operations checkout opened in Claude Cowork, or in Claude
  Code on the web, reaches no server and says so.** Their shell
  runs in a Linux VM apart from the workstation, without its SSH
  keys, so such a session stops before any server work with a
  pointer to the same checkout in Claude Code on the workstation. A
  development checkout in such a VM is unaffected.

### Fixed

- **Text an ssh never reads is no longer checked as commands.** A
  heredoc `ssh host 'cat > /tmp/notes' <<EOS`, a remote script file,
  `ssh -n` with a body line such as `reboot`, or a `printf` piped
  into an ssh with `-n`, `-f` or a redirected stdin made the impact
  hook demand an announcement for a reboot nothing runs. Such a body
  is now left out, while one any other command may run, or with a
  `$(…)` the shell expands, still counts.
- **A site's map is named by the site alone.** `bin/hostwarden-map`
  named the map of a `## Sites` line without a description after the
  whole line, its sub-entries included, which gave broken file names
  and, with a long uplink line, failed with "File name too long". It
  now reads name, description and date from the site's own line, and
  a site name of several words matches its hosts' `Site:` and its
  ranges whole.
- **A map that cannot be written fails `bin/hostwarden-map`.** A
  read-only `memory/maps`, a full disk or a file name too long
  printed one line and the run still ended with exit 0, so
  `hostwarden-sync commit` took half-redrawn maps for current. Each
  map, the index and the overview page are now written through a
  temporary file and moved into place, the file that failed is named
  in a `hostwarden-map:` line, the run exits non-zero and the old
  file stays whole. `hostwarden-sync commit` still commits your own
  files, adds no maps on top and says that the maps are stale.

### Security

- **The guard denies a redirect onto a computed target.** An arrow
  in the echo text of a nested remote check is a redirect to the
  shell, and the next word names the file it truncates: one such
  check printed nothing and replaced `/usr/bin/nvim` as root. A
  redirect onto a `$( )` or backtick lookup and an arrow onto any
  expansion or lookup are now blocked in every permission mode; a
  plain `> "$VAR"` stays allowed. The rules add that empty output
  from a check that must print is a finding, and that a check which
  only reads runs with the least privilege its data needs.
