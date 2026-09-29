# Adopting a Baked Container Template

A node can already hold a baseline template that Hostwarden did not
build: a container archive with the baseline baked in, made by hand
or by Heinzel, and used with `pct create`. Hostwarden recognises it
by measuring the archive against `rules/baseline.md`, instead of
rebuilding it, and then creates containers from it as from its own.

Nothing here starts the archive, extracts a whole tree or writes to
the node except the memory line at the end. Everything is read with
`tar` to standard output from the archive, one file at a time. It
is never run as a container to look inside, since a container that
runs is a server.

## When it applies

- A node without a `Baseline template:` line (`rules/appliance/proxmox-ve.md`
  → Guests), before `references/proxmox-template.md` builds one.
- The onboarding of a Proxmox VE node, or the takeover of one from
  Heinzel, whose archive the user or the changelog names, or that `pveam list
  local` shows, typically `heinzel-*-base_*.tar.zst`.

Find the candidates in one call: archives in `local`'s `vztmpl`
content that `pveam available` does not list.

```bash
pveam list local
pveam available --section system
ls -l /var/lib/vz/template/cache
sha256sum /var/lib/vz/template/cache/*.tar.*
```

The user says which archive is the baseline template. A name is a
lead, never the answer. An archive that is a plain `pveam` template
is not one.

## The measurement

`$A` below is the archive's path; `tar` recognises `.tar.zst`,
`.tar.gz` and `.tar.xz` by itself when it reads a file. Each call
reads one thing, and the calls go out together in one round. Each is judged
against the section of `rules/baseline.md` it names, with the family file's
tool.

```bash
A=/var/lib/vz/template/cache/debian-13-base.tar.zst
tar -xOf "$A" ./usr/lib/os-release
tar -tf "$A" | grep -cE '^\./etc/cloud/'
tar -tf "$A" --wildcards './etc/ssh/sshd_config.d/*.conf'
tar -xOf "$A" ./etc/ssh/sshd_config | grep -E '^(Include|PasswordAuthentication|KbdInteractiveAuthentication|PermitRootLogin)'
tar -xOf "$A" ./usr/etc/ssh/sshd_config | grep -E '^(Include|PasswordAuthentication|KbdInteractiveAuthentication|PermitRootLogin)'
tar -tf "$A" --wildcards './usr/etc/ssh/sshd_config.d/*.conf'
tar -xOf "$A" ./etc/passwd | grep -c '^alice:'
tar -xOf "$A" ./etc/ufw/ufw.conf | grep '^ENABLED='
tar -tf "$A" --wildcards './etc/systemd/journald.conf.d/*'
tar -xOf "$A" ./var/lib/dpkg/status | grep -A7 -E '^Package: (openssh-server|unattended-upgrades|ufw|nftables|nullmailer|postfix|msmtp-mta|dma|sudo)$'
tar -xOf "$A" ./etc/apt/apt.conf.d/20auto-upgrades
tar -tvf "$A" ./etc/localtime ./etc/timezone
tar -tvf "$A" --wildcards './etc/nullmailer/*'
tar -tf "$A" --wildcards './etc/systemd/system/multi-user.target.wants/ssh*' './etc/systemd/system/sockets.target.wants/ssh*'
```

The block above is Debian's. The archive's family, from its
`os-release`, changes the package and firewall reads and, on Alpine, how sshd is
enabled; the judging is the same.

```bash
A=/var/lib/vz/template/cache/alpine-3-base.tar.zst
tar -xOf "$A" ./lib/apk/db/installed | grep -E '^P:(openssh|sudo|nftables|tzdata)$'
tar -tf "$A" --wildcards './etc/nftables.d/*' './etc/runlevels/*'
tar -tf "$A" ./usr/sbin/firewalld ./etc/dnf/automatic.conf
tar -xOf "$A" ./etc/dnf/automatic.conf | grep -E '^(upgrade_type|apply_updates)'
```

- **Alpine:** the package database is text, `lib/apk/db/installed`,
  and its `P:` lines name the packages. The firewall is
  `etc/nftables.d/` and the `nftables` service in
  `etc/runlevels/`; automatic updates have no mechanism there, so
  none is a gap to report, as `rules/os/alpine.md` → Automatic Security Updates
  says.
- **RHEL family and openSUSE:** the package database is binary and
  is not read. A package counts as installed when a file it ships
  is in the listing (`usr/sbin/firewalld`,
  `etc/dnf/automatic.conf`, and for openSUSE a security patch
  timer under `etc/systemd/system/`), and its settings are read
  from the files as above.
