# RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux

Rules for the Red Hat family of distributions.

## Package Manager

- **RHEL 8+, Fedora, Rocky, Alma:** use `dnf`
- **RHEL 7, CentOS 7:** use `yum`
- Dry-run before upgrading: `dnf --assumeno update`
  (or `yum --assumeno update`)
- Non-interactive install: `dnf install -y <package>`

To determine which to use, check the OS version from
`/etc/os-release`. RHEL/CentOS 7 uses `yum`; everything
newer uses `dnf`.

If the host is on the `yum` branch (RHEL/CentOS 7
era), check its support status via web search — it
is likely past EOL, which is itself a **CRITICAL**
finding. See `rules/version-check.md`.

## Version Detection

- `/etc/redhat-release` — distro and version string
- `/etc/os-release` — full distro info

## Firewall

- **Expected:** `firewalld`, with the commands, the safety net
  and the default-zone check of `rules/firewalld.md`.
- If `firewalld` is not running, flag it to the user.

## Automatic Security Updates

- **Expected:** `dnf-automatic`
- Config: `/etc/dnf/automatic.conf`
- Check if active:
  `systemctl status dnf-automatic-install.timer`
- `upgrade_type = security` under `[commands]` limits it to
  security updates, which the install timer applies; a key the
  file leaves out keeps its default.
- On RHEL 7/CentOS 7: `yum-cron` instead
- If not installed or not enabled, flag it to the
  user.

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
  `sshd@.service` (`sshd -i $OPTIONS`) per connection: no listener
  runs, and its `ListenStream` lines, not `Port`, are the ports.
- `sshd.service`'s `ExecStart` adds `$OPTIONS` from
  `/etc/sysconfig/sshd`, where a `-f`, `-o` or `-p` can sit. On
  RHEL 8 it adds `$CRYPTO_POLICY` too: `-o` options that set the
  ciphers, MACs and key exchange from the crypto policy, which
  neither `sshd -G` nor `sshd -T` shows.
- Configuration: `/etc/ssh/sshd_config`, mode 0600, so reading it
  needs root, `sshd -G` included. On RHEL 9 and newer and on Fedora
  it includes `sshd_config.d/*.conf` near its top, and a drop-in
  there includes the crypto policy's
  `/etc/crypto-policies/back-ends/opensshserver.config`.
- Auth log: `/var/log/secure` where rsyslog runs, and the journal,
  `journalctl -u sshd`.
- Checksum of a file: `sha256sum <file>`.

## Networking

- **Hostname:** `hostnamectl set-hostname <name>` writes the
  static name to `/etc/hostname` and sets the running one.

## SELinux

- RHEL-family systems typically have SELinux enabled.
- Check status: `getenforce`
- If a service isn't working after configuration, SELinux
  may be blocking it. Check: `ausearch -m avc -ts recent`
- Do **not** disable SELinux without discussing with the
  user. Prefer adding proper SELinux policies.

## Storage Maintenance

What Fedora and the RHEL family schedule by themselves
(`rules/baseline.md` → Storage Maintenance):

- **TRIM:** `fstrim.timer`, weekly, enabled by the preset on
  Fedora and RHEL 10 and its rebuilds; RHEL 9 and its rebuilds
  install it disabled
  ([c10s preset](https://gitlab.com/redhat/centos-stream/rpms/centos-stream-release/-/raw/c10s/90-default.preset)).
- **md RAID:** `raid-check.timer`, Sundays at 01:00, runs
  `/usr/sbin/raid-check` as `/etc/sysconfig/raid-check` configures
  it (`ENABLED`, `CHECK`); enabled by default. The upstream
  `mdcheck_*` timers are installed and disabled
  ([Fedora mdadm](https://src.fedoraproject.org/rpms/mdadm/raw/rawhide/f/mdadm.spec)).
  `mdmonitor.service` watches arrays and mails as
  `/etc/mdadm.conf` says.
- **ZFS:** not from the distribution. The OpenZFS packages bring
  `zfs-scrub-monthly@<pool>.timer` and `zfs-trim-monthly@<pool>.timer`,
  not enabled.
- **btrfs:** Fedora packages `btrfsmaintenance`, disabled, with its
  settings in `/etc/sysconfig/btrfsmaintenance`. RHEL has no
  btrfs.
- **SMART:** `smartd.service`, installed with a "Server" install
  and not with a minimal one, and enabled. The default
  `DEVICESCAN -H` line watches health and schedules no self-tests.

## Directory Conventions

- Config files: `/etc/`
- Web roots: `/var/www/` or `/usr/share/nginx/html/`
- Logs: `/var/log/`
- Nginx config: `/etc/nginx/conf.d/`
  (no sites-available/sites-enabled pattern)

## Notes

- EPEL (Extra Packages for Enterprise Linux) is a common
  third-party repo on RHEL/CentOS. Only enable it if
  needed and with user approval.
- Fedora is a fast-moving distro — package versions and
  available packages differ significantly from RHEL.

## Common Pitfalls

- `dnf` vs `yum` — check the OS version first.
  RHEL/CentOS 7 uses `yum`, everything newer uses
  `dnf`. Running the wrong one may fail or behave
  unexpectedly.
- `firewall-cmd` changes are temporary by default:
  without `--permanent` they vanish at the next reload
  or reboot. Firewall above says when to add it.
- SELinux blocks are silent by default. If a service
  fails after correct configuration, check
  `ausearch -m avc -ts recent` before assuming the
  config is wrong.
- RHEL 8+ uses `nftables` as the backend for
  `firewalld`. Do not mix `iptables` commands with
  `firewalld` — they will conflict.
- EPEL is not enabled by default. Do not assume EPEL
  packages are available without first checking.
