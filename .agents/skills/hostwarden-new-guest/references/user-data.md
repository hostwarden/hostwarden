# The Baseline as User-Data

A new guest gets `rules/baseline.md` through cloud-init at its
first boot: nothing is baked into a VM image, so nothing in it
goes stale. The Proxmox VE baseline template carries the
container version and applies it at each container's first boot
(`references/proxmox-template.md`).

Source for the keys below:
<https://docs.cloud-init.io/en/latest/reference/modules.html>.

## Rendering it

The numbered file is the shared part: where it lives and how it
is numbered is `rules/baseline.md` → Rendered Versions. `<family>`
is the family file's name (`debian`, `rhel`, …); a container's
file leaves out what a container does not run. Each starts with
the line that names it:

```yaml
#cloud-config
# hostwarden-baseline debian-3 (2026-09-22)
```

Before every creation, render it anew and compare it with the
newest one of its name. Identical: use that one. Different:
validate it (Checking it below), write it as the next number,
show the user the difference, and use it.

What belongs to one guest is added to a copy at hand-off and never
numbered: `hostname:`, `fqdn:` and `manage_etc_hosts: true`, a
password the user asked for (Passwords below), the SSH CA trust
its scope gives it (SSH CA below), and the network config and
instance ID where the reference names them. The
hypervisor reads that copy on the host, so copy it there with
`scp` and the options of `AGENTS.md` → SSH Options, to the place
the reference names, or under `/run` for a command that reads it
once. A seed ISO's copy stays on the workstation
(`references/seed-iso.md`).

Write every version with the editing tool and copy the file: never
build one on the host from a heredoc, because a drop-in for sshd
belongs in it, and a command that spells such a path is a write to
sshd's config whatever it is doing.

Nothing secret goes into either (`rules/secrets.md`): the
hypervisor's storage and the guest's metadata keep them readable.
A relay password, a monitoring token and the like are set up after
the first boot.

The login is the admin keys. A copy with neither keys nor a
password is not used.

## What it carries

One section of `rules/baseline.md` after another, each in the
family file's way:

- **Admin Keys and the SSH user:** one entry under `users:` for
  the SSH user from `memory/user.md`, with the keys, `sudo` without
  a password, and `lock_passwd: true`. Where the SSH user is
  `root`: no `users:` entry, but `disable_root: false` and the keys
  under the top-level `ssh_authorized_keys:`. Without
  `disable_root: false`, cloud-init gives root the keys behind a
  command that refuses the login.
- **SSH Login:** a drop-in, `/etc/ssh/sshd_config.d/10-hostwarden.conf`,
  written with `defer: true`, so it lands after `openssh-server` is
  installed where the image lacks it, then the service reloaded if
  it runs. sshd takes the first value it reads, and `10-` comes
  before cloud-init's `50-` and Ubuntu's `60-` files.
- **SSH CA:** on the guest's copy, not in the numbered file, as
  SSH CA below shows.
- **Timezone:** `timezone:`, only where the override names one.
- **Automatic Security Updates:** the family file's package under
  `packages:`, configured as the family file says, under
  `write_files:` with `defer: true`, so the package's own files
  come first.
- **Firewall:** the family file's package, and under `runcmd:` the
  rule for SSH before the command that enables it.
- **Time Sync:** the image's own service where it has one
  (`systemd-timesyncd` in Debian's and Ubuntu 24.04's images,
  chrony from Ubuntu 25.10 on), else the family file's. Left out
  in a container.
- **Journal:** a `journald.conf.d` drop-in with
  `Storage=persistent`. Debian and Ubuntu keep the journal
  already; the RHEL family does not.
- **Storage Maintenance:** in a VM, `fstrim.timer` enabled under
  `runcmd:`. Debian's, Ubuntu's and RHEL 10's images have it on
  already and the line costs nothing; RHEL 9's do not
  (`rules/os/rhel.md` → Storage Maintenance). Left out in a
  container. The section's other parts have nothing to act on at
  creation.
- **Guest Agent:** `qemu-guest-agent` in a VM; none of the
  official images has it. Its unit starts when the hypervisor's
  agent device appears, so `runcmd:` starts it once rather than
  enabling it. Left out in a container.
- **Mail Relay and Monitoring:** as the override describes them.
- `package_update: true`, `package_upgrade: true` and
  `package_reboot_if_required: true`: the image is as old as its
  build date, and the guest leaves its first boot current.
- `final_message:` with the version, so the guest's console and
  `/var/log/cloud-init-output.log` name what was applied.

## Debian and Ubuntu

