# Proxmox VE Baseline Template

Sources as in `references/proxmox.md`.

Proxmox VE gives a container no cloud-init, and `pct create`
already sets its network, hostname and `/etc/hosts` and writes new
SSH host keys. So the baseline template is the distribution's
`pveam` template with the baseline baked in: the packages, the SSH
user and its sudo rule, automatic security updates, the firewall,
the journal and the timezone, each as the family file names it. No
cloud-init.

Two things cannot be baked in, and a first-boot unit makes each in
the container made from the archive: the login, which is sshd's
drop-in and the SSH user's keys, and the first upgrade with the
version record. `AGENTS.md` → Critical Safety Rules lets only the
first boot of a guest that has never run set sshd's login options
and keys, whatever form that takes. The build container runs, so
nothing that reaches sshd's configuration or a key is written
into it: `login.conf` and `admin-keys` sit under
`/usr/local/lib/hostwarden/firstboot/` as inert files, and the
login unit moves them into place before sshd first starts, in the
container made from the archive and never in this one.

## Which family builds how

The admin chooses the `pveam` template from
`pveam available --section system`, any distribution and release
it lists, and a node can hold one baseline template per
distribution and release side by side. The template's family, from
its name and the build container's `os-release`, names the family
file and so the recipe:

| Family file (`rules/os/`) | Templates                    | Init    |
| ------------------------- | ---------------------------- | ------- |
| `debian`                  | Debian, Ubuntu               | systemd |
| `rhel`, release 9 and up  | Rocky, Alma, CentOS, RHEL    | systemd |
| `suse`                    | openSUSE                     | systemd |
| `alpine`                  | Alpine                       | OpenRC  |

Release 8 of the RHEL family is left out too: its sshd reads no
drop-in, and the build refuses it. Fedora is left out of `rhel` for now: its
dnf5 names the timer and
configuration of automatic updates differently, and the recipe is
for dnf4. For every other template — Arch, Gentoo, Devuan and the
rest — no family file says what the baseline's firewall, updates
and service manager are, so nothing is baked. Say so in one line and offer the
user two ways on: adopt an archive they built
(`references/adopt-template.md`, which measures any family), or a
VM from the distribution's cloud image (`references/proxmox.md`).
A recipe for the family is a change to Hostwarden, not to this run.

## The files

The units and scripts are the shipped files under
`.agents/skills/hostwarden-new-guest/firstboot/`:

- `common.sh` reads `build.conf` and the family's file, and defines
  how the two units are installed and disabled for the family's
  init. `family-<family>.sh` holds what differs: the package
  manager's calls, the SSH user's group, the settings of
  automatic updates, journal, timezone and firewall.
- The login unit, `hostwarden-firstboot-login.service` (systemd) or
  `hostwarden-firstboot-login.openrc`, runs `login.sh` before
  sshd. On systemd, sshd's service requires it; on OpenRC,
  `rc.conf` makes `sshd` need it. If it fails or `sshd -t`
  rejects the result, sshd does not start: a container with no
  login is better than one with the wrong one. It is also wanted
  by `multi-user.target`, since a socket-activated sshd (Ubuntu
  from 22.10, `rules/os/debian.md` → sshd) has no service at boot
  to pull it in. It never reloads or touches a running sshd.
- The upgrade unit runs `upgrade.sh` once the network is up, and
  only once the login is in place: the firewall where it needs the
  first boot (`ufw` on Debian and Ubuntu), the first upgrade,
  `/etc/hostwarden-baseline` with the version, and its own
  disabling.
- Each unit skips itself once its marker under `/var/lib/hostwarden/`
  exists, `login.done` and `upgrade.done`, so a boot after a
  failed upgrade never places the login a second time, and a
  container that already ran keeps the sshd configuration it has.
  `ConditionFirstBoot` is not used: whether systemd counts a
  container's first boot that way is not something these files
  depend on.
- `build.sh` runs in the build container. It installs the
  packages, creates the SSH user and its sudo rule, applies the
  family's settings, and installs and enables the two units. It
  starts neither.
- On Alpine there is no mechanism for automatic security updates
  (`rules/os/alpine.md` → Automatic Security Updates) and no
  journal to make persistent; the template has neither, and the
  baseline measurement reports the first as a gap. On openSUSE the
  updates are a daily timer for security patches
  (`hostwarden-security-patch.timer`).

The template is built once per distribution release, and again when
`rules/appliance/proxmox-ve.md` → Guests says it is due, or when
`pveam available` after `pveam update` no longer lists the `pveam`
template it was built from.

## Building it

1. The `pveam` template the admin chose, verified by `pveam`
   against its signed index:

   ```bash
   pveam update
   pveam available --section system
   pveam download local <template>
   ```

