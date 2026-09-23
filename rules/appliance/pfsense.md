# pfSense

Base: `rules/os/freebsd.md`
Hardware: any

For pfSense CE and pfSense Plus. pfSense is built on FreeBSD, so the
base file supplies the vocabulary (`ifconfig`, `pfctl`,
`/usr/local/etc`). Most of its instructions for changing the system
are **wrong here**: pfSense generates the system configuration from
one XML file and overwrites manual edits. This file applies on top
of the base (`rules/os-detection.md` → Layers).

The host is usually the network's only way out. A mistake here cuts
off everyone behind it, not just your SSH session.

Source for everything below unless noted: the Netgate
documentation, <https://docs.netgate.com/pfsense/en/latest/>.

## Add: Version Detection

- `/etc/platform` contains `pfSense`, on CE and Plus.
- Version: `cat /etc/version` (e.g. `2.9.0-RELEASE`), patch level
  in `/etc/version.patch` (`0` means unpatched).
- **CE or Plus:** CE numbers its releases `2.x.y`, Plus uses
  `YY.MM` (e.g. `26.07`). The two differ in upgrade path and
  features, above all Boot Environments (Plus only).
- FreeBSD base: `uname -mrs`.
- Record in server memory: `Appliance: pfSense CE <version>` or
  `Appliance: pfSense Plus <version>`.

## Access and Shell

- SSH is **off by default**; the user enables it in the web UI or
  on the console. With default rules it is reachable from LAN only.
- `root` and `admin` share the same keys. Keys are managed in the
  web UI (User Manager); pfSense rewrites
  `/root/.ssh/authorized_keys` from the config. **Never manage keys
  from the shell.**
- pfSense generates `/etc/ssh/sshd_config` and appends
  `/etc/sshd_extra` to it. The SSH taboo in `AGENTS.md` covers both
  files and the host keys in `/etc/ssh`: read only.
- An interactive root login shows the console menu. A command
  passed over SSH skips the menu and runs under `/bin/sh`.
- A non-root user with shell access gets `tcsh`
  (`rules/first-detection.md` step 1 records it as `Shell: tcsh`).
- No `sudo` in the base system. It comes from the Sudo package,
  which asks for a password unless the entry is set to "No
  Password"; `sudo -n` then fails. Probe as usual
  (`rules/privilege-escalation.md`), and use root SSH as the
  fallback.
- `sshguard` blocks an address after repeated failed SSH or web UI
  logins. `rules/ssh-connections.md` applies; if it blocked you,
  the user clears it from another address
  (`pfctl -T flush -t sshguard`).

## Configuration Model

- **Everything lives in `/conf/config.xml`** (`/conf` links to
  `/cf/conf`). pfSense generates `/etc/ssh/sshd_config`, the pf
  ruleset (`/tmp/rules.debug`) and service configs from it. Edits
  to generated files are overwritten.
- `/etc/rc.conf` is not used for pfSense services, and editing it
  is unsupported. Do not edit it, and do not use `sysrc`.
- **Change settings through the web UI.** Give the user the exact
  menu path and values. From the shell, only use the documented
  tools below.
- pfSense keeps the last 30 configs in `/cf/conf/backup/`.
  The backup directory is `/root/hostwarden-backups/`, and
  `config.xml` gets a backup there like any other file.
- Editing `config.xml` by hand is the last resort: `viconfig`
  (clears the config cache on save), then reapply the affected area
  in the web UI or reboot. The documented safe route is to download
  a backup, edit it, and restore it in the web UI (the firewall
  reboots). Ask before either.
- **PHP shell playback scripts** (`pfSsh.php playback <script>`)
  run the same code as the web UI. Run them over SSH or on the
  console only, one script per `pfSsh.php` invocation (several
  invocations may share one SSH call). Useful ones: `svc`,
  `gatewaystatus`, `listpkg`, `pfanchordrill`, `pftabledrill`.
  `disabledhcpd`, `removepkgconfig` and `removeshaper` **delete
  config sections** (`removepkgconfig` also deletes
  `/usr/local/etc/rc.d/*`); never without an explicit request.
  Never run several scripts in one PHP shell session.
- Persistent custom commands: prefer the `shellcmd`/`earlyshellcmd`
  entries in the config (Shellcmd package), which are in config
  backups. Netgate also documents `/usr/local/etc/rc.d/*.sh`
  scripts; they run at boot and on some network events.
- Back from a bad config change without the web UI: console menu
  option 15, "Restore recent configuration".

## Replace: Package Manager

- `pkg info` and other queries are fine. Changing packages goes
  through `pfSense-upgrade` and the pfSense package tools, see
  Updates and Packages.
- Never add the FreeBSD or any non-Netgate package repository.
  Netgate: FreeBSD packages "will have unintended side effects",
  third-party repositories can leave the system "unbootable".
- Never upgrade packages on their own before the system; Netgate
  says "Do not upgrade packages before upgrading pfSense software".

## Replace: Automatic Security Updates

- There is no automatic update. Pending updates are a finding for
  housekeeping, not a missing package.

## Updates

