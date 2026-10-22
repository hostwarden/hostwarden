# openSUSE & SLES

Rules for openSUSE (Leap, Tumbleweed) and SUSE Linux
Enterprise Server (SLES).

## Package Manager

- Use `zypper`
- Update repos: `zypper --non-interactive refresh`
- Upgrade all: `zypper --non-interactive update`
- Install: `zypper --non-interactive install <package>`
- Dry-run before upgrading: `zypper --non-interactive update --dry-run`
  (`--dry-run` goes after the command — verify with
  `zypper help update` first)
- Every call runs with `--non-interactive`. Add
  `--gpg-auto-import-keys` only to a refresh of one repository
  by alias (`refresh <alias>`), the one the user approved adding
  in this session, right after `zypper addrepo`; it accepts that repository's
  signing key unseen.

## Version Detection

- `/etc/os-release` — full distro info
- `/etc/SuSE-release` — on older versions (deprecated)

## Firewall

- **Expected:** `firewalld`, with the commands, the safety net
  and the default-zone check of `rules/firewalld.md`.
- Some systems may use SuSEfirewall2 (older) — if so,
  flag it to the user as it's deprecated.

## Brute-Force Protection

Where the security audit finds a public service that takes a
password (its `references/intrusion-prevention.md`), the
recommendation is `fail2ban`: in openSUSE's main repository, and on
SLES from SUSE Package Hub, which `SUSEConnect -p
PackageHub/<version>/<arch>` enables as part of the same asked
step. Key-only login and an admin interface behind a VPN come
first.

- The package bans through iptables and reads log files. One
  drop-in, `/etc/fail2ban/jail.d/hostwarden.local`, a file of
  Hostwarden's (`rules/deployed-files.md`), turns it to firewalld
  and the journal:

  ```ini
  [DEFAULT]
  backend = systemd
  banaction = firewallcmd-rich-rules
  banaction_allports = firewallcmd-rich-rules
  ignoreip = 127.0.0.1/8 ::1 <admin networks>

  [sshd]
  enabled = true
  mode = normal
  ```

  `ignoreip` takes the addresses this workstation and the admins
  connect from: ask for them. Never `mode = aggressive` or `ddos`
  (`rules/ssh-connections.md`).
- The package leaves the service disabled: `fail2ban-client -t`
  tests the configuration, then `systemctl enable --now fail2ban`.
  Check: `fail2ban-client status sshd`.

## Automatic Security Updates

- Prefer **security-only** patching via a cron job or
  systemd timer, e.g.
  `zypper --non-interactive patch --category security`
  — verify the exact syntax with `zypper help patch`
  first; it varies between versions.
- Do **not** schedule a full
  `zypper --non-interactive update` — that upgrades
  every package nightly, not just security fixes.
- On SLES, YaST Online Update is the supported
  mechanism for configuring automatic updates.
- If no auto-update is configured, flag it to the user.
- **Reboot:** SUSE has no reboot option inside the patch
  timer itself; `rebootmgr` is the separate service that
  reboots within a configured maintenance window when one
  is set up (`rebootmgrctl status`). Not active means no
  automatic reboot at all, whatever the patch schedule
  (`rules/maintenance-windows.md` → Automatic restarts).

## Service Manager

- `systemctl` (systemd)
- **Enabled services:** `systemctl list-unit-files --no-legend`
  prints every unit file with its state in the second column;
  `enabled` there marks one that starts at boot. The third column,
  where systemd prints one, is the vendor preset, which says what
  the distribution would choose and nothing about this host:
  `nftables.service disabled enabled` is off. It reads unit files,
  not services, and is cheap enough for every connection.
- **Service status:** `systemctl is-active <unit>` prints `active`
  and exits 0 while the unit runs.
- Check service: `systemctl status <service>`
- Logs: `journalctl -u <service>`
- Reload vs restart: prefer `systemctl reload` when
  the service supports it. See
  `rules/service-reload.md` for the auto-proceed
  policy and `memory/service-policy.md` opt-out /
  opt-in lists.

## sshd

- Unit `sshd.service`. The package also ships `sshd.socket`
  (`Accept=yes`), which, when enabled instead, starts one
  `sshd@.service` (`sshd -i $SSHD_OPTS`) per connection: no
  listener runs, and its `ListenStream` lines, not `Port`, are the
  ports.
