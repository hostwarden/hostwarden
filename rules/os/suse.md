# openSUSE & SLES

Rules for openSUSE (Leap, Tumbleweed) and SUSE Linux
Enterprise Server (SLES).

## Package Manager

- Use `zypper`
- Update repos: `zypper refresh`
- Upgrade all: `zypper update`
- Install: `zypper install <package>`
- Dry-run before upgrading: `zypper update --dry-run`
  (`--dry-run` goes after the command — verify with
  `zypper help update` first)
- Non-interactive: `zypper --non-interactive install <pkg>`

## Version Detection

- `/etc/os-release` — full distro info
- `/etc/SuSE-release` — on older versions (deprecated)

## Firewall

- **Expected:** `firewalld`, with the commands, the safety net
  and the default-zone check of `rules/firewalld.md`.
- Some systems may use SuSEfirewall2 (older) — if so,
  flag it to the user as it's deprecated.

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