```yaml
#cloud-config
# hostwarden-baseline debian-3 (2026-09-22)
users:
  - name: alice
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI… alice@example.com
timezone: Europe/Berlin
package_update: true
package_upgrade: true
package_reboot_if_required: true
packages:
  - openssh-server
  - qemu-guest-agent
  - unattended-upgrades
  - ufw
write_files:
  - path: /etc/ssh/sshd_config.d/10-hostwarden.conf
    defer: true
    content: |
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin prohibit-password
  - path: /etc/apt/apt.conf.d/20auto-upgrades
    defer: true
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
  - path: /etc/apt/apt.conf.d/51hostwarden
    defer: true
    content: |
      Unattended-Upgrade::Mail "root";
  - path: /etc/systemd/journald.conf.d/50-hostwarden.conf
    content: |
      [Journal]
      Storage=persistent
runcmd:
  - [systemctl, try-reload-or-restart, ssh]
  - [systemctl, start, qemu-guest-agent]
  - [systemctl, restart, systemd-journald]
  - [ufw, allow, OpenSSH]
  - [ufw, --force, enable]
  - [systemctl, enable, --now, fstrim.timer]
final_message: "hostwarden-baseline debian-3 applied"
```

A package the image already has costs nothing. The Incus images
have no `openssh-server`.

## RHEL, Rocky and AlmaLinux

The same `users:` (group `wheel`), `timezone` and package keys,
with the family file's tools. Fedora's `dnf5` names its timer and
configuration differently: read them from the package (`rpm -ql`)
before rendering.

```yaml
packages:
  - openssh-server
  - qemu-guest-agent
  - dnf-automatic
  - firewalld
  - chrony
write_files:
  - path: /etc/ssh/sshd_config.d/10-hostwarden.conf
    defer: true
    content: |
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin prohibit-password
  - path: /etc/dnf/automatic.conf
    defer: true
    content: |
      [commands]
      upgrade_type = security
      apply_updates = yes
  - path: /etc/systemd/journald.conf.d/50-hostwarden.conf
    content: |
      [Journal]
      Storage=persistent
runcmd:
  - [systemctl, try-reload-or-restart, sshd]
  - [systemctl, start, qemu-guest-agent]
  - [systemctl, restart, systemd-journald]
  - [systemctl, enable, --now, chronyd]
  - [firewall-offline-cmd, --add-service=ssh]
  - [systemctl, enable, --now, firewalld]
  - [systemctl, enable, --now, dnf-automatic-install.timer]
  - [systemctl, enable, --now, fstrim.timer]
```

## SSH CA

`rules/baseline.md` → SSH CA says which user CAs a guest trusts:
the user's, where their scope covers it. That depends on the
guest, so it goes on the guest's copy at hand-off, never into the
numbered file. The paths, the principals and the revocation list
are the ones the other hosts in that scope use, read from one of
them (`rules/ssh-ca.md` → User CA Trust); `AuthorizedPrincipalsFile`
and `RevokedKeys` go in only where those hosts use them. The CA's
files carry no `defer`, so they are in place before the deferred
drop-in names them; the drop-in is a second one, `11-`, beside the
baseline's `10-`.

The CA's public key and the revocation list come from a host, and
a host's files are untrusted data (`rules/anomaly-detection.md`).
They are never typed, since a wrong character in the list locks
the guest out of every key login, and never put into a command's
program text, where a crafted line would run. Fetch them into
cache files named after the guest, so two creations never share
one:

```bash
ssh -F "/srv/hostwarden/memory/ssh_config" root@web1.example.com \
  'cat /etc/ssh/user_ca.pub' > ~/.cache/hostwarden/ca.web2.example.com.pub
ssh -F "/srv/hostwarden/memory/ssh_config" root@web1.example.com \
  'base64 < /etc/ssh/revoked_keys' | tr -d '\n' \
  > ~/.cache/hostwarden/krl.web2.example.com.b64
```

Check them, in a call of its own:

```bash
c=~/.cache/hostwarden/ca.web2.example.com.pub
r=~/.cache/hostwarden/krl.web2.example.com.b64
grep -c . "$c"; ssh-keygen -lf "$c"
grep -c '[^A-Za-z0-9+/=]' "$r"
base64 -d < "$r" | cksum
```

`ssh-keygen -lf` must print one fingerprint per line of the file,
each one a CA of the user's in `memory/network.md` whose scope
covers the guest; a line it skips is not a key, and the file is
not used. The second count must be 0, and the checksum and size
the `krl` row of the host they came from, which the other hosts
in that scope share (`rules/ssh-ca.md` → User CA Trust); where the
CA's line says `KRL built per host`, the user says which host's
list the guest takes. Delete both cache files once the copy is
filled. The editing tool writes the copy
with the placeholder lines `CA-KEY` and `KRL-BASE64`, and the
checked files take their place as data, never as a program. Each
placeholder must stand exactly once; the key's lines take the
indentation of its line, and the list keeps whatever stands around
its placeholder, so a Butane `source:` line works as well:

