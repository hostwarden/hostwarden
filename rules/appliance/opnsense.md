# OPNsense

Base: `rules/os/freebsd.md`
Hardware: any

OPNsense is built on FreeBSD, so the base file supplies the
vocabulary (`ifconfig`, `pfctl`, ZFS). Most of its instructions for
changing the system are **wrong here**: OPNsense generates the
system configuration from one XML file and overwrites manual edits.
This file applies on top of the base (`rules/os-detection.md` →
Layers).

The host is usually the network's only way out. A mistake here cuts
off everyone behind it, not just your SSH session.

Source for everything below unless noted: the OPNsense
documentation, <https://docs.opnsense.org/>, and the
`opnsense/core` source where the docs are silent.

## Add: Version Detection

- `opnsense-version` prints e.g. `OPNsense 26.7.4 (amd64)`;
  `opnsense-version -v` only the version, `-V` the series (`26.7`).
- Two major releases a year (`YY.1`, `YY.7`), minor updates in
  between.
- Record in server memory: `Appliance: OPNsense <version>`.

## Access and Shell

- **root runs remote commands in csh.** root's login shell is
  `opnsense-shell`, which hands a command passed over SSH to
  `/bin/csh -c` (`rules/first-detection.md` step 1 records it as
  `Shell: csh`). An admin user with its own login shell gets that
  shell instead.
- An interactive root login shows the console menu.
- SSH is **off by default** on an installed system; the user
  enables it under System > Settings > Administration. Root login
  is a separate option there, and only members of `wheel` may log
  in at all.
- Non-root admins get a shell only when one is set for them under
  System > Access > Users. Keys are managed there too, not in
  `authorized_keys` by hand.
- `sudo` is installed but grants nothing until the "Sudo" option
  under System > Settings > Administration allows it for `wheel`
  ("Ask password" or "No password"). With "Ask password",
  `sudo -n` fails. Probe as usual (`rules/privilege-escalation.md`).
- The SSH config is generated into `/usr/local/etc/ssh/sshd_config`,
  host keys live in `/conf/sshd/`. `sshd_config` includes
  `/usr/local/etc/ssh/sshd_config.d/*.conf`. The SSH taboo in
  `AGENTS.md` covers all of these and the whole `/conf/sshd/`
  directory: read only.

## Configuration Model

- **Everything lives in `/conf/config.xml`.** `configd` renders the
  system configuration from it through templates and overwrites,
  among others: `sshd_config`, `/boot/loader.conf`, root's crontab,
  `/etc/rc.conf.d/*`, the pf ruleset (`/tmp/rules.debug`) and
  sudoers.
- **Change settings through the web UI** (or the API, if the user
  has set up a key). Give the user the exact menu path and values.
  Do not use `sysrc` or edit `rc.conf`.
- Every save keeps a copy in
  `/conf/backup/config-<epoch>.<fraction>.xml`. The backup directory
  is `/root/hostwarden-backups/`, and `config.xml` gets a backup
  there like any other file.
- **Apply from the shell with `configctl`**, the front end to
  `configd`:
  - `configctl configd actions` lists all actions.
  - `configctl filter reload` regenerates and loads the firewall
    rules.
  - `configctl service reload all` reapplies everything (console
    menu option 11).
- configd action names with a dot are called with a space:
  `configctl filter rule stats`, not `filter rule.stats`.
- Documented places for persistent custom additions:
  `/usr/local/etc/rc.syshook.d/<event>/` (boot and event hooks),
  `/usr/local/etc/cron.d/` (own cron jobs), System > Settings >
  Tunables (loader and sysctl values). Template overrides in
  `+TARGETS.D` may break on upgrades; avoid them.
- `configctl system halt`, `system reset_factory_defaults` and
  `system flush config_history` exist. Never.

## Replace: Package Manager

- `pkg info`, `pkg audit -F` and other queries are fine. Changing
  packages goes through `configctl firmware`, see Updates and
  Plugins.
- Never add the FreeBSD or any other repository under
  `/usr/local/etc/pkg/repos/`; OPNsense calls that "not supported".

## Replace: Automatic Security Updates