- **Never** use `freebsd-update`.
- Check for an update:
  ```
  pfSense-upgrade -d -c
  ```
  Exit code 2 means an update is available, 0 means current, 1
  that another instance is running. Read the output too: it also
  exits 0 after "Aborted due to block_external_services flag". `-c`
  checks the current release branch only; `-C` looks for a major
  upgrade. It refreshes the repository setup first, so it is not
  strictly read-only, but it installs nothing. The web UI caches
  its last check in `/var/run/pfSense_version`.
- Apply: `pfSense-upgrade` (console menu option 13). **It reboots
  the firewall when done.** Always ask. Over SSH run it inside
  `screen`, which is not in the base system (`pkg install screen`,
  ask first). Log: `/conf/upgrade_log.latest.txt`.
- **Plus on ZFS (24.03 and later)** upgrades inside a new Boot
  Environment and rolls back on its own if the new one fails to
  boot. **CE has no Boot Environments**: recovering from a failed
  upgrade needs console access. Say which case applies before
  asking.
- CE stays CE and Plus stays Plus; switching editions is a separate
  migration.

## Packages

- pfSense packages are named `pfSense-pkg-<name>`. Install and
  remove them through the web UI (System > Packages) or its CLI
  equivalent: `pfSsh.php playback installpkg <name>`,
  `uninstallpkg <name>`, `listpkg`.
- `rules/service-class-check.md` still applies: pfSense already
  brings a web server, DNS resolver and DHCP server.

## Replace: Firewall

- **Expected:** pf, managed by pfSense. The WAN default is to block
  all inbound traffic; LAN has default allow rules.
- Read-only: `pfctl -sr` (rules), `pfctl -sn` (NAT), `pfctl -ss`
  (states), `pfSsh.php playback pfanchordrill`. The generated
  ruleset is in `/tmp/rules.debug`.
- **Rules are changed in the web UI**, never with `pfctl -f` on a
  file you wrote: the next filter reload (almost every save)
  replaces it.
- The only documented CLI rule tool is `easyrule`:
  ```
  easyrule showblock wan
  ```
  `easyrule pass <if> <proto> <src> <dst> [port]` and
  `easyrule block <if> <src>` add real rules to the config,
  `easyrule unblock <if> <src>` removes a block. Ask first.
- **Anti-lockout rule:** keeps the web UI and SSH reachable on LAN,
  ahead of user rules. It can be disabled under System > Advanced >
  Admin Access. Check that it is on before any rule change. Do not
  turn it off unless the user explicitly asks.
- `pfctl -d` switches off the firewall **and NAT** until the next
  reload: everyone behind it loses internet access. It is an
  emergency tool for the user on the console, not a safety net for
  Hostwarden.
- `pfSsh.php playback enableallowallwan` opens WAN completely.
  Never.

## Replace: Service Manager

- **Enabled services:** `rc.conf` is unused and PHP starts the
  services, so take the list from the appliance, never from memory,
  which need not hold one:
  ```
  php -r 'require_once("config.inc"); require_once("service-utils.inc"); foreach (get_services() as $s) { echo $s["name"], get_service_status($s) ? " running" : " stopped", "\n"; }'
  ```
  `get_services()` is what Status > Services lists: every service
  the configuration enables, packages included, and `sshd` only
  where SSH is enabled (`/etc/inc/service-utils.inc`). Each line
  carries the service's state.
- **Service status:** `pfSsh.php playback svc status <service>`.
- Service control: `pfSsh.php playback svc <action> <service>` with
  `start`, `stop`, `restart` or `status`, and the name as shown
  under Status > Services, e.g. `pfSsh.php playback svc restart
  unbound`.
- Netgate documents only `svc` for this. Do not fall back to
  `service <name> restart`.
- Web UI stuck: `/etc/rc.restart_webgui` (menu option 11),
  `/etc/rc.php-fpm_restart` (option 16).
- `rules/service-reload.md` still decides when to ask.

## Replace: Networking

- Interfaces, addresses, routes, DNS and the hostname are set in
  the web UI and rendered from `config.xml`. Never edit `rc.conf`
  or `resolv.conf`, and never restart `netif` or `routing` by hand.
- `ifconfig`, `netstat -rn` and `pfSsh.php playback gatewaystatus`
  are fine for reading.

## Replace: Accounts

- Users, groups, passwords and SSH keys are managed in the User
  Manager and written from `config.xml`; never `pw useradd`,
  `usermod` or `userdel`. Reading `/etc/master.passwd` as root for
  a verdict, as the base file describes, is fine.
- `admin` has UID 0 by design: pfSense keeps it as root's twin and
  sets root's password from it (`/etc/rc.initial.password`). A
  second UID 0 account named `admin` is expected, not a finding,
  and so is its shell, the console menu `/etc/rc.initial`, in the
  system-account check.

## Replace: sshd

- sshd is the base system's `/usr/sbin/sshd`, its configuration
  generated into `/etc/ssh/sshd_config` (Access and Shell).
