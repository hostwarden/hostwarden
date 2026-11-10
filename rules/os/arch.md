# Arch Linux

Rules for Arch Linux and the distributions built on its
repositories and pacman: CachyOS, EndeavourOS.

Sources unless noted: the package file lists and the news on
<https://archlinux.org/>, the manuals on
<https://man.archlinux.org/> (`pacman(8)`, `pacman.conf(5)`,
`checkupdates(8)`, `paccache(8)`), and the wiki,
<https://wiki.archlinux.org/title/System_maintenance>.

## Rolling Release

Arch has no releases and no stable branch: the repositories hold
one version of each package, built against the other packages as
they are today. Three things follow.

- **The whole system upgrades at once, or not at all.**
  `pacman -Syu --noconfirm` is the only upgrade. It is a change to
  every package on the host: ask first, as for any upgrade, and
  name the count from `checkupdates`.
- **Never a partial upgrade.** Never `pacman -Sy` on its own,
  never `pacman -Sy <package>`, never `pacman -Syuw` followed by a
  plain install: each refreshes the database without upgrading
  what is installed, and the next package installed is built
  against libraries the host does not have. An `IgnorePkg` or
  `IgnoreGroup` line in `/etc/pacman.conf` holds a package back in
  the same way: an uncommented one → **WARN**, and never add one.
- **An interrupted `-Syu` is finished, not left.** Run it again
  before anything else is installed.

Before a full upgrade, read the news on <https://archlinux.org/news/>
back to the date of the last one (Version Detection below): an
entry that asks for a manual step names it, and the step is part of
the upgrade. Without a search or fetch tool, say so and let the
user read it.

`[core-testing]` and `[extra-testing]` are commented out in the
shipped `/etc/pacman.conf`. An uncommented one → **WARN**; never
enable one.

```
grep -nE '^[[:space:]]*(\[|IgnorePkg|IgnoreGroup)' /etc/pacman.conf
```

## Package Manager

- Use `pacman`, as root. Every call that changes something runs
  with `--noconfirm`; without it pacman waits for an answer.
- **Pending upgrades:** `checkupdates`, from `pacman-contrib`, as
  any user. It syncs a private copy of the database, so the
  host's own stays as it was, and prints one line per package. It
  exits 0 with a list, 2 when nothing is pending and 1 on an
  error: `checkupdates; echo "rc=$?"` tells the last two apart.
  Without `pacman-contrib`, say that the count is unknown; never
  run `pacman -Sy` to get one.
- **Dry run of an install:**
  `pacman -S --print --print-format '%n %v' <package>` prints the
  package and every dependency it would bring, and changes
  nothing.
- **Install:** `pacman -S --needed --noconfirm <package>`, only
  when `checkupdates` reports nothing pending. When it does, the
  install is `pacman -Syu --needed --noconfirm <package>`, which
  is a full upgrade and asked as one.
- **Remove:** `pacman -Rs --noconfirm <package>`, which takes the
  dependencies nothing else needs with it; show the list first
  with `pacman -Rs --print <package>`.
- **Security fixes:** pacman has no security-only view.
  `arch-audit -u`, from the `arch-audit` package, lists the
  installed packages with a known vulnerability that an upgrade
  already fixes; it stands in for "pending security updates".
  Without it, report the total and say no subset is known.
- **History:** `/var/log/pacman.log`, one line per action.
- **Foreign packages:** `pacman -Qm` lists what no configured
  repository offers, which is what came from the AUR or a file;
  `pacman -Qdtq` lists dependencies nothing needs any more. Both
  exit 1 when the list is empty, so read the output
  (`rules/verify-before-reporting.md`).
- **Cache:** `/var/cache/pacman/pkg/` keeps every package file
  ever downloaded and is never pruned by pacman itself. It is
  also the rollback: `pacman -U /var/cache/pacman/pkg/<file>`
  reinstalls an older build. `paccache -d` from `pacman-contrib`
  says what a prune would remove; `paccache -rk2` removes all but
  the two newest versions of each package, and asks first
  (`rules/disk-space.md`).
