# FreeBSD

Rules for FreeBSD (all versions).

## Package Manager

- Use `pkg` for binary package management.
- Bootstrap if missing: `pkg bootstrap -y`
- Update catalog: `pkg update`
- Dry-run before upgrading: `pkg upgrade -n`
- Non-interactive install: `pkg install -y <package>`
- Search: `pkg search <name>`
- Installed packages: `pkg info`
- Audit for vulnerabilities: `pkg audit -F`
- Check which pkg branch the host uses (`quarterly`
  or `latest`) in `/etc/pkg/FreeBSD.conf` before
  installing, and stick to the branch the host
  already uses (AGENTS.md: stable release tracks).

### Packaged base or distribution sets

The base system is installed one of two ways, and
the update tool follows from it. Check before any
base update:

```
pkg -N 2>/dev/null && pkg which /usr/bin/uname
```

- `was installed by package FreeBSD-runtime-…` —
  **packaged base** (pkgbase). The base system is a
  set of packages from the `FreeBSD-base` repository
  and updates with `pkg upgrade`; `freebsd-update`
  refuses to run.
- `was not found in the database`, or no pkg at
  all — **distribution sets**, updated with
  `freebsd-update`.

A `freebsd-version -u` ending in `-STABLE` or
`-CURRENT` means a system built from source:
`freebsd-update` serves only releases, so base
updates follow the owner's source build, and a
check for pending base patches reports itself as
not applicable there.

Record which one in server memory.

## Version Detection

- `freebsd-version` — base system version
  (e.g. `N.N-RELEASE`)
- `freebsd-version -k` — installed kernel version,
  `-r` the running one, `-u` the userland;
  `-kru` prints all three in that order. A jail usually has no
  `/boot/kernel`, and there `-k` ends the command with `unable
  to locate kernel` before any line is printed: run
  `freebsd-version -u` alone in a jail
- `uname -r` — kernel release string
- `uname -m` — architecture (e.g. `amd64`,
  `aarch64`)
- There is no `/etc/os-release` on FreeBSD.

## Firewall

- **Expected:** `pf` (Packet Filter); `ipfw`
  (`firewall_enable="YES"`) and IPFilter
  (`ipfilter_enable="YES"`) count as well.
- Config: `/etc/pf.conf`
- Which one runs, and whether it survives a reboot
  (the `pfctl` and `ipf` lines need root):
  ```
  pfctl -s info 2>/dev/null | head -1
  sysctl -n net.inet.ip.fw.enable 2>/dev/null
  ipf -V 2>/dev/null | grep '^Running:'
  sysrc -n -i pf_enable firewall_enable ipfilter_enable
  ```
  `Status: Enabled` means pf runs, `Running: yes`
  IPFilter;
  `net.inet.ip.fw.enable` exists only while the ipfw
  module is loaded and is `1` while it filters. A
  firewall that runs while its `_enable` variable is
  not `YES` is gone after the next reboot. Without
  root the `pfctl` and `ipf` lines print nothing:
  those two are then unknown, not off, and no
  firewall may be reported as missing.
- Enable in `/etc/rc.conf`: `pf_enable="YES"`
- Load rules: `pfctl -f /etc/pf.conf`
- Show current rules: `pfctl -s rules`
- **Critical:** before enabling `pf`, always add a
  rule to pass SSH traffic first. A `pf` config
  without an SSH rule locks you out immediately.
  The example below passes port 22 only: list every
  port sshd listens on (`to port { 22 2222 }`,
  `AGENTS.md` → Critical Safety Rules).
- Minimal safe `/etc/pf.conf`:
  ```
  ext_if = "vtnet0"  # set to the real interface, see ifconfig
  set skip on lo0
  block in all
  pass out all keep state
  pass in on $ext_if proto tcp to port 22
  ```
- Do **not** rely on the `egress` interface group in
  rules unless `ifconfig -g egress` shows it is
  populated on this host. If the group is missing or
  empty, a `pass in on egress` rule matches nothing
  and `block in all` kills SSH the moment the rules
  load.
- **Mandatory before any load:** the parse-only
  config test `pfctl -nf /etc/pf.conf` must pass
  first.
