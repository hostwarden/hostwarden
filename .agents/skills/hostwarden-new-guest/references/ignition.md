# Ignition

Fedora CoreOS and Flatcar Container Linux read no cloud-init. Write
the baseline as Butane and transpile it to Ignition JSON; Ignition
JSON is never written by hand.

The guest reads that config once, in the initramfs of its first
boot, and never again — "On first boot, Ignition reads its
configuration from a source of truth … and applies the
configuration" (<https://coreos.github.io/ignition/>). A config
handed to a guest that has already booted does nothing, so there
is no second chance and no way to touch a guest that runs.

Sources:
<https://coreos.github.io/butane/>,
<https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/>,
<https://www.flatcar.org/docs/latest/provisioning/>.

## Which variant and version

The header pair is the release's, not a remembered one: a spec
version newer than the Ignition in the image fails the boot with
nothing to log into. Read the pair from the release's own
documentation at the time of the creation
(`rules/version-check.md`), and name it in the plan.

- Fedora CoreOS: `variant: fcos`, the version its Butane spec page
  lists (`1.6.0` on
  <https://coreos.github.io/butane/config-fcos-v1_6/>).
- Flatcar: `variant: flatcar`, the version its page lists (`1.1.0`
  on <https://coreos.github.io/butane/config-flatcar-v1_1/>).

## The rendered file

`rules/baseline.md` → Rendered Versions names it; `<family>` is
`fcos` or `flatcar`. Render, number
and compare it as `references/user-data.md` → Rendering it says;
only the keys differ, and the guest's own hostname and address go
on the copy there. The transpiled `.ign` is a build product of
that copy and is not kept.

It is written and copied as `references/user-data.md` → Rendering
it says, for the same reason.

An example carrying the baseline's Admin Keys, SSH Login and
Journal sections:

```yaml
variant: fcos
version: 1.6.0
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI… alice@example.com
storage:
  files:
    - path: /etc/ssh/sshd_config.d/10-hostwarden.conf
      mode: 0600
      contents:
        inline: |
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          PermitRootLogin prohibit-password
    - path: /etc/systemd/journald.conf.d/50-hostwarden.conf
      mode: 0644
      contents:
        inline: |
          [Journal]
          Storage=persistent
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: web1.example.com
```

- `passwd.users` with `ssh_authorized_keys` is the login
  (<https://coreos.github.io/butane/config-fcos-v1_6/>). The user
  the image already has is `core` on both; "a privileged user named
  `core` is created on the Fedora CoreOS system, but it is not
  configured with a default password or SSH key". A user of another
  name is created by the same list, with `groups: [wheel]` on
  Fedora CoreOS and `groups: [sudo]` on Flatcar.
- Fedora CoreOS already refuses password logins through
  `40-disable-passwords.conf`, and a file that must win over it
  sorts before it. `10-hostwarden.conf` does, and the baseline
  states the setting rather than inheriting it
  (<https://docs.fedoraproject.org/en-US/fedora-coreos/authentication/>).
- No password goes into the file. Ignition is the one format with
  no counterpart to `references/user-data.md` → Passwords: its
  `password_hash` field takes a hash, which means Hostwarden would
  have to know the password to compute it. A user who wants one
  sets it themselves, on the hypervisor's console or over their
  first key login. Say that in one line when the question comes
  up, rather than hashing anything.
- A service the baseline needs goes under `systemd.units` with
  `enabled: true`; a file under `storage.files`.

## Transpiling and checking it

`--strict` makes a warning an error, so nothing reaches a guest on
a config that only nearly parses. The transpile runs in the same
call as the creation, ahead of it, so a config that does not
transpile creates nothing:

```bash
butane --strict --pretty --output /run/hostwarden.ign /run/hostwarden.bu
```

`--output` rather than a redirect, as the documentation asks
(<https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/>).
Where the host has no `butane` — which its Before the creation
call reports — the documented container does the same work:

```bash
podman run --interactive --rm quay.io/coreos/butane:release \
  --pretty --strict < /run/hostwarden.bu > /run/hostwarden.ign
```

A transpile that fails stops the creation; it is the only check
before the guest boots, as `cloud-init schema` is for user-data.

## Handing it to the guest

### libvirt

The config goes in over QEMU's firmware config device. The name
differs per OS and is not interchangeable:

- Fedora CoreOS: `opt/com.coreos/config`
  (<https://github.com/coreos/fedora-coreos-docs/blob/main/modules/ROOT/pages/getting-started-libvirt.adoc>)
- Flatcar: `opt/org.flatcar-linux/config`
  (<https://www.flatcar.org/docs/latest/deploy/virt-options/libvirt/>)

The call is `references/libvirt.md` → Creating it, with
`--cloud-init` replaced by one option:

```bash
  --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=/var/lib/libvirt/images/web1.ign"
```

- Both paths in it are absolute; the documentation requires it.
- Where SELinux is enforcing, the config file needs the label qemu
  may read, `chcon --verbose --type svirt_home_t <file>`, before
  the first start. `getenforce` on the host says whether it is,
  and belongs in that file's Before the creation call.
- `--osinfo`: the ID this host's database has. An older one has no
  `fedora-coreos-*`; the newest Fedora it does have is the answer.
- `--cloud-init` is not used and must not be: the two are separate
  mechanisms and the guest reads only this one.

### Proxmox VE

Both images read Ignition through the cloud-init drive, so
`--cicustom` carries it — but through a different key each, and the
image is the platform's own build, not the generic one:

- Fedora CoreOS: the `proxmoxve` platform image, and
  `--cicustom vendor=<storage>:snippets/<file>.ign` with
  `--ciupgrade 0`
  (<https://github.com/coreos/fedora-coreos-docs/blob/main/modules/ROOT/pages/provisioning-proxmoxve.adoc>).
- Flatcar: `flatcar_production_proxmoxve_image.img`, and
  `--cicustom user=<storage>:snippets/<file>.ign`
  (<https://www.flatcar.org/docs/latest/deploy/virt-options/proxmoxve/>).

In the creation call of `references/proxmox.md` → A VM from a
cloud image, one `qm set` replaces the one that carries the
user-data snippet:

```bash
qm set <vmid> --cicustom vendor=local:snippets/<vmid>-config.ign --ciupgrade 0
```

The storage, the snippets directory and everything else about the
VM are unchanged. The one rule that is new: never give such a VM
cloud-init data as well.
"You cannot use both Ignition config and regular cloud-init"; the
`--ciuser`, `--sshkeys` and `--cipassword` options do nothing here
and are left out.

### Incus, LXD, and a host whose UI owns the guests

No path. Neither manager documents an Ignition datasource, and the
UIs that take a custom configuration take cloud-init. Say so and
stop rather than improvise one.

## The image

`references/images.md` → Fedora CoreOS and → Flatcar. Each
platform takes its own build of the image, named there.

## What the baseline means here

An image-based OS has no package manager, so several sections of
`rules/baseline.md` are met by the image rather than by anything
written at creation. Record what holds; report what does not, as a
finding of this run.

- **Automatic Security Updates:** met already. Fedora CoreOS
  updates itself through Zincati and rpm-ostree
  (<https://docs.fedoraproject.org/en-US/fedora-coreos/auto-updates/>),
  Flatcar through update-engine. Nothing is installed for it. Read
  the strategy at After creation and record it; a guest whose
  updates were switched off is a finding.
- **Firewall:** neither ships one enabled. The ruleset is the
  baseline's — incoming denied by default, every port sshd listens
  on open — written into `storage.files` with the unit that loads
  it in `systemd.units`, for the tool the release's own
  documentation names and no other; do not assume
  `nftables.service` exists. Where the release documents none, the
  guest is created without a firewall and that is a finding of
  this run, reported in one line.
- **SSH Login and Admin Keys:** the Butane config above.
- **Time Sync:** the image's own service; Flatcar's documentation
  names `systemd-timesyncd` for its images
  (<https://www.flatcar.org/docs/latest/>). Add none. At After
  creation, `timedatectl` on the guest says which service runs and
  whether the clock is synchronized, and that is what is recorded.
- **Timezone:** a `/etc/localtime` link under `storage.files`,
  only where the override names one.
- **Journal:** the drop-in above.
- **Guest Agent:** not in either image. On Fedora CoreOS it is an
  OS extension, installed by a systemd unit that runs `rpm-ostree`
  and needs a reboot
  (<https://docs.fedoraproject.org/en-US/fedora-coreos/os-extensions/>);
  offer that as a separate step after the guest is registered,
  never as part of the first boot.
- **Backup:** the hypervisor's job, as for every guest.

## After creation

`SKILL.md` → After creation, with two differences.

There is no `cloud-init status --wait`. Ignition runs before the
root filesystem is handed to systemd, so the guest is done when it
answers on SSH with the keys from the config. The wait is one call
on the host, not an SSH retry:

```bash
timeout 570 sh -c 'until nc -z 192.0.2.21 22; do sleep 15; done'
```

Run it again where it ends first, then report. A guest that never
answers has an Ignition failure on its console, which the
hypervisor shows: read it there rather than guessing, then fix the
Butane file and create the guest again.

Hostwarden has no family file for an image-based CoreOS. Detection
knows that and stops at its no-family path
(`rules/os-detection.md`, step 2): generic commands, extra
verify-before-running care, and the user told. Record
`- Origin: <image file>` and `- Baseline: <version> (created
<date>)` as usual, and say in one line at the hand-over that the
package and updater checks do not apply there. Everything else —
sshd, the firewall, the journal, the audits that read them — is
ordinary OpenSSH and systemd and holds.
