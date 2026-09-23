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
  prints every unit file with its state; `enabled` marks one that
  starts at boot. It reads unit files, not services, and is cheap
  enough for every connection.
- **Service status:** `systemctl is-active <unit>` prints `active`
  and exits 0 while the unit runs.
- Check service: `systemctl status <service>`
- Logs: `journalctl -u <service>`
- Reload vs restart: prefer `systemctl reload` when
  the service supports it. See
  `rules/service-reload.md` for the auto-proceed
  policy and `memory/service-policy.md` opt-out /
  opt-in lists.

## YaST

- SUSE uses YaST for system configuration. Prefer command-
  line tools for scripted operations, but be aware that YaST
  may have configured things in non-standard ways. Check
  existing config before assuming defaults.

## Directory Conventions

- Config files: `/etc/`
- Web roots: `/srv/www/htdocs/` (different from most distros)
- Logs: `/var/log/`
- Nginx config: `/etc/nginx/conf.d/`

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