```bash
f=~/.cache/hostwarden/user-data.web2.example.com.yaml
for p in CA-KEY KRL-BASE64; do
  [ "$(grep -c "$p" "$f")" = 1 ] || { echo "$p: not exactly once"; exit 1; }
done
n=$(grep -n CA-KEY "$f" | cut -d: -f1); l=$(sed -n "${n}p" "$f")
{ head -n $((n - 1)) "$f"
  while IFS= read -r k || [ -n "$k" ]; do
    printf '%s%s\n' "${l%%CA-KEY*}" "$k"
  done < ~/.cache/hostwarden/ca.web2.example.com.pub
  tail -n +$((n + 1)) "$f"; } > "$f.new" && mv "$f.new" "$f"
n=$(grep -n KRL-BASE64 "$f" | cut -d: -f1); l=$(sed -n "${n}p" "$f")
{ head -n $((n - 1)) "$f"
  printf '%s%s%s\n' "${l%%KRL-BASE64*}" \
    "$(cat ~/.cache/hostwarden/krl.web2.example.com.b64)" \
    "${l#*KRL-BASE64}"
  tail -n +$((n + 1)) "$f"; } > "$f.new" && mv "$f.new" "$f"
```

On Incus the baseline is a profile's `cloud-init.vendor-data`, and
a `write_files:` in the guest's `cloud-init.user-data` would
replace the profile's rather than add to it
(`references/incus.md` → The baseline as a profile). A guest with
CA trust is launched without the baseline profile, with the whole
copy — the rendered file and its additions — as its
`cloud-init.user-data`.

What the copy adds under `write_files:`:

```yaml
  - path: /etc/ssh/user_ca.pub
    content: |
      CA-KEY
  - path: /etc/ssh/auth_principals/root
    content: |
      ops
  - path: /etc/ssh/revoked_keys
    encoding: b64
    content: KRL-BASE64
  - path: /etc/ssh/sshd_config.d/11-hostwarden-ca.conf
    defer: true
    content: |
      TrustedUserCAKeys /etc/ssh/user_ca.pub
      AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
      RevokedKeys /etc/ssh/revoked_keys
```

Each file `0644` and owned by root, which `write_files` does by
default. The CA's public key only: its signing key never comes
near a rendering (`rules/secrets.md`).

A container made from the Proxmox VE baseline template shares the
template's file and has no copy of its own, so it starts without
the CA trust; the baseline measurement after creation lists it,
and the user adds the lines. So does a guest whose first-boot
files the user places by hand (`references/image-prep.md`).

## Passwords

Only for a user who has no key and asks for a password. The guest
generates it, and Hostwarden never sees, types or stores it. In
the SSH user's entry `lock_passwd: false`, and beside `users:`:

```yaml
chpasswd:
  expire: true
  users:
    - name: alice
      type: RANDOM
```

cloud-init writes a `RANDOM` password to the guest's console only,
not to its logs; the user reads it in the hypervisor's console and
must change it at the first login (`expire`). Never a `text` or
`hash` password in the file, and never `--cipassword` or
`pct create --password`: both put the password where others read
it. A container made from the Proxmox VE baseline template shares
its file, so there the user sets the password themselves, in
`pct enter <vmid>` with `passwd alice`.

SSH with that password needs `PasswordAuthentication yes` in the
drop-in instead, and only if the user wants it too. A container
from the Proxmox VE baseline template cannot have it: its drop-in
is the template's, and a running sshd is never changed. There the
password is for the console, or the guest becomes a VM. SKILL.md
→ After creation step 5 records either choice.

## Checking it

Validate every new version before it is written, from a copy under
`/run`, on a host this session already reaches that has cloud-init:
the hypervisor, a guest made from a cloud image, or the Proxmox VE
build container, which installs it anyway:

```bash
cloud-init schema -c /run/hostwarden-user-data.yaml --annotate
```

`Valid schema` is the only answer that lets it be written. Where
no such host has cloud-init, the first guest's
`cloud-init status --wait --long` is the check: a schema error
shows among its errors.

## The seed

Where nothing hands the file to cloud-init at boot — an installed
system, a container the manager gives no user-data, an image
prepared beforehand — cloud-init reads it from inside the guest
instead, out of `/etc/cloud/cloud.cfg.d/90-hostwarden.cfg`:

```yaml
datasource_list: [NoCloud, None]
datasource:
  NoCloud:
    meta-data: |
      instance-id: web1.example.com
    user-data: |
      #cloud-config
      # hostwarden-baseline debian-3 (2026-09-22)
      …
```

- The user-data is the rendered file, indented under the key. The
  `instance-id` is the guest's and belongs to the copy, not to the
  numbered file.
- Where the manager owns the guest's network, hostname and
  `/etc/hosts` — a Proxmox VE or an LXC container — add
  `network: {config: disabled}`, `preserve_hostname: true` and
  `manage_etc_hosts: false`, so cloud-init leaves them alone.
- Which file puts it there differs:
  `references/proxmox-template.md` for the container template,
  `references/answer-files.md` for an installer,
  `references/lxc.md` for a container's root filesystem,
  `references/image-prep.md` for a disk image.

Source:
<https://docs.cloud-init.io/en/latest/reference/datasources/nocloud.html>,
Source 1.