- Loading or enabling pf over SSH goes through
  `rules/ssh-safety-net.md`. Loaded rules against the
  file (its step 2), where pf runs, in the backup call:
  ```
  pfctl -nvf /etc/pf.conf | grep -E '^(pass|block|match|anchor)' > <tmp>
  pfctl -sr | diff - <tmp>
  ```
  Check:
  `pfctl -nf /etc/pf.conf`; apply:
  `pfctl -f /etc/pf.conf` (or `pfctl -e`); revert:
  the backed-up `/etc/pf.conf` restored, then
  `pfctl -f /etc/pf.conf` where pf ran before, or
  `pfctl -d` where it did not. `pf_enable="YES"` waits
  for the fresh login
  (<https://man.freebsd.org/cgi/man.cgi?query=pfctl&sektion=8>).
- After enabling, verify the default policy blocks
  incoming traffic. pf has no default of its own: a
  packet no rule matches passes, and the last
  matching rule wins unless an earlier one says
  `quick`. `pfctl -s rules` prints the loaded rules
  normalised, so a blocking default reads
  `block drop in all`, `block return in all` or
  `block drop all`, possibly with `log` in between.
  One limited by `on <interface>` covers only that
  interface: it counts as the default only when
  every interface that takes traffic in (`ifconfig`,
  `lo0` and `set skip` ones aside) has one. No later
  `pass` — `in` or without a direction, which
  matches both — without address, port, protocol or
  interface undoes it. IPFilter reads the same way
  (`ipfstat -i` lists its inbound rules): last match
  wins unless `quick`, and an unmatched packet
  passes.
- **ipfw's default** is its rule 65535, which cannot
  be deleted. ipfw applies the first matching rule,
  so read the unconditional ones in `ipfw list`
  (root) — `allow` or `deny`, with or without `log`,
  `ip from any to any`, with or without `in` — by
  number: incoming traffic is allowed by default when
  the first of them is an `allow`, rule 65535
  included. `firewall_type="open"` and the loader
  tunable `net.inet.ip.fw.default_to_accept` are the
  usual causes.
- Start/stop: `service pf start`, `service pf stop`

## Automatic Security Updates

- **Base system, distribution sets:**
  `freebsd-update fetch install` (non-interactive:
  `freebsd-update --not-running-from-cron fetch install`)
- **Packages, and the base system on packaged
  base:** `pkg upgrade` (dry-run: `pkg upgrade -n`)
- There is no built-in equivalent of
  `unattended-upgrades`. Flag this to the user.
- What is expected is that pending updates get
  noticed. pkg ships a periodic job that runs
  `pkg audit -F` daily; it is on unless
  `/etc/periodic.conf` or, read after it,
  `/etc/periodic.conf.local` sets
  `security_status_pkgaudit_enable` or
  `daily_status_security_enable` to `NO`. Its report
  goes to root's mailbox, so it only reaches
  someone when `/etc/mail/aliases` forwards `root:`
  to a real address.
- Unattended upgrades are a **decision for the
  user**, not a default. Prefer a notify-only cron
  job that audits pending updates without applying
  them:
  ```
  # root crontab (crontab -e) — no user field:
  @daily pkg upgrade -n 2>&1 | mail -s "pkg updates" root
  ```
  ```
  # /etc/cron.d/pkg-audit — user field required:
  @daily root pkg upgrade -n 2>&1 | mail -s "pkg updates" root
  ```
- If the user explicitly wants auto-applying
  updates, warn first: unattended
  `freebsd-update install` can stage kernel updates
  that silently require a reboot, and `pkg upgrade -y`
  full-upgrades every package, not just security
  fixes.

## Service Manager

- FreeBSD uses `rc.d`, not systemd.
- **Service control:**
  - Start: `service <name> start`
  - Stop: `service <name> stop`
  - Reload (when supported): `service <name> reload`
  - Restart: `service <name> restart`
  - Status: `service <name> status`
  - One-shot start (without enabling):
    `service <name> onestart`
  - Reload vs restart: see `rules/service-reload.md`
    for the auto-proceed policy and
    `memory/service-policy.md` opt-out / opt-in
    lists.
- **Enable/disable services:**
  - `sysrc <name>_enable="YES"` (preferred)
  - Or manually in `/etc/rc.conf`
  - Check: `sysrc -n <name>_enable`
- **Read `rc.conf` without printing a secret:**
  `sysrc -N -a` lists the variable names alone and costs one
  pass. `sysrc -e <name> …` prints `name="value"` for the names
  it is given. Resolve values that way, for names already in
  hand: `sysrc` re-sources `/etc/defaults/rc.conf` in a subshell
  for every value it prints, so a whole-host `sysrc -e -a` pays
  that per variable. Match on the name with an anchored pattern,
  never on a whole `name="value"` line — a `<something>_flags`
  value can carry a token (`rules/secrets.md`). An empty result
  proves nothing on its own: the `-a` path exits 0 whatever it
  could not read.
- **Enabled services:** the `_enable` variables the rc.conf files
  set, resolved to their values, in the two steps the bullet above
  describes:
  ```
  rcn=$(sysrc -N -a) && {
    rce=$(printf '%s\n' "$rcn" | grep -E '_enable$' | grep -Ei "${P:-.}")
    [ -z "$rce" ] || sysrc -e $rce; }
  ```
  It prints `<name>_enable="YES"`, or `"NO"` for a service switched
  off, and exits non-zero when `sysrc` fails outright; an empty
  result proves nothing, as above. A
  caller that looks for particular services sets `P` to an extended
  regular expression of their names first, so that only those
  values are looked up. `$rce` is unquoted so that several names
  become several arguments; they are words from `sysrc`'s own
  listing. A service only `/etc/defaults/rc.conf` enables, such as
  `cron` or `syslogd`, is not in it.
- **Service status:** `service <name> status` exits 0 while the
  service runs. A script with no process of its own answers with a
  usage line or `unknown directive` instead, which is no failure.
- **Every enabled rc script:** `service -e` prints the
  paths of the enabled rc scripts in boot order, defaults
  included — `/etc/rc.d/` for the base system,
  `/usr/local/etc/rc.d/` for packages. It executes every
  script to resolve its rcvar, so run it once per session
  and reuse the output.
- `/etc/rc.conf` is the central service
  configuration file.

## Filesystem

### ZFS

- ZFS is the default filesystem on modern FreeBSD.
- Pool status: `zpool status`
- Pool list: `zpool list`
- Datasets: `zfs list`
- Snapshots: `zfs list -t snapshot`
- Create snapshot:
  `zfs snapshot pool/dataset@name`
- **Boot environments** (`bectl`):
  - List: `bectl list`
  - Create: `bectl create <name>`
  - Activate: `bectl activate <name>`
  - Use boot environments before major changes
    (upgrades, config changes).
- Common pool layout:
  ```
  zroot/ROOT/default    /
  zroot/tmp             /tmp
  zroot/usr/home        /usr/home
  zroot/var/log         /var/log
  ```

### UFS

- Older installations may use UFS.
- Check: `mount` — UFS shows as `ufs`.
- `fsck` for filesystem checks (not `e2fsck`).

### Storage Maintenance

What FreeBSD schedules by itself (`rules/baseline.md` → Storage
Maintenance):

- **ZFS:** `daily_scrub_zfs_enable` and `daily_trim_zfs_enable` in
  `/etc/periodic.conf`, both `NO` by default
  ([periodic.conf](https://github.com/freebsd/freebsd-src/blob/main/usr.sbin/periodic/periodic.conf)).
- **UFS:** TRIM is a flag of the filesystem, shown by `tunefs -p`
  as `trim: (-t)`, and trims every freed block as it goes; no
  periodic job trims UFS. `tunefs -t enable` needs the filesystem
  unmounted or read-only
  ([tunefs(8)](https://man.freebsd.org/cgi/man.cgi?query=tunefs&sektion=8)).
- **SMART:** the smartmontools package adds `smartd_enable` for
  rc.conf and a daily report, `daily_status_smart_devices` in
  `/etc/periodic.conf` (`AUTO` for every disk); both are off until
  set
  ([sysutils/smartmontools](https://github.com/freebsd/freebsd-ports/tree/main/sysutils/smartmontools)).

## Logs

**The syslog stream** is every line the host still keeps of the log
`logger` writes to, `/var/log/messages`, oldest first. Define it
once in a call that reads it:

```
syslog_stream() {
  set -- /var/log/messages.0 /var/log/messages
  [ -e "$1" ] || shift
  cat "$@"
}
```

It exits non-zero, with the reason on stderr, when `cat` could not
read a file. The stock `/etc/newsyslog.conf` rotates `messages` at
1000 KB or on 1 January and compresses the old files
(`messages.0.bz2` and on), so the stream opens `messages` and an
uncompressed `messages.0` only where one exists.

Hostwarden's journal entries (`rules/changelog.md`) go to syslog and
are read back from it, both tags (`rules/activity-check.md`):

```
syslog_stream | grep -E "hostwarden|heinzel" | awk "$C"
syslog_stream | head -1
date
```

`$C` is the activity check's classifier, defined in the same call
(`rules/activity-check.md` → Sessions and watchers); it keeps the
last 20 sessions' entries and sums up the watchers. The stream is
not cut to seven days: the `head -1` line and `date` bound it
(`rules/activity-check.md` → How far back it reached).

## Directory Conventions

- **Third-party config:** `/usr/local/etc/`
  (not `/etc/` — that's for base system only)
- **Third-party binaries:** `/usr/local/bin/`,
  `/usr/local/sbin/`
- **Web roots:** `/usr/local/www/`
- **Shells from packages:** `/usr/local/bin/`
  (`bash`, `zsh`); there is no `/bin/bash`.
- **cron:** `/etc/crontab`, `/etc/cron.d/` and
  `/usr/local/etc/cron.d/`; users' crontabs in
  `/var/cron/tabs/` (root only).
- **sudo** (from packages): `/usr/local/etc/sudoers`
  with drop-ins in `/usr/local/etc/sudoers.d/`,
  edited with `visudo -f`.
- **Logs:** `/var/log/`
- **Ports tree:** `/usr/ports/` (if installed)
- **Base system config:** `/etc/`
  (`rc.conf`, `pf.conf`, `fstab`, `loader.conf`)
- **Boot loader config:** `/boot/loader.conf`

## Networking

- **Use `ifconfig`**, not `ip` (Linux-only).
- Listening sockets: `sockstat -46l`, `*:<port>`
  meaning every address. Without root, other users'
  sockets are missing when
  `security.bsd.see_other_uids` is `0`.
- Interface list: `ifconfig`
- Set static IP: edit `/etc/rc.conf`:
  ```
  ifconfig_vtnet0="inet 192.168.1.10 \
    netmask 255.255.255.0"
  defaultrouter="192.168.1.1"
  ```
- DNS: `/etc/resolv.conf`
- Hostname: `sysrc hostname="myhost.example.com"`
- Restart networking: `service netif restart &&
  service routing restart`

## Cross-OS Compatibility

- **ext2fs driver:** FreeBSD can mount ext2/ext3
  partitions (`mount -t ext2fs /dev/daXpY /mnt`).
  However, the driver cannot handle modern ext4
  features (`metadata_csum_seed`, `orphan_file`).
  Use plain ext2 for partitions shared between
  FreeBSD and Linux.
- **Swap:** FreeBSD and Linux swap formats are
  incompatible. Each OS needs its own swap partition
  or skip swap on one OS.
- **ZFS:** Linux (OpenZFS) and FreeBSD ZFS are
  compatible at the pool level, but mixing is not
  recommended for root pools.

## Console Configuration

The correct `console` setting in `/boot/loader.conf`
depends on the platform and architecture:

| Platform                    | Console setting   |
|-----------------------------|-------------------|
| Physical server (VGA)       | `vidconsole`      |
| Physical server (serial)    | `comconsole`      |
| UTM / QEMU **x86_64** (EFI)| `vidconsole`      |
| UTM / QEMU **ARM64** (EFI) | `efi`             |
| QEMU with `-nographic`      | `comconsole`      |

**x86_64 QEMU/UTM:** QEMU emulates a VGA text-mode
adapter on x86_64, so `vidconsole` works. Using
`console="efi"` on x86_64 causes "Display output is
not active" in UTM — the EFI framebuffer console is
not initialized by x86_64 QEMU firmware.

**ARM64 UTM:** No VGA text mode exists on ARM64.
`vidconsole` fails. The `efi` console uses the EFI
framebuffer — this is the one that shows the boot
menu on the VM display. **Use `console="efi"` only
for ARM64 UTM/QEMU EFI VMs.**

If the wrong console is set, the loader prints
"console ... is unavailable" and "no valid
consoles!" and falls back to `spinconsole` (which
discards all output). The kernel may boot but
produce no visible output and potentially fail
silently. SSH may still work if the kernel fully
boots.

**Quick fix from the loader prompt:**
```
set console="vidconsole"   # x86_64
set console="efi"          # ARM64
boot
```

## Boot Loader (Lua-based, 14.x+)

Starting with FreeBSD 14.x, the boot loader uses
Lua scripts in `/boot/lua/`. The entry point is
`/boot/lua/loader.lua`.

- **If `/boot/lua/loader.lua` is missing,** the
  loader drops to an `OK` prompt instead of booting
  the kernel. This looks like a boot failure but the
  kernel and root filesystem may be intact.
- **Quick fix from the `OK` prompt:**
  ```
  load kernel
  load -t rootfs ufs:/dev/ada0p2
  boot
  ```
  (Replace `ada0p2` with the actual root partition.)
- **Permanent fix:** re-extract `base.txz` which
  contains `/boot/lua/`.
- **When extracting `base.txz` manually** (e.g.
  during SSH-only OS replacement), always verify
  `/boot/lua/loader.lua` exists after extraction.
  A tar truncation error can silently skip files.

## Common Pitfalls

- **No `systemctl`** — use `service` and `sysrc`.
- **No `/etc/os-release`** — use `freebsd-version`.
- **No `ip` command** — use `ifconfig`.
- **No `apt-get`/`dnf`/`zypper`** — use `pkg`.
- **Config in `/usr/local/etc/`** — third-party
  software (nginx, PostgreSQL, etc.) keeps its
  config under `/usr/local/etc/`, not `/etc/`.
- **`/etc/rc.conf` is central** — services, network,
  hostname, and many system settings live here.
  Back up before editing.
- **`freebsd-update` vs `pkg`** — `freebsd-update`
  patches the base system (kernel, userland);
  `pkg` manages third-party packages. Both need
  separate maintenance.
- **Boot loader:** FreeBSD uses its own loader
  (`/boot/loader.efi`), not GRUB or systemd-boot.
  Config is in `/boot/loader.conf`. Always set
  `vfs.root.mountfrom` explicitly (e.g.
  `vfs.root.mountfrom="ufs:/dev/ada0p3"`) —
  auto-detection can fail after cross-OS
  replacement or when EFI boot entries change.
- **No `journalctl`** — logs are in `/var/log/`.
  Use `tail`, `grep`, or `less`. The Hostwarden
  changelog uses `logger`, which writes to syslog.
- **`sudo` is not installed by default** — install
  with `pkg install sudo`; its files are under
  Directory Conventions.

## Accounts

- `pw useradd`, `pw usermod`, `pw userdel -r`
  instead of `useradd`, `usermod`, `userdel`.
- There is no `/etc/shadow` and no `passwd -S`. The
  hashes are in `/etc/master.passwd`, readable by root
  only; `pw usershow` replaces them with `*`. A field
  starting with `*` is locked (`pw lock` prefixes
  `*LOCKED*`), an empty one has no password. Print
  only that verdict, never the field
  (`rules/secrets.md`).
- `toor` is a second UID 0 account the base system
  ships locked, with an empty shell field, which
  means `/bin/sh`.

## sshd

- The base system's sshd is `/usr/sbin/sshd` with
  `/etc/ssh/sshd_config`, no `Include` by default.
  The `openssh-portable` package runs
  `/usr/local/sbin/sshd` with `/usr/local/etc/ssh`;
  Enabled services (Service Manager) shows
  `openssh_enable="YES"` when that one is enabled.
  Call the enabled one by its full path.
- FreeBSD ships `KbdInteractiveAuthentication yes`
  and `UsePAM yes`, so passwords are accepted
  although `PasswordAuthentication` is `no`.

## Mail and Time

- `/usr/sbin/sendmail` is `mailwrapper`;
  `/etc/mail/mailer.conf` names the MTA behind it —
  the base system's `dma` or `sendmail`, or one from
  packages (`postfix`, OpenSMTPD's rc script
  `smtpd`, `exim`).
- Time sync is the base system's `ntpd`
  (`ntpd_enable`); in `ntpq -pn` a line starting with
  `*` is the selected peer. `chronyd` and `openntpd`
  from packages answer `chronyc tracking` and
  `ntpctl -s status`. `/var/db/zoneinfo` holds the
  zone `tzsetup` installed.

## QEMU/UTM Emulated x86_64 Workarounds

**OpenSSL SIGSEGV on emulated Skylake CPU:**
FreeBSD's base `sshd` (and `openssh-portable`)
crash with signal 11 when OpenSSL's hardware-
accelerated crypto (AES-NI, AVX assembly) runs on
QEMU's emulated Skylake CPU. The crash occurs
during RSA key loading.

**Fix:** disable OpenSSL hardware acceleration with
`OPENSSL_ia32cap=0`. Replacing `/usr/sbin/sshd` with
a wrapper touches an SSH binary — get **explicit
user confirmation** before doing this:

```
# For base sshd (only with user confirmation):
mv /usr/sbin/sshd /usr/sbin/sshd.real
cat > /usr/sbin/sshd << 'EOF'
#!/bin/sh
export OPENSSL_ia32cap=0
exec /usr/sbin/sshd.real "$@"
EOF
chmod +x /usr/sbin/sshd
```

Base-system updates restore the real binary —
re-check the wrapper after every
`freebsd-update install`.

This affects ANY program using OpenSSL crypto on
emulated x86_64 QEMU. If other services crash with
SIGSEGV in libcrypto, apply the same workaround.

**Does not affect:** native ARM64 UTM VMs (Apple
Silicon with HVF), physical servers, or QEMU VMs
with KVM hardware virtualization.