- pacman restarts no service. A daemon keeps running the old
  binary until it is restarted (`rules/service-reload.md`).

### Changed configuration files

An upgrade that would overwrite an edited file in `/etc` writes
`<file>.pacnew` next to it; a removal keeps an edited file as
`<file>.pacsave`. List them after every upgrade:

```
find /etc -name '*.pacnew' -o -name '*.pacsave'
```

Merge each by hand, with a backup (`rules/backups.md`), and never
accept the new version of `passwd`, `shadow`, `group`, `sudoers`
or `sshd_config` wholesale. Never run `pacdiff` over SSH: it is
interactive.

### AUR

The Arch User Repository holds build recipes anyone can upload,
unreviewed. A package from it is not updated by `pacman -Syu` and
breaks when a library it was built against moves on.

- Install from the AUR only when the user asks for that package by
  name, after the alternatives: the official repositories, the
  upstream project's own binary in `/usr/local/` or `/opt/`, and
  mise for a language runtime (`hostwarden-runtimes`).
- Read the `PKGBUILD` and every file it sources first, and show
  the user what it downloads and runs.
- `makepkg` and the helpers `paru` and `yay` refuse to run as
  root; they run as a normal user, who needs sudo for the install
  step.
- Record it in machine memory, and log it with
  `logger -t hostwarden`:

  ```markdown
  - AUR: <package> (reason: <why the repositories were not enough>)
  ```

What is installed from outside the repositories is the
`pacman -Qm` list; housekeeping reports it as **INFO**.

## Version Detection

- `/etc/os-release` — `ID=arch`, or the derivative's `ID` with
  `ID_LIKE=arch`; `BUILD_ID=rolling`. There is no `VERSION_ID`,
  and no version to report.
- What stands in for the version is the date of the last full
  upgrade:

  ```
  grep 'starting full system upgrade' /var/log/pacman.log | tail -1
  ```

  No line means the host has not been upgraded since it was
  installed, or the log was rotated away: say which you cannot
  tell.
- Kernel: `uname -r`. The packages are `linux`, `linux-lts`,
  `linux-zen` and `linux-hardened`; CachyOS adds `linux-cachyos`
  and its variants.
- **Support period:** none ends. A rolling release has no
  end-of-life date (`rules/version-check.md` → OS End-of-Life
  Awareness); how far the host is behind is the measure instead
  (Automatic Security Updates below).

## Firewall

Arch installs none, and enables nothing it packages. What it
packages:

- **nftables** (core) — `nftables.service` loads
  `/etc/nftables.conf`. The shipped file drops input and forward
  by default and accepts established connections, loopback, ICMP
  and `tcp dport ssh`, which is port 22 only.
- **ufw** (extra) — with the commands of `rules/os/debian.md` →
  Firewall. `ufw enable` alone does not survive a reboot here:
  `ufw.service` has to be enabled too.
- **firewalld** (extra) — with `rules/firewalld.md`.

A derivative's installer may set one up; go by what the checks
below print, never by the distribution's name.

Never add a second manager on top of one that is active
(`rules/service-class-check.md`), and never enable `ufw.service`
beside an enabled `iptables.service` or `nftables.service`.

**Before `systemctl enable --now nftables`:** read the ports sshd
listens on (`AGENTS.md` → Critical Safety Rules). The shipped
ruleset opens 22 and nothing else, so an sshd on another port is
cut off. Add each port to `/etc/nftables.conf` first, check with
`nft -c -f /etc/nftables.conf`, and apply through
`rules/ssh-safety-net.md`. Discuss all of it with the user first
(`rules/firewall-changes.md`).

Checks, for housekeeping and the security audit alike (`fc`:
`rules/secrets.md` → Commands That Leak):

```
systemctl is-enabled nftables iptables ufw firewalld 2>&1
systemctl is-active nftables iptables ufw firewalld 2>&1
ufw status verbose | sed -E "${fc:?}"
```

- ufw `Status: active` while `ufw.service` is not enabled →
  **WARN**: the rules are gone after the next reboot.
