# Ignition

Fedora CoreOS and Flatcar Container Linux read no cloud-init. They
take one Ignition config from the platform in the initramfs of the
first boot and never again: "On first boot, Ignition reads its
configuration from a source of truth (remote URL, network metadata
service, hypervisor bridge, etc.) and applies the configuration"
(<https://coreos.github.io/ignition/>). A config handed to a guest
that has already booted does nothing, which is why this is the one
form the first-boot exception in `AGENTS.md` → Critical Safety
Rules covers here.

The config is written as Butane and transpiled to Ignition JSON;
Ignition JSON is never written by hand. Sources:
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

`memory/baseline/<family>-ign-<n>.bu`, with `<family>` as `fcos` or
`flatcar` (`rules/baseline.md` → Rendered Versions). Render, number
and compare it as `references/user-data.md` → Rendering it says;
only the keys differ. What belongs to this one guest — its
hostname, its keys where they are not the baseline's, a static
address — is added to a copy at hand-off and never numbered, as it
is there. The transpiled `.ign` is a build product of that copy
and is not kept.

Write the file with the editing tool and copy it to the host with
`scp` and the options of `AGENTS.md` → SSH Options. Never build it
on the host from a heredoc: a drop-in for sshd belongs in it, and
a command that spells such a path is a write to sshd's config
whatever it is doing.

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
  name is created by the same list and gets `groups: [sudo, wheel]`
  as the platform needs.
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
a config that only nearly parses:

```bash
butane --strict --pretty --output /run/hostwarden.ign /run/hostwarden.bu
```

`--output` rather than a redirect, as the documentation asks
(<https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/>).
Where the host has no `butane`, the documented container does the
same work:

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

```bash
virt-install --connect qemu:///system --import --name web1 \
  --memory 2048 --vcpus 2 --os-variant fedora-coreos-stable \
  --disk size=20,backing_store=/var/lib/libvirt/images/<image> \
  --network bridge=br0,model=virtio \
  --graphics none --noautoconsole --autostart \
  --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=/var/lib/libvirt/images/web1.ign"
```

- Both paths are absolute; the documentation requires it.
- Where SELinux is enforcing, the config file needs the label qemu
  may read, `chcon --verbose --type svirt_home_t <file>`, before
  the first start.
- `--os-variant`: the ID `virt-install --osinfo list` has on this
  host. An older database has no `fedora-coreos-*`.
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

```bash
qm set <vmid> --cicustom vendor=local:snippets/<vmid>-config.ign
qm set <vmid> --ciupgrade 0
```

The storage, the snippets directory and everything else about the
VM are `references/proxmox.md` → A VM from a cloud image. The one
rule that is new: never give such a VM cloud-init data as well.
"You cannot use both Ignition config and regular cloud-init"; the
`--ciuser`, `--sshkeys` and `--cipassword` options do nothing here
and are left out.

### Incus, LXD, and a host whose UI owns the guests

No path. Neither manager documents an Ignition datasource, and the
UIs that take a custom configuration take cloud-init. Say so and
stop rather than improvise one.

## The image

- **Fedora CoreOS:** `coreos-installer download -s <stream>
  -p <platform> -f qcow2.xz --decompress`, with `<platform>`
  `qemu` for libvirt and `proxmoxve` for Proxmox VE. Read what the
  download verifies from `coreos-installer download --help` on the
  host before trusting it, and where it verifies nothing, treat the
  stream's signature list as `references/images.md` does.
- **Flatcar:** the channel's
  `flatcar_production_<platform>_image.img` and the `.sig` beside
  it, checked against the image signing key, fingerprint
  `F88C FEDE FF29 A5B4 D952 3864 E25D 9AED 0593 B34A`:

  ```bash
  gpg --verify flatcar_production_qemu_image.img.sig
  ```

  Import the key into a keyring of this call's own, as
  `references/images.md` → Keys on the host says. A signature that
  does not verify stops the creation.

  Source: <https://www.flatcar.org/security/image-signing-key/>.

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
- **Firewall:** neither ships one enabled. Write the ruleset and
  the unit that loads it into `storage.files` and `systemd.units`
  only for the tool the release's own documentation names, read at
  creation time; do not assume `nftables.service` exists. Where the
  release documents none, the guest is created without one and the
  missing firewall is a finding of this run, reported in one line.
- **SSH Login and Admin Keys:** the Butane config above.
- **Time Sync:** the image's own service — `systemd-timesyncd` on
  Flatcar, by its documentation's page on date and time zone
  (<https://www.flatcar.org/docs/latest/>). Confirm it is running
  at After creation rather than adding one.
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

There is no `cloud-init status --wait`. The guest is up when it
answers on SSH with the keys from the config; Ignition has then
finished, since it runs before the root filesystem is handed to
systemd. A guest that never answers has an Ignition failure on its
console, which the hypervisor shows: read it there rather than
guessing, and fix the Butane file and create the guest again.

Hostwarden has no family file for an image-based CoreOS
(`rules/os/`). Detection finds Fedora or Flatcar and the family
file's package manager does not apply. Record
`- Origin: <image file>` and `- Baseline: <version> (created
<date>)` as usual, add `- OS: image-based, no package manager` to
the guest's memory, and say in one line that housekeeping's
package and updater checks report not applicable there until a
family file covers it. Everything else — sshd, the firewall, the
journal, the audits that read them — is ordinary OpenSSH and
systemd and holds.