- `sshd.service`'s `ExecStart` adds `$SSHD_OPTS` from
  `/etc/sysconfig/ssh`, where a `-f`, `-o` or `-p` can sit.
- Configuration: without an `/etc/ssh/sshd_config`, as openSUSE
  Leap 16 and Tumbleweed ship, sshd reads
  `/usr/etc/ssh/sshd_config`, mode 0640, so reading it needs root,
  `sshd -G` included. That file includes
  `/etc/ssh/sshd_config.d/*.conf` and then
  `/usr/etc/ssh/sshd_config.d/*.conf`, the crypto policy among
  them.
- Auth log: the journal, `journalctl -u sshd`.
- Checksum of a file: `sha256sum <file>`.

## Networking

- **Hostname:** `hostnamectl set-hostname <name>` writes the
  static name to `/etc/hostname` and sets the running one.

## YaST

- SUSE uses YaST for system configuration. Prefer command-
  line tools for scripted operations, but be aware that YaST
  may have configured things in non-standard ways. Check
  existing config before assuming defaults.

## Mandatory Access Control

- **Expected:** SELinux, enforcing, on a new install of SLE 16,
  Leap 16 or Tumbleweed; AppArmor on SLE 15 and Leap 15, and on a
  16 upgraded from one where the migration kept it. Either one,
  enforcing, meets the baseline.
- Check status: `getenforce` for SELinux, `aa-status` as root for
  AppArmor; `/sys/kernel/security/lsm` says which one runs.

Sources: https://en.opensuse.org/How_to_switch_from_SELinux_to_AppArmor_in_Leap_16,
https://linuxiac.com/sles-16-0-launches-with-agama-installer-selinux-and-16-years-of-support

## Storage Maintenance

What openSUSE schedules by itself (`rules/baseline.md` → Storage
Maintenance), all enabled by the preset
([default-SUSE.preset](https://build.opensuse.org/public/source/SUSE:SLFO:1.2/systemd-presets-common-SUSE/default-SUSE.preset)):

- **TRIM:** `fstrim.timer`, weekly, from `util-linux-systemd`.
- **md RAID:** `mdcheck_start.timer` and `mdmonitor-oneshot.timer`.
- **btrfs:** `btrfsmaintenance` with `btrfs-scrub.timer` (monthly)
  and `btrfs-balance.timer` (weekly); its TRIM is off. It works
  only on the mount points `/etc/sysconfig/btrfsmaintenance` names,
  `/` by default, so a second btrfs filesystem goes unscrubbed
  until `BTRFS_SCRUB_MOUNTPOINTS` lists it
  ([btrfsmaintenance](https://github.com/kdave/btrfsmaintenance/blob/master/sysconfig.btrfsmaintenance)).
- **SMART:** `smartd.service`. Its default configuration runs a
  short self-test daily and a long one on the first Sunday of the
  month, the only family that schedules self-tests.

## Directory Conventions

- Config files: `/etc/`
- Web roots: `/srv/www/htdocs/` (different from most distros)
- Logs: `/var/log/`
- Nginx config: `/etc/nginx/conf.d/`

## Vendor Defaults under /usr

openSUSE Leap 16 and Tumbleweed ship some defaults under `/usr`
rather than `/etc`: `/usr/etc/nsswitch.conf`, `/usr/etc/sudoers`
(mode `0444`), `/usr/etc/login.defs`, `/usr/lib/pam.d/`. A file
of the same name in `/etc` replaces the default, and
`sudo -V` as root names both sudoers paths,
`/etc/sudoers:/usr/etc/sudoers`. Probes read both, `/etc` first.
Edit only in `/etc`: an update overwrites `/usr`. `visudo -c`
calls the `0444` vendor file bad permissions and exits 1; sudo
still reads it, and that alone is not a finding. Leap 15 keeps
them in `/etc`.

## Notes

- openSUSE Tumbleweed is a rolling release — package
  versions change frequently.
- openSUSE Leap and SLES share the same base and are more
  stable/predictable.

## Common Pitfalls

- `zypper` is interactive by default — always use
  `--non-interactive` for scripted/SSH commands.
- Web root is `/srv/www/htdocs/`, not `/var/www/`.
  Nginx config is in `/etc/nginx/conf.d/`, not
  `sites-available/`.
- `firewalld` is shared with RHEL but zone defaults
  may differ. Check `firewall-cmd --get-active-zones`
  before making changes.
- YaST quirks: see the YaST section above.