- **sshd at boot:** an `sshd` entry in `etc/runlevels/default/`
  on Alpine, and on systemd a link to `ssh.service`, `sshd.service`
  or `ssh.socket` under `multi-user.target.wants` or
  `sockets.target.wants`. A vendor preset alone is not read here:
  where no link is there, say so and count it as a miss to check
  on a guest, since the container would answer no SSH.
- **Init:** `usr/lib/systemd/systemd` or `sbin/openrc` in the
  listing tells which init the guests run, and so how their first
  boot is waited for (`references/proxmox.md`).

- **Distribution and release:** from `usr/lib/os-release`, which
  `etc/os-release` links to and `tar -xO` does not follow, with the archive's
  own name. It must match the distribution the guests are meant to
  run.
- **SSH Login:** the listing names the drop-ins. Read each in name
  order with `tar -xOf "$A" <member>` piped to `grep -E` for
  the three keywords, in a call of its own, and the main file as
  above. Drop-ins come before the main file's own lines (its
  `Include` sits at the top; a main file with no `Include`, as on
  RHEL 8, does not read them at all, and then the main file alone
  counts; on openSUSE all of the `etc/ssh` drop-ins come before any
  of the `usr/etc/ssh` ones, each in name order), and sshd takes the
  first value it
  reads: judge the first of each keyword in that order. Only `tar`
  into `grep` reads these files, never a language runtime.
- **Admin Keys:** the SSH user must exist in the archive's
  `etc/passwd`, with its public keys in `home/<user>/.ssh/` or
  `root/.ssh/`. Fetch the key lines into a cache file, then compare
  fingerprints with the Admin Keys override, in a call of its own:

  ```bash
  A=/var/lib/vz/template/cache/debian-13-base.tar.zst
  ssh -F "/srv/hostwarden/memory/ssh_config" root@pve1.example.com \
    "tar -xOf $A ./home/alice/.ssh/authorized_keys" \
    > ~/.cache/hostwarden/template.pve1.example.com.pub
  ```

  ```bash
  ssh-keygen -lf ~/.cache/hostwarden/template.pve1.example.com.pub
  ```

  A key the override does not name is reported, one it names and
  the archive lacks is a miss. Delete the cache file afterwards.
- **Timezone:** `etc/timezone` where the listing has it, else the
  target of the `etc/localtime` link.
- **Automatic Security Updates, Firewall, Journal, Mail Relay,
  Monitoring:** the packages the overrides name for the relay and
  the agent join the `grep` list; the package lines say installed or not; the
  settings files say enabled. A firewall counts as the baseline says it does
  for a container (`rules/baseline.md` → Firewall): the one inside.
  A mail relay's configuration is checked for its presence and
  mode from the listing only: its content holds a credential and is
  never read (`rules/secrets.md`).
- **cloud-init:** the count of `etc/cloud` entries says whether the
  archive carries it. Neither answer is a miss: a baked template
  needs none.
- **ssh.socket:** an `ssh.socket` under `sockets.target.wants` means
  sshd starts on demand, and every guest from the archive has that
  shape. It is recorded on the line below, so a session that means
  to reload ssh on such a guest reads `systemctl cat ssh.socket`
  first (`rules/os/debian.md` → sshd).
- **Checksum:** `sha256sum` on every node that holds the archive,
  one value across all of them. A node whose value differs holds a
  different archive under the same name, which is a finding.

## The result

Recorded on the node as the `Baseline template:` line
(`rules/appliance/proxmox-ve.md` → Guests), with `adopted` and the archive's
distribution, release and init where a
rendering number would stand, since the rendering is not one of
Hostwarden's and is not numbered in `memory/baseline/`:

```
- Baseline template: local:vztmpl/<file>
  (adopted, debian 13, systemd, measured 2026-09-22,
  sha256 <sum>; complete)
- Baseline template: local:vztmpl/<file>
  (adopted, alpine 3.22, openrc, measured 2026-09-22,
  sha256 <sum>; missing automatic updates)
```

Show the measurement to the user before the line is written, and ask
whether to adopt it: a miss is theirs to accept or to have fixed by
building Hostwarden's template instead. Hostwarden never edits the
archive.

A guest made from it records `- Baseline: adopted <file>` and gets
its first-boot wait from `references/proxmox.md` → A container from
the baseline template: an archive that carries neither Hostwarden's
units nor cloud-init has nothing to wait for but
`systemctl is-system-running --wait`, and the measurement of
`SKILL.md` → After creation step 7 is then the only check of its
baseline.

An adopted line is never due for a rebuild by age or by a newer
rendering. It is INFO while its measurement lists a miss, and the
user decides when Hostwarden's own template replaces it.