- Automatic updates exist as an opt-in cron job ("Automatic
  firmware update", minor updates only). Its absence is not a
  finding; pending updates are.
- Keep the firmware release type on "Production".

## Updates

- **Never** use `freebsd-update`: base and kernel come as signed
  sets through `opnsense-update`.
- Check without installing:
  ```
  configctl firmware probe
  cat /tmp/pkg_upgrade.json
  ```
  `needs_reboot` in the JSON says whether the update would reboot;
  `upgrade_needs_reboot` only says that a major upgrade is
  available.
- Apply a minor update: `configctl firmware update`. **It reboots
  the firewall on its own** when base or kernel changed, and after
  any package change when the firmware "reboot" setting is on.
  Always ask first, and say whether the probe expects a reboot. It
  returns at once and runs in the background; follow it with
  `configctl firmware status`.
- On ZFS (24.7.3 and later), take a snapshot before updating:
  `configctl zfs snapshot list`, then
  `configctl zfs snapshot create <name>`. It is the rollback path
  (boot menu option 8). On UFS there is none; say so before asking.
- **Major upgrades** (e.g. 26.1 → 26.7) run offline and take the
  firewall down for the duration. The docs want console access.
  Hand them to the user (console menu option 12); never run
  `configctl firmware upgrade` yourself. Read the release notes
  first; they list plugins and repositories that block the upgrade.
- Update log: `opnsense-update -g`; last major upgrade:
  `opnsense-update -G`.

## Plugins

- Plugins are `os-*` packages. Install with
  `configctl firmware install os-<name>`, remove with
  `configctl firmware remove os-<name>`. Plain `pkg install` skips
  the registration in the config, so the plugin is lost on a
  config restore.
- Community plugins are "Tier 3": supported by the community, not
  the core team. Third-party repositories are not OPNsense's at
  all. Ask before installing either.
- `rules/service-class-check.md` still applies: OPNsense already
  brings a web server, DNS resolver and DHCP server.

## Replace: Firewall

- **Expected:** pf, managed by OPNsense. A default deny rule blocks
  everything no other rule matches; WAN also blocks private and
  bogon networks by default.
- Read-only: `pfctl -sr` (rules), `pfctl -s nat`, `pfctl -si`,
  `configctl filter rule stats`. The generated ruleset is in
  `/tmp/rules.debug`. A rule listing, that file's included, goes
  through `sed -E "${fc:?}"` (`fc`: `rules/secrets.md` → Commands
  That Leak).
- **Rules are changed in the web UI or the API**, never with
  `pfctl -f` on a file you wrote: the next `configctl filter
  reload` replaces it.
- Since 26.7 the rules API applies changes at once; there is no
  automatic rollback. Do not count on a timed revert.
- **Anti-lockout rule:** keeps the web UI and SSH reachable on LAN
  (or the first interface that exists), ahead of user rules. It
  can be disabled under Firewall > Settings > Advanced (26.7; the
  menu moves in later versions). Check that it is on before any
  rule change: it is on while
  `grep -c '<noantilockout' /conf/config.xml` prints `0`
  (`system/webgui/noantilockout`,
  <https://github.com/opnsense/core/blob/master/src/etc/inc/filter.lib.inc>).
  A rule listing cannot tell, since `fc` withholds its description.
  Do not turn it off unless the user explicitly asks.
- `pfctl -d` switches off the firewall **and NAT** until the next
  reload: everyone behind it loses internet access. It is not a
  safety net for Hostwarden.
- `configctl filter flush states` and the `filter kill …` actions
  drop live connections, including your own SSH session. Ask
  first.

## Replace: Service Manager

- **Enabled services:** `pluginctl -s` lists the services OPNsense
  runs, including the ones it starts itself, which `rc.conf` does
  not name; `pluginctl -S` gives the same as JSON with a `status`
  per service.
- **Service status:** `pluginctl -s <name> status`.
- `pluginctl -s <name> restart|start|stop|status` controls one.
  `configctl service list` (JSON) and
  `configctl service restart <name>` do the same through `configd`.
- Some services have their own namespace, e.g.
  `configctl webgui restart`, `configctl openssh restart`.
- Avoid `service <name> restart`: the generated config is written
  by `configd`, not by the rc.d script. The documented exception is
  `service configd restart`.
- `rules/service-reload.md` still decides when to ask. Restarting
  `openssh` over SSH needs the same care as on any host.

## Replace: Networking

- Interfaces, addresses, routes, DNS and the hostname are set in
  the web UI and rendered from `config.xml`. Never edit `rc.conf`
  or `resolv.conf`, and never restart `netif` or `routing` by hand.
- `ifconfig` and `netstat -rn` are fine for reading.

## Replace: Accounts

- Users, groups, passwords and SSH keys are managed under
  System > Access > Users and written from `config.xml`; never
  `pw useradd`, `usermod` or `userdel`. Reading
  `/etc/master.passwd` as root for a verdict, as the base file
  describes, is fine.

## Replace: sshd

- sshd is `/usr/local/sbin/sshd`, its generated configuration
  `/usr/local/etc/ssh/sshd_config` (Access and Shell).
- Its options are under System > Settings > Administration:
  "Permit password login" sets both `PasswordAuthentication` and
  `ChallengeResponseAuthentication`, "Permit root user login" sets
  `PermitRootLogin`, and `AllowGroups wheel` and
  `X11Forwarding no` are always written. Report a finding as the
  option to change.
- Auth log: System > Log Files > Audit, kept under
  `/var/log/audit/` one file per day. Checksum of a file:
  `sha256 -q <file>`.

## Replace: Mail and Time

- Time sync is `ntpd`, configured in the web UI; `ntpq -pn` reads
  it as on FreeBSD.
- Mail notifications are configured in the web UI; a missing MTA
  behind `mailwrapper` is not a finding.

## Remove: Directory Conventions > sudo

## Add: Filesystem

- Take ZFS snapshots before an update with `configctl zfs
  snapshot`, see Updates, rather than with `bectl`.

## Remove: Console Configuration

## Remove: QEMU/UTM Emulated x86_64 Workarounds

## Remove: Common Pitfalls > `/etc/rc.conf` is central

## Remove: Common Pitfalls > `sudo` is not installed by default

## Remove: Common Pitfalls > `freebsd-update` vs `pkg`

## Replace: Logs

- One file per day: `/var/log/<area>/<area>_<YYYYMMDD>.log`,
  written by syslog-ng.
- `opnsense-log -l` lists the areas; `opnsense-log <area>` prints
  the current log, `opnsense-log -n <area>` its path
  (`/var/log/<area>/latest.log`). Never use `-f` over
  non-interactive SSH: it does not exit.
- `/var` may be a RAM disk (an option in System > Settings): then
  `df /var/log` names `tmpfs` or an `md` device, and the log does
  not survive a reboot. Not a finding on its own
  (`rules/verify-before-reporting.md`).
- No `journalctl`. `logger -t hostwarden` lands in the `system`
  area, but only at level notice or higher: keep `logger`'s
  default priority, never `-p user.info`. It also needs local
  logging to be on.
- **The syslog stream** is the `system` area's daily files, oldest
  first; the glob sorts them by date:
  ```
  syslog_stream() { cat /var/log/system/system_*.log; }
  ```
  "Maximum preserved files" under System > Settings > Logging sets
  how many days are kept. The activity check reads it back with:
  ```
  syslog_stream | grep -E "hostwarden|heinzel" | awk "$C"
  syslog_stream | head -1
  ```
  The first line is the oldest entry (`rules/activity-check.md` →
  How far back it reached). A shell function needs `sh`: send the
  call as the `sh -s` bundle (`rules/ssh-connections.md` → Bundle
  commands), never as a command line, which root's csh would run
  (see Access and Shell).

## Housekeeping and Audits

- Pending updates come from `configctl firmware probe` (see
  Updates); they are the finding, and replace the FreeBSD
  baseline's Release Support, Pending Updates and Update
  Notification. Check that the anti-lockout rule is on.
  `pfctl -si` reporting `Status: Disabled` is **CRITICAL** "No
  active firewall": `pfctl -d` leaves it off until the next
  reload.
- Report settings OPNsense generates as web UI changes, not file
  edits.

**Housekeeping** runs the FreeBSD baseline with these changes:

- Firewall Status: `pfctl -si | head -1` (root) reads
  `Status: Enabled`; ipfw is not used. The `_enable` check does
  not apply.
- Time Sync: judge by `ntpq -pn` alone; `ntpd_enable` is not where
  the vendor enables ntpd.
- Failed Services: `pluginctl -S` (Replace: Service Manager)
  replaces the `service -e` loop; a service not running is WARN.
- Certificate expiry: also the web UI's
  `/usr/local/etc/lighttpd_webgui/cert.pem`.
- Backups: a copy off the box needs a backup plugin
  (`pkg info -g 'os-*backup*'`); none installed is INFO.

**A security audit** runs the FreeBSD sections with these changes:

- SSH: judged as usual while sshd runs — an audit that came in
  over SSH shows it does; locally or on the console, check the
  `openssh` entry of `pluginctl -S` first, and with SSH off report
  only that. Report findings as the options in Replace: sshd.
- Firewall: the appliance case in the security skill's
  `references/firewall.md`; the WAN rules are under Firewall >
  Rules > WAN. From the same `pfctl -s rules` output, no
  `sshlockout` rule means OPNsense's own login lockout (on by
  default) was disabled under Firewall > Settings > Advanced:
  INFO.
- Kernel: OPNsense sets `drop_redirect`, `kern.randompid` and
  `see_other_uids`/`gids` itself (System > Settings > Tunables):
  one the kernel table flags was changed on this box. The two
  `security.bsd.unprivileged_*` keys keep FreeBSD's default: not a
  finding here.
- SUID/SGID: files `pkg which` attributes to a package (`opnsense`
  itself or a port; it takes the whole list at once) are expected.
  The base system comes as sets, not packages; judge those against
  the FreeBSD list.

**Fleet audit:** the unattended-upgrades rows are replaced by the
"Automatic firmware update" cron job and the pending updates; the
WAN rules are the firewall rows to compare. The time daemon comes
from `pluginctl -S`; the MTA rows are `n/a (OPNsense)`.
