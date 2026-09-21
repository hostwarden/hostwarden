# OpenMediaVault

Base: `rules/os/debian.md`

An OpenMediaVault (OMV) host is a Debian host, and this file applies
on top of the base (`rules/os-detection.md` → Appliances). OMV owns
most of what the base would have you edit: it keeps its settings in
one XML database and regenerates the files under `/etc` from it, so
a hand edit lasts until the next time the web UI applies a change.

Source for everything below unless noted: the documentation,
<https://docs.openmediavault.org/en/latest/>, and the source,
<https://github.com/openmediavault/openmediavault> (paths below are
under `deb/openmediavault/` there).

## Add: Version Detection

- `dpkg-query -W openmediavault` prints the package name and the
  OMV version (e.g. `8.5.9-1`). There is no `omv-version` command.
- `omv-confdbadm` exists on every OMV host;
  `/etc/openmediavault/config.xml` is the configuration database.
- Release names come from `/usr/share/openmediavault/productinfo.xml`
  (`<versionname>`): OMV 8 "Synchrony" is based on Debian 13, OMV 7
  "Sandworm" on Debian 12.
- Record in server memory: `Appliance: OpenMediaVault <version>`.
- Take end-of-life dates from the release table
  (<https://docs.openmediavault.org/en/latest/releases.html>), never
  from memory. A host on a release past its end of life is a finding.

## Configuration Model

- **`/etc/openmediavault/config.xml` holds every setting.** Salt
  states under `/srv/salt/omv/deploy/` render the system files from
  it: `sshd_config`, `/etc/fstab` (between its markers), Samba, NFS,
  nginx, postfix, monit, smartd, apt sources, netplan, the firewall
  script and more. Every generated file carries the header "Do not
  edit this file, your changes will get lost." The docs: "Changes
  manually added to configuration files will eventually overwritten"
  (<https://docs.openmediavault.org/en/latest/various/advset.html>).
- **Change settings through the web UI.** Give the user the exact
  menu path and values. The CLI equivalents write the same
  database, and Hostwarden uses them only when the user asks for
  the CLI:
  - `omv-confdbadm read --prettify <id>` reads one part of the
    database (`omv-confdbadm list-ids` lists every id). Read-only,
    always allowed — mind `rules/secrets.md`, several ids carry
    passwords.
  - `omv-rpc -u admin '<Service>' '<method>' '<json>'` calls the
    same backend the web UI calls
    (<https://docs.openmediavault.org/en/latest/development/tools/omv_rpc.html>).
  - `omv-confdbadm update <id> '<json>'` writes the database
    directly, outside the backend the UI uses. Prefer `omv-rpc`.
- **Applying.** A change saved in the UI marks the affected Salt
  states dirty in `/var/lib/openmediavault/dirtymodules.json`, which
  is what the yellow "pending changes" bar shows. The UI's Apply
  button deploys them.
  - `omv-salt deploy list-dirty` lists them; read-only.
  - `omv-salt deploy run <state>` renders one state now, e.g.
    `omv-salt deploy run samba`. `omv-salt deploy list` names them
    all.
  - Pending changes that someone else made are theirs: show the
    list to the user and never apply them along with your own.
  - `omv-salt stage run deploy` renders everything, `ssh`
    included, and is therefore off limits (see Access and SSH).
- **Persistent local changes** go through environment variables,
  never through edits to generated files. `omv-env list`,
  `omv-env get <VAR>`, `omv-env set -- <VAR> <value>` manage them in
  `/etc/default/openmediavault`; the advanced-settings page lists
  the variables. It applies them with `omv-salt stage run deploy`;
  Hostwarden runs `omv-salt stage run prepare` and then deploys
  only the states the variable affects. A custom Salt state belongs
  in `/srv/salt/omv/deploy/` (same page).
- `rules/backups.md` still applies, `config.xml` included. A copy of
  a generated file restores nothing: the next deploy overwrites the
  restored file too. Back up `config.xml`.

## Access and SSH

- **Hostwarden never changes SSH settings on OMV, not even through
  the UI's backend.** The `ssh` Salt state renders
  `/etc/ssh/sshd_config` (OMV diverts Debian's file with
  `dpkg-divert`) and rebuilds `/var/lib/openmediavault/ssh/authorized_keys/`
  from scratch on every run. Deploying it modifies `sshd_config` and
  overwrites SSH keys, both taboos in `AGENTS.md`. So Hostwarden
  never runs `omv-salt deploy run ssh`, never runs
  `omv-salt stage run deploy`, never saves Services > SSH or a
  user's Public Keys through `omv-rpc`, and never applies pending
  changes while `ssh` is among them. Give the user the menu path
  and values instead. The taboo guard, where it runs, blocks the
  first two; `omv-salt deploy run --append-dirty` and the `omv-rpc`
  calls are left to this rule.
- Settings live in the `conf.service.ssh` id and under
  Services > SSH. SSH is off in a fresh database; root login and
  password login are on
  (<https://docs.openmediavault.org/en/latest/administration/services/ssh.html>).
- `AllowGroups root _ssh`: only root and members of `_ssh` may log
  in. The docs' way to a non-root admin is a user in `_ssh` and
  `sudo`.
- `AuthorizedKeysFile` is `.ssh/authorized_keys`,
  `.ssh/authorized_keys2` and
  `/var/lib/openmediavault/ssh/authorized_keys/%u`. Keys entered
  under Users > Users > (user) > Edit > Public Keys land in the last
  one, converted from RFC 4716 format. A key added to
  `~/.ssh/authorized_keys` by hand survives a deploy, but the UI
  does not show it.
- Inspect with `sshd -T`, `cat` and `grep` as `AGENTS.md` says.
- `omv-firstaid` is the console tool for recovery: network, web UI
  port, admin password, failed logins, pending-change repair. It is
  interactive — the user runs it at the console.

## Remove: Package Manager > Dry-run before upgrading

## Add: Package Manager

- **Upgrade the way OMV does: `dist-upgrade`, never plain
  `upgrade`.** `omv-upgrade`, the documented non-interactive
  wrapper (<https://docs.openmediavault.org/en/latest/various/apt.html>),
  runs `apt-get update`, then `dist-upgrade` with `--yes`,
  `--auto-remove`, `--allow-change-held-packages`,
  `--allow-downgrades`, `--allow-unauthenticated` and `confold`;
  its comment says so "because newer version have modified package
  dependencies".
- Dry-run first, and show the user what it would install and
  remove:
  ```
  apt-get update
  apt-get -s dist-upgrade
  apt-mark showhold
  ```
  If it wants to remove `openmediavault`, **stop**. A held package
  is not held for `omv-upgrade`: name every hold to the user.
- After the user agrees, run `omv-upgrade`, or the user applies
  the updates under System > Update Management > Updates.
- **Never install a desktop environment or Apache.** OMV refuses to
  install next to a graphical desktop, and its package conflicts
  with `gdm3`, `sddm`, `lightdm` and `cloud-init`; the apt page says
  not to install Apache, because nginx serves the web UI.
- The apt page advises against `pip` installs on the host; offer a
  container instead.

## Replace: Stable Branch Only

- **Add no Debian Backports, Testing or Experimental source.** The
  apt page: "openmediavault is strictly tied to the Debian version
  it is based on." The same page allows one exception: a package the
  user insists on, pinned so nothing else comes from that source.
  Say first that the next OMV upgrade may break on it, and record the
  pin in server memory.
- OMV writes its own sources: `/etc/apt/sources.list.d/openmediavault.list`,
  `openmediavault-kernel-backports.list` and
  `openmediavault-os-security.list` come from the `apt` Salt state.
  They are generated; change them only through
  System > Update Management > Settings.
- Check existing hosts:
  ```
  grep -r "testing\|unstable\|sid\|experimental" \
    /etc/apt/sources.list /etc/apt/sources.list.d/
  ```
  A match is a **WARN**. The kernel backports list written by OMV is
  not one.

## Plugins and Third-Party Sources

- Official plugins are `openmediavault-*` packages from the OMV
  repository (e.g. `openmediavault-md`, `openmediavault-nut`), and
  are installed under System > Plugins or with `apt-get`.
- **omv-extras is third-party.** The docs list it under
  "3rd Party" (<https://docs.openmediavault.org/en/latest/plugins/3rd_party.html>).
  It adds its own apt source (`omvextras.sources` in
  `/etc/apt/sources.list.d/`) and plugins such as ZFS, MergerFS,
  SnapRAID, the Proxmox kernel and `openmediavault-flashmemory`.
  Its installer is a script piped from GitHub into `bash`
  (<https://wiki.omv-extras.org/doku.php?id=misc_docs:omv_extras>).
  **Ask before installing omv-extras or any of its plugins**, and
  say that it is a third-party repository with root on the NAS.
- On a host that already has it, its source is part of every
  upgrade. Record it in server memory.

## Replace: Automatic Security Updates

- **Expected: on, and OMV configures it.** `unattended-upgrades` is
  a dependency of the `openmediavault` package, and the
  `conf.system.apt.updates` id has `unattendedupgrade` on by
  default. The `apt` Salt state writes
  `/etc/apt/apt.conf.d/98openmediavault-periodic-custom`
  (`APT::Periodic::Unattended-Upgrade "1"`), and OMV's own
  `/etc/apt/apt.conf.d/95openmediavault-unattended-upgrade` limits
  it to Debian security updates with `Automatic-Reboot "false"`.
  There is no `20auto-upgrades` to look for.
- Check: `omv-confdbadm read --prettify conf.system.apt.updates`,
  and `systemctl status apt-daily-upgrade.timer`. Turned off is a
  finding; it is turned back on under
  System > Update Management > Settings, not by editing the apt
  files.
- `apticron` mails the list of pending updates when notifications
  are set up (see Housekeeping and Audits). The apt page still
  names `cron-apt`; the current package has no `cron-apt`
  dependency, so do not look for it.

## Updates

- **Major upgrades** (e.g. 7 → 8) go through `omv-release-upgrade`,
  which ships only in the last versions of a major release. It is
  the user's decision, asked for explicitly: check the release
  table and the forum announcement for the target release first,
  run it only with the user's console access at hand, and over SSH
  only inside `tmux` or `screen`. Never run `apt-get` against the
  next Debian release by hand.
- Unattended upgrades never reboot. A kernel update needs a reboot,
  which only happens with the user's agreement.

## Replace: Firewall

- **Expected: OMV's own firewall, Network > Firewall > Rules.** It
  is iptables-based: the rules live in the
  `conf.system.network.iptables.rule` id, the `iptables` Salt state
  writes `/etc/iptables/openmediavault-firewall.sh`, and the
  `openmediavault-firewall` unit loads it at boot. Rules go only
  into the INPUT and OUTPUT chains of the filter table
  (<https://docs.openmediavault.org/en/latest/administration/general/network.html>).
- **Never install `ufw`, `firewalld` or enable `nftables.service`
  here.** The OMV script flushes INPUT and OUTPUT every time it
  runs, and `nftables.service` flushes the whole ruleset: each wipes
  the other.
- There is no default deny: an empty table means everything is
  accepted, which is what a fresh install has. Report it as a
  finding; on a NAS that only answers a trusted LAN the user may
  well decide to keep it.
- Read-only: `iptables-save`, `ip6tables-save` (the docs ask for
  `iptables-save` output rather than a screenshot) and
  `omv-confdbadm read --prettify conf.system.network.iptables.rule`.
- **Before adding or changing a rule:** discuss it with the user,
  keep every sshd port open (`AGENTS.md` → Critical Safety Rules)
  as well as the web UI ports (`conf.webadmin`, 80 and 443 by
  default), and put the reject-all rule last. The docs' safety net
  while testing is a cron job that flushes INPUT and OUTPUT every
  five minutes; offer it, and remove it afterwards. Rules are
  entered in the UI and applied with Apply.

## Remove: Common Pitfalls > Prefer `apt-get upgrade`

## Remove: Common Pitfalls > Before enabling `ufw`

## Remove: Common Pitfalls > `ufw` must be enabled

## Storage

- **Filesystems, RAID and shared folders are OMV's.** The docs:
  "Drives/filesystems that are not mounted through the webui are
  not registered in the internal database"
  (<https://docs.openmediavault.org/en/latest/administration/storage/filesystems.html>).
  A shared folder, an SMB or NFS share and a SMART job all hang off
  the filesystem entry. Create, mount and remove them under
  Storage > File Systems and Storage > Shared Folders, never with
  `mount`, `mkfs` or an fstab edit.
- `/etc/fstab` has an OMV block between `# >>> [openmediavault]`
  and `# <<< [openmediavault]`. The `fstab` Salt state owns
  everything between the markers; the docs say not to touch it,
  and mount options are changed through variables on the
  advanced-settings page.
- **Software RAID** is the `openmediavault-md` plugin
  (Storage > Multiple Device, id `conf.system.mdadm.device`).
  Read with `cat /proc/mdstat` and `mdadm --detail /dev/md<n>`.
- **ZFS** needs a plugin from omv-extras (see Plugins and
  Third-Party Sources); read it with `zpool status` and `zfs list`.
- **The disk taboos in `AGENTS.md` hold for the web UI's backend
  too.** Storage > Disks > Wipe erases a whole disk; creating or
  growing a filesystem or an array partitions and formats disks.
  Hostwarden never calls these through `omv-rpc` or `omv-salt`,
  where the taboo guard cannot see them — they run in the UI, by
  the user. Read-only inspection is always allowed:
  `lsblk`, `blkid`,
  `omv-confdbadm read --prettify conf.system.filesystem.mountpoint`.
- Removing a shared folder or a filesystem entry that a share still
  uses breaks the share. Show the user what depends on it first.

## Networking

- OMV writes the network configuration: the `systemd-networkd`
  Salt state renders `/etc/netplan/10-openmediavault-default.yaml`
  and one `/etc/netplan/<nn>-openmediavault-<device>.yaml` per
  interface from the `conf.system.network.interface` id, for
  systemd-networkd. Hand edits to those files do not last;
  configure interfaces only through OMV.
- Interfaces, bonds and VLANs are changed under
  Network > Interfaces. A change there can cut SSH: ask the user,
  and make sure they have console access, where `omv-firstaid`
  restores a working interface.

## Add: Service Manager

- The web UI is nginx (site `openmediavault-webgui`), PHP-FPM and
  `openmediavault-engined`, the backend every RPC goes through.
- **monit supervises them** and restarts what fails (nginx,
  php-fpm, `omv-engined`, rrdcached, collectd, and filesystem
  mounts): `monit summary` shows the state. The advanced-settings
  page restarts the backend with `monit restart omv-engined`.
- Samba, NFS, rsyncd and the rest are the Debian services, but
  their configuration is generated: change it in the UI, then
  reload as `rules/service-reload.md` says.

## Housekeeping and Audits

- **Pending changes:** `omv-salt deploy list-dirty`. Anything listed
  was saved and never applied; report it with the list.
- **Filesystems:** `df -h`, and the mountpoints from
  `omv-confdbadm read --prettify conf.system.filesystem.mountpoint`
  compared with `findmnt`. A registered filesystem that is not
  mounted is a finding.
- **RAID:** `cat /proc/mdstat`; for each array, `mdadm --detail`.
  Degraded, resyncing or with a failed member is a finding.
  ZFS: `zpool status -x`.
- **SMART:** `smartctl -H` and `smartctl -A` per disk. Whether
  monitoring is on: `omv-confdbadm read --prettify
  conf.service.smartmontools` and the device list
  (`conf.service.smartmontools.device`). A disk without monitoring
  is a finding; so is a failed health check or a growing
  reallocated or pending sector count.
- **Pending updates:** `apt-get -s dist-upgrade`, plus the state of
  unattended upgrades (see Automatic Security Updates).
- **Notifications:** check whether mail is set up without printing
  the SMTP password:
  ```
  omv-confdbadm read conf.system.notification.email | \
    jq 'del(.authentication.password)'
  omv-confdbadm read conf.system.notification.notification
  ```
  Mail goes out through postfix in satellite mode
  (<https://docs.openmediavault.org/en/latest/administration/general/notifications.html>).
  Mail turned off, or no recipient, means nobody hears about a
  failing disk or a degraded array: a finding, fixed under
  System > Notification. Events turned off (`monitfilesystems`,
  `smartmontools`, `mdadm`, `apt`, …) are worth one line each.
- **Firewall:** see Firewall. An empty rule table is reported, not
  flagged as a missing firewall manager.
- **Logs:** OMV uses the journal (the UI's log viewer runs
  `journalctl`), so the base's read-back applies. With the
  `openmediavault-flashmemory` plugin from omv-extras, `/var/log`
  lives in RAM: entries from before the last reboot may be gone,
  and the activity check says so rather than reporting no activity.
- Security audit: SSH findings go to the user as UI changes
  (Services > SSH, Users > Users); see Access and SSH.
- Fleet audit: compare OpenMediaVault hosts only with each other.
  Show OMV's firewall in the firewall rows; `sshd_config` drift
  between OMV hosts is a difference in their UI settings.

## Add: Common Pitfalls

- A file under `/etc` that looks wrong is usually generated. Look
  for the "Do not edit this file" header before touching it, and
  find the setting in the UI.
- Do not add Samba shares to `smb.conf` or NFS exports to
  `/etc/exports`: the docs say manual changes "will not be
  reflected in the web interface", and the next deploy of that
  service overwrites them.
- `omv-upgrade` answers every prompt with yes; the dry-run in
  Package Manager is the only moment to read what it will do.