- Judge default deny for nftables and for iptables with
  `.agents/skills/hostwarden-security/references/firewall-nftables-docker.md`
  (Native nftables, iptables without a manager).
  `nftables.service` loads the rules and exits, so `is-active`
  may read `inactive` with a ruleset loaded: `is-enabled` and the
  ruleset count.
- None enabled and no ruleset loaded → **CRITICAL** "No active
  firewall", weighed by `rules/baseline.md` → Filtering in front
  of the host.

## Brute-Force Protection

Where the security audit finds a public service that takes a
password (its `references/intrusion-prevention.md`), the
recommendation is `fail2ban` from extra. Key-only login and an
admin interface behind a VPN come first.

- The package enables no jail and reads log files, which a host
  that logs to the journal alone does not have. One drop-in,
  `/etc/fail2ban/jail.d/hostwarden.local`, a file of Hostwarden's
  (`rules/deployed-files.md`), turns it to the journal and to
  nftables:

  ```ini
  [DEFAULT]
  backend = systemd
  banaction = nftables
  banaction_allports = nftables[type=allports]
  ignoreip = 127.0.0.1/8 ::1 <admin networks>

  [sshd]
  enabled = true
  mode = normal
  ```

  Under ufw or firewalld, `banaction` is `ufw` or
  `firewallcmd-rich-rules` instead. `ignoreip` takes the addresses
  this workstation and the admins connect from: ask for them.
  Never `mode = aggressive` or `ddos` (`rules/ssh-connections.md`).
- The package leaves the service disabled: `fail2ban-client -t`
  tests the configuration, then `systemctl enable --now fail2ban`.
  Check: `fail2ban-client status sshd`.

## Automatic Security Updates

Arch has none, and none is expected: an unattended `pacman -Syu`
upgrades every package with nobody to read the news or merge a
`.pacnew`. Its absence is not a finding: the ratings below stand
in for `rules/baseline.md` → Automatic Security Updates. Never
set one up unasked.

What is rated instead:

- More than 30 days since the last full upgrade (Version Detection
  above), or no upgrade on record → **WARN**.
- Each package `arch-audit -u` lists → **WARN**, as a pending
  security update.
- `checkupdates` count → **INFO** on its own.

Where the user did set one up, report it as **INFO** with what it
does. `pacman-offline` (extra) is the packaged one:
`pacman-offline-prepare.timer` downloads the upgrade daily, the
upgrade is installed during the next boot, and
`pacman-offline-reboot.timer` reboots at night when one is
prepared, which is an automatic restart
(`rules/maintenance-windows.md` → Automatic restarts).
Source: <https://github.com/eworm-de/pacman-offline>.

```
systemctl is-enabled pacman-offline-prepare.timer \
  pacman-offline-clean-prepare.timer pacman-offline-reboot.timer 2>&1
```

**Kernel awaiting a reboot:** a kernel upgrade removes the running
kernel's modules, so the next module load fails until the host
reboots:

```
[ -d "/usr/lib/modules/$(uname -r)" ] && echo "kernel-modules=present" \
  || echo "kernel-modules=missing"
```

`kernel-modules=missing` → **INFO**, reboot recommended, as
housekeeping's Kernel: Running vs Installed rates it. A reboot is
the user's call. In a container the directory is the host's and
its absence says nothing.

## Service Manager

- `systemctl` (systemd)
- **Nothing is enabled by installing it.** Arch's preset is
  `disable *`: a package's unit starts only after
  `systemctl enable --now <unit>`, and a freshly installed daemon
  that does not run is not broken.
- **Enabled services:** `systemctl list-unit-files --no-legend`
  prints every unit file with its state in the second column;
  `enabled` there marks one that starts at boot. The third column
  is the vendor preset, which is `disabled` for nearly everything
  here and says nothing about this host. It reads unit files, not
  services, and is cheap enough for every connection.
- **Service status:** `systemctl is-active <unit>` prints `active`
  and exits 0 while the unit runs.