- "SSHd Key Only" under System > Advanced > Admin Access decides
  password logins: "Password or Public Key", the default, accepts
  them; "Public Key Only" sets `PasswordAuthentication`,
  `ChallengeResponseAuthentication` and `UsePAM` to `no`;
  "Require Both" adds `AuthenticationMethods publickey,password`.
  `PermitRootLogin yes` is pfSense's normal state. Report a finding
  as the option to change.
- Auth log: `/var/log/auth.log`. Checksum of a file:
  `sha256 -q <file>`.

## Replace: Mail and Time

- Time sync is `ntpd`, configured in the web UI; `ntpq -pn` reads
  it as on FreeBSD.
- Mail notifications are configured in the web UI; a missing MTA
  behind `mailwrapper` is not a finding.

## Remove: Directory Conventions > sudo

## Add: Filesystem

- Boot Environments on Plus belong to `pfSense-upgrade`, see
  Updates. Do not create or activate one with `bectl`.

## Remove: Console Configuration

## Remove: QEMU/UTM Emulated x86_64 Workarounds

## Remove: Common Pitfalls > `/etc/rc.conf` is central

## Remove: Common Pitfalls > `sudo` is not installed by default

## Remove: Common Pitfalls > `freebsd-update` vs `pkg`

## Replace: Logs

- Plain text in `/var/log/*.log` since CE 2.5.0 / Plus 21.02; older
  versions use binary clog files (`clog /var/log/filter.log`).
- Rotated logs are bzip2-compressed by default (`bzcat`, `bzgrep`);
  new installs with `/var/log` on compressed ZFS default to no
  compression. Check the log settings before assuming either.
- Readable firewall log:
  `tail -n 50 /var/log/filter.log | filterparser.php`.
- `/var` may be a RAM disk: then `df /var/log` names `tmpfs` or an
  `md` device, and the log does not survive a reboot. Not a finding
  on its own (`rules/verify-before-reporting.md`).
- No `journalctl`. `logger -t hostwarden` lands in
  `/var/log/system.log`, which is **the syslog stream**:
  ```
  syslog_stream() { cat /var/log/system.log; }
  ```
  The activity check reads it back with:
  ```
  syslog_stream | grep -E "hostwarden|heinzel" | awk "$C"
  syslog_stream | head -1
  date
  ```
  The file rotates at 500 KiB by default and the stream does not
  open the compressed rotations, so the first line is the oldest
  entry it saw (`rules/activity-check.md` → How far back it
  reached). With "syslog (RFC 5424)" instead of the default BSD
  format under Status > System Logs > Settings, the timestamp
  carries the year itself.

## Housekeeping and Audits

- Pending updates come from `pfSense-upgrade -d -c` (never without
  `-c`: it reboots); they are the finding, and replace the FreeBSD
  baseline's Release Support, Pending Updates and Update
  Notification. Check that the anti-lockout rule is on.
  `pfctl -si` reporting `Status: Disabled` is **CRITICAL** "No
  active firewall": `pfctl -d` leaves it off until the next
  reload.
- Report settings pfSense generates as web UI changes, not file
  edits.

**Housekeeping** runs the FreeBSD baseline with these changes:

- Firewall Status: `pfctl -si | head -1` (root) reads
  `Status: Enabled`; ipfw is not used. The `_enable` check does
  not apply.
- Time Sync: judge by `ntpq -pn` alone; `ntpd_enable` is not where
  the vendor enables ntpd.
- Failed Services: the Enabled services listing (Replace: Service
  Manager) replaces the `service -e` loop; a stopped service is
  WARN.
- Certificate expiry: also the web UI's `/var/etc/cert.crt`.
- Backups: AutoConfigBackup keeps copies off the box once enabled:
  ```
  sed -n '/<acb>/,/<\/acb>/p' /cf/conf/config.xml \
    | grep -c '<enable>yes</enable>'
  ```
  `0` is INFO. Print nothing else from `config.xml`: it holds
  password hashes and keys (`rules/secrets.md`).

**A security audit** runs the FreeBSD sections with these changes:

- SSH: judged as usual while sshd runs — an audit that came in
  over SSH shows it does; locally or on the console, ask
  `pfSsh.php playback svc status sshd` first, and with SSH off
  report only that. The default "Password or Public Key" is the
  WARN, reported as the option in Replace: sshd.
- Firewall: the appliance case in the security skill's
  `references/firewall.md`; the WAN rules are under Firewall >
  Rules > WAN.
- Kernel: pfSense sets `kern.randompid` itself but leaves
  `drop_redirect` at FreeBSD's default: INFO here, with the
  tunable to set under System > Advanced > System Tunables.
- SUID/SGID: base files are expected when
  `/usr/local/share/pfSense/base.mtree` lists them with that mode;
  files `pkg which` attributes to a package (it takes the whole
  list at once) are expected too.
- Intrusion prevention: `sshguard` (Access and Shell) runs only
  while local logging is on; its settings are Login Protection
  under System > Advanced > Admin Access.

**Fleet audit:** compare CE only with CE. The unattended-upgrades
rows are replaced by `pfSense-upgrade -d -c`'s result; the WAN
rules are the firewall rows to compare. The time daemon comes from
`pfSsh.php playback svc status ntpd`; the MTA rows are
`n/a (pfSense)`.