2. The rendering: the directory
   `memory/baseline/<family>-bake-<n>/`
   (`rules/baseline.md` → Rendered Versions), written with the
   editing tool on the workstation, never on the host:
   - `build.conf`, shell assignments: `FAMILY` as the family file's
     name, `SSH_USER` from `memory/user.md`, `TIMEZONE` where the
     override names one and empty otherwise, `PACKAGES` and
     `BASELINE`, the rendering's name, `debian-bake-4`. Never a
     credential (`rules/secrets.md`). The packages are the
     family's plus what the overrides for the mail relay and
     monitoring name:
     - `debian`: `sudo openssh-server unattended-upgrades ufw`
     - `rhel`: `sudo openssh-server dnf-automatic firewalld`
     - `suse`: `sudo openssh firewalld`
     - `alpine`: `sudo openssh nftables tzdata`
   - `admin-keys`, the public keys of the baseline's Admin Keys.
     A copy with none is not built.
   - `login.conf`, the three lines
     `references/user-data.md` → What it carries gives for SSH
     Login: `PasswordAuthentication no`,
     `KbdInteractiveAuthentication no`,
     `PermitRootLogin prohibit-password`.
   - a copy of each shipped file from `firstboot/`, so the
     directory is all a build used and a change to a script is a
     change to the rendering.

   Render it anew before every build and compare it with the
   newest directory of its family with `diff -r`. Identical: use
   that one. Different: write it as the next number, show the
   user the difference, and use it.

3. A build container, with the next free ID and an address the
   user gives or DHCP. It lives only until step 7: no memory
   directory, no entry in `guests.md` or in the session register.
   A container created from the finished template is a guest like
   any other, and a server with all that goes with it.

   ```bash
   pct create <id> local:vztmpl/<template> \
     --hostname hostwarden-build --unprivileged 1 \
     --features nesting=1 --rootfs <storage>:8 --memory 1024 \
     --net0 name=eth0,bridge=vmbr0,ip=dhcp --start 1
   ```

4. Copy the directory to the node with `scp` and the options of
   `AGENTS.md` → SSH Options, into `/root/hostwarden-bake-<n>/`, a
   fresh directory per rendering, then build in one call:

   ```bash
   pct exec <id> -- mkdir -p /usr/local/lib/hostwarden/firstboot &&
     for f in /root/hostwarden-bake-<n>/*; do
       pct push <id> "$f" /usr/local/lib/hostwarden/firstboot/"${f##*/}" ||
         exit 1
     done &&
     pct exec <id> -- chmod 0755 \
       /usr/local/lib/hostwarden/firstboot/build.sh \
       /usr/local/lib/hostwarden/firstboot/login.sh \
       /usr/local/lib/hostwarden/firstboot/upgrade.sh &&
     pct exec <id> -- sh /usr/local/lib/hostwarden/firstboot/build.sh &&
     pct exec <id> -- test ! -e /var/lib/hostwarden &&
     rm -r /root/hostwarden-bake-<n>
   ```

   The `test` is the check that neither unit has run. Then read
   that both are enabled: on a systemd family
   `pct exec <id> -- systemctl is-enabled` with the two unit names,
   on Alpine `pct exec <id> -- rc-update show default`. Anything
   else: stop, and do not archive the container. The scripts are
   written for `sh`; a template without one cannot be built.

5. Stop it with `pct shutdown <id>`. The guard asks: show ID,
   name, node and state in the same call first
   (`rules/system-containers.md` → Changes).
6. The archive, into the directory of `local`'s `vztmpl` content:

   ```bash
   vzdump <id> --mode stop --compress zstd \
     --dumpdir /var/lib/vz/template/cache
   ```

   Rename it to `<distribution>-<release>-<rendering>_<date>.tar.zst`,
   for instance `debian-13-debian-bake-4_20260922.tar.zst`, and
   read its checksum with `sha256sum` in the same call.
7. Delete the build container with `pct destroy <id>`, asked like
   step 5.
8. Write the `Baseline template:` line into the node's memory
   (`rules/appliance/proxmox-ve.md` → Guests), with the checksum,
   replacing the one for an older archive of the same release.
   Name the older archive and offer to remove it
   (`pveam remove local:vztmpl/<file>`).

The archive carries `/etc/vzdump/pct.conf` of the build container
into every container made from it; it describes the build
container and does no harm. Its machine ID and SSH host keys are
the build container's, and `pct create` replaces both: `pct clone`
and `pct restore` do not (`rules/appliance/proxmox-ve.md` →
Guests), which is why a new server is always created from the
archive.

## Other nodes

Every node that creates containers from the template holds the
same archive, byte for byte. Copy it from the node it was built on
with the directory copy of `rules/directory-copy.md` into `local`'s
`vztmpl` directory, and read
`sha256sum` on each node against the one in the `Baseline
template:` line. Every node gets a `Baseline template:` line of its
own with the same rendering, date and checksum. A checksum that
differs is a copy that went wrong, not another version: copy it
again.