- Check service: `systemctl status <service>`
- Logs: `journalctl -u <service>`
- Reload vs restart: prefer `systemctl reload` when the service
  supports it. See `rules/service-reload.md` for the auto-proceed
  policy and `memory/service-policy.md` opt-out / opt-in lists.

## sshd

- Unit `sshd.service`, from `openssh`; `sshdgenkeys.service`
  creates missing host keys before it. The package ships no
  `sshd.socket`.
- Configuration: `/etc/ssh/sshd_config`, with the drop-ins in
  `/etc/ssh/sshd_config.d/`, of which the package ships
  `99-archlinux.conf`.
- Auth log: the journal, `journalctl -u sshd`.
- Checksum of a file: `sha256sum <file>`.

## Networking

- **Hostname:** `hostnamectl set-hostname <name>` writes the
  static name to `/etc/hostname` and sets the running one.

## Storage Maintenance

Arch enables no storage maintenance (`rules/baseline.md` → Storage
Maintenance): the units exist once their package is installed and
stay disabled until someone enables them (Service Manager above).

- **TRIM:** `fstrim.timer`, weekly, from `util-linux`.
- **md RAID:** `mdcheck_start.timer` and `mdmonitor-oneshot.timer`,
  from `mdadm`.
- **btrfs:** `btrfs-scrub@.timer`, monthly, from `btrfs-progs`,
  enabled once per filesystem with the escaped mount point as the
  instance: `systemd-escape -p /srv/data` prints `srv-data`, `/`
  is `-`.
- **SMART:** `smartd.service`, from `smartmontools`.

## Directory Conventions

- Config files: `/etc/`
- Web root: `/srv/http/` (the `filesystem` package creates it)
- nginx: `/etc/nginx/nginx.conf`; the package ships no `conf.d/`
  and no `sites-available/`, and its default root is
  `/usr/share/nginx/html/`
- Apache: package `apache`, unit `httpd.service`,
  `/etc/httpd/conf/httpd.conf`
- Logs: the journal; `/var/log/pacman.log` for package changes
- pacman: `/etc/pacman.conf`, `/etc/pacman.d/mirrorlist`,
  `/var/cache/pacman/pkg/`, `/var/lib/pacman/`

## Notes

### CachyOS

CachyOS installs its own repositories in front of Arch's in
`/etc/pacman.conf`: `[cachyos]` on every machine, and by CPU level
`[cachyos-v3]`, `[cachyos-core-v3]` and `[cachyos-extra-v3]`, the
same three with `-v4`, or with `-znver4`. They carry rebuilt
packages of the same names, so the order of the sections decides
which build is installed: never reorder them, and never remove one
while its packages are installed. They are the distribution's
repositories, not a third-party source to flag.
Source: <https://wiki.cachyos.org/features/optimized_repos/>.

Where the root filesystem is btrfs, `snapper list-configs` shows whether
snapshots are taken around each pacman transaction; one from
before an upgrade is the way back from it, and rolling back is a
storage change that asks first (`rules/storage.md`).

### Containers are not hosts

The `archlinux` image is not a host: it has no init and no sshd,
and is rebuilt rather than administered. Arch in an LXC or
systemd-nspawn container is a host with its hypervisor's kernel:
kernel updates, `sysctl` changes and most firewall work happen
there, and the kernel-modules check above does not apply.

## Common Pitfalls

- `pacman -Sy <package>` works today and breaks the host at the
  next library bump. Rolling Release above is not a preference.
- An upgrade that replaces `systemd`, `glibc` or the kernel leaves
  the running system on the old one until the reboot; the kernel
  check under Automatic Security Updates is what shows it.
- `checkupdates` and `pacman -Syu` ask the same mirrors, the first
  that answers in `/etc/pacman.d/mirrorlist`. A host with an old
  last-upgrade date and nothing pending may be reading a mirror
  that no longer syncs: say so rather than report it up to date.
- Package names differ from Debian's and RHEL's: `apache`, not
  `apache2` or `httpd`; `openssh`, not `openssh-server`;
  `python`, not `python3`. Check with `pacman -Ss '^<name>$'`
  before installing by a remembered name.
