# Installer Answer Files

For a guest that has to be installed rather than copied from a
cloud image: a host whose UI can neither import a disk image nor
attach a seed (`SKILL.md` → Hosts that keep guests to their UI), a
distribution with no cloud image for this release, or a user who
asks for the installer. The installer reads the answer file once,
into a system that has never run (`SKILL.md` → The baseline).

Four formats, one per family: kickstart for the RHEL family,
preseed for Debian, autoinstall for Ubuntu, AutoYaST for SUSE.

## What the answer file does

The answer file installs the OS and hands the baseline to
cloud-init, rather than carrying the baseline itself. It sets only:

- the disk, the network, the timezone and the packages the
  installer owns;
- no password anywhere — root locked, and no user created with
  one;
- `cloud-init` among the installed packages;
- the rendered baseline as a seed for the installed system's first
  boot.

Everything else — the SSH user and its keys, sshd's drop-in, the
firewall, the updater, the journal — is the same rendered file
every other path uses (`references/user-data.md`), applied by
cloud-init at the first boot after the install. One rendering, one
validation, one version recorded in memory. Ubuntu's installer
takes that rendered file as it stands (Autoinstall below).

The seed is `references/user-data.md` → The seed, written into the
installed system.

A user with no key who asks for a password gets it from cloud-init
at the first boot (`references/user-data.md` → Passwords). No
answer file sets a password or carries a hash.

## The rendered files

`rules/baseline.md` → Rendered Versions names them and says how a
carrier is numbered: by its own content, recording which rendering
of the baseline it carries. Render, number and compare each as
`references/user-data.md` → Rendering it says. The guest's own
names — the hostname in the installer's network line, the
`instance-id` in the seed — go on a copy at hand-off and are never
numbered.

They are written and copied as `references/user-data.md` →
Rendering it says, for the same reason.

## Kickstart — RHEL, Rocky, AlmaLinux, Fedora

Syntax: <https://pykickstart.readthedocs.io/en/latest/>.

```
text
network --bootproto=static --ip=192.0.2.21 --netmask=255.255.255.0 --gateway=192.0.2.1 --nameserver=192.0.2.53 --hostname=web1.example.com --activate
timezone Europe/Berlin --utc
rootpw --lock
firewall --enabled --service=ssh
services --enabled=sshd
reboot

%packages
openssh-server
qemu-guest-agent
cloud-init
%end
```

- A kickstart command is one line. There is no continuation:
  `ksvalidator` reads a backslash-wrapped `network` line as three
  commands and rejects two of them, so `network` stays long even
  where that passes 80 characters.
- `rootpw --lock` locks root and creates no other account, so the
  install ends with no password on the system. The SSH user comes
  from cloud-init at the first boot.
- `sshkey --username USERNAME PUBLIC_KEY` exists and is not used:
  it needs a user the kickstart created, and one account made two
  ways drifts. Where a user insists on a login before cloud-init
  runs, `user --name=alice --groups=wheel --lock` plus `sshkey` is
  the documented pair.
- `firewall --enabled --service=ssh` is the baseline's Firewall
  section, set before the first boot rather than after it.
- The seed file goes in a `%post` section, which runs chrooted in
  the installed system unless `--nochroot` says otherwise. Give it
  `--erroronfail`, so an install that could not write the seed
  stops visibly rather than producing a guest with no login.

## Preseed — Debian

Syntax: <https://www.debian.org/releases/stable/amd64/apb.en.html>.

```
d-i passwd/root-login boolean true
d-i passwd/root-password-crypted password !
d-i passwd/make-user boolean false
d-i pkgsel/include string openssh-server qemu-guest-agent cloud-init
d-i pkgsel/upgrade select none
tasksel tasksel/first multiselect standard
popularity-contest popularity-contest/participate boolean false
d-i finish-install/reboot_in_progress note
```

- `!` as the crypted password disables the account: "The
  `passwd/root-password-crypted` and `passwd/user-password-crypted`
  variables can also be preseeded with '!' as their value. In that
  case, the corresponding account is disabled." With
  `make-user false` no second account is made either, so again
  nothing on the installed system has a password.
- Never preseed a real password, hashed or not: "Preseeding
  passwords is not completely secure as everyone with access to the
  preconfiguration file will have the knowledge of these
  passwords." The preconfiguration file lives on the hypervisor.
- `pkgsel/upgrade select none`: the baseline's own
  `package_upgrade` runs at the first boot, and an upgrade in the
  installer would download the same packages an hour earlier and
  can pull a reboot forward into the install.
- `preseed/late_command` writes the seed. It runs in the
  installer, with the installed system mounted at `/target`, so
  the seed rides on the medium beside the preseed and is copied
  in rather than written out on the command line:

  ```
  d-i preseed/late_command string cp /cdrom/90-hostwarden.cfg /target/etc/cloud/cloud.cfg.d/90-hostwarden.cfg
  ```
- A network the installer needs before it reads the file cannot be
  preseeded; a static address is given as kernel arguments
  (`netcfg/…`) or the installer takes DHCP.

## Autoinstall — Ubuntu

Syntax:
<https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html>.

Ubuntu's installer takes the rendered cloud-init file as it stands,
so this format carries no seed:

```yaml
#cloud-config
autoinstall:
  version: 1
  ssh:
    install-server: true
    authorized-keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI… alice@example.com
    allow-pw: false
  packages:
    - qemu-guest-agent
  user-data:
    # hostwarden-baseline debian-3 (2026-09-22)
    …
```

- No `identity` section: "This is the only configuration key that
  must be present (unless the user-data section is present, in
  which case it is optional)", and identity needs an encrypted
  password, which the baseline has no use for. The user comes from
  `user-data` instead — "users created using cloud-init user-data
  will be created on first boot".
- `allow-pw: false` is the baseline's SSH Login section; subiquity
  writes sshd's configuration itself, so nothing else has to.
- `user-data` here is the rendered file's body, indented under the
  key, without its `#cloud-config` line: the wrapper above already
  carries one.
- The `#cloud-config` header and the `autoinstall:` key are
  required when the file arrives through cloud-init. A file named
  `autoinstall.yaml` on the medium is passed to the installer
  directly and needs neither.
- The rendered file also carries `shutdown: reboot`, so the guest
  comes up by itself when the install finishes.

## AutoYaST — SUSE

Syntax: <https://doc.opensuse.org/projects/autoyast/>, and the
profile schema in the YaST modules themselves.

```xml
<?xml version="1.0"?>
<profile xmlns="http://www.suse.com/1.0/yast2ns"
         xmlns:config="http://www.suse.com/1.0/configns">
  <general>
    <mode>
      <confirm config:type="boolean">false</confirm>
    </mode>
  </general>
  <users config:type="list">
    <user>
      <username>root</username>
      <user_password>!</user_password>
      <encrypted config:type="boolean">true</encrypted>
    </user>
  </users>
  <firewall>
    <enable_firewall config:type="boolean">true</enable_firewall>
    <start_firewall config:type="boolean">true</start_firewall>
    <default_zone>public</default_zone>
    <zones config:type="list">
      <zone>
        <name>public</name>
        <services config:type="list">
          <service>ssh</service>
        </services>
      </zone>
    </zones>
  </firewall>
  <software>
    <packages config:type="list">
      <package>openssh</package>
      <package>cloud-init</package>
      <package>qemu-guest-agent</package>
    </packages>
  </software>
  <files config:type="list">
    <file>
      <file_path>/etc/cloud/cloud.cfg.d/90-hostwarden.cfg</file_path>
      <file_permissions>644</file_permissions>
      <file_contents>…</file_contents>
    </file>
  </files>
</profile>
```

- `<confirm>false</confirm>` is what makes the install unattended;
  without it AutoYaST stops at the settings screen.
- `!` as an encrypted password locks root, by the same shadow
  semantics preseed relies on. Confirm it on the guest afterwards:
  `passwd -S root` reports `L`.
- A user with keys, where one is wanted before cloud-init runs, is
  `<authorized_keys config:type="list"><authorized_key>…` inside
  the `<user>` entry.
- `<files>` writes the seed with its permissions; a post-script is
  not needed for it.
- The firewall element names come from YaST's own profile schema
  (`yast-firewall`, `src/autoyast-rnc/firewall.rnc`), which is the
  only complete list of them.

## Handing it to the installer

### libvirt

`virt-install` puts the file into the installer's initrd, so
nothing has to serve it over the network:

The call is `references/libvirt.md` → Creating it, with three
changes: `--import` and the copied disk give way to `--location`
and an empty disk of the size asked for, because this guest boots
an installer rather than a prepared image, and `--cloud-init` to
the two options that carry the answer file:

```bash
  --location /var/lib/libvirt/images/<installer image> \
  --initrd-inject /run/hostwarden-answer.cfg \
  --extra-args "inst.ks=file:/hostwarden-answer.cfg console=ttyS0"
```

- `--initrd-inject` "Add PATH to the root of the initrd fetched
  with `--location`", which is why the file is named at the root
  in the kernel argument.
- The kernel argument differs per installer:
  `inst.ks=file:/…` for anaconda,
  `auto=true priority=critical preseed/file=/…` for Debian,
  `autoyast=file:///…` for AutoYaST, and for Ubuntu
  `autoinstall` with the datasource, since subiquity reads its
  file through cloud-init.
- `--location` takes a tree or an installer ISO; a live ISO needs
  its `kernel=` and `initrd=` sub-options. Read
  `virt-install --location=?` on the host rather than guessing the
  paths inside an image, in that file's Before the creation call.

### A host whose UI owns the guests

The UI attaches the installer ISO; the answer file rides on a
second ISO, built as `references/seed-iso.md` builds one. For
Ubuntu that ISO is the `cidata` seed the installer already looks
for, and the guest boots with `autoinstall` on its kernel
command line. For the others the user adds the kernel argument
from libvirt above in the boot menu, once.

This is what turns "only its installer is left, and that sets a
password the user types" into a guest that comes up with the
baseline on it. Where the user cannot reach the boot menu at all,
that dead end stands: say so, and let them decide.

### Proxmox VE and Incus

A Proxmox VE VM takes the installer ISO as `--ide2 <storage>:iso/…`
and the answer ISO as a second CD drive; nothing else about
`references/proxmox.md` changes. Incus and LXD create from images,
not installers, and have no path here: use `references/incus.md`.

## Checking it before the install

Each format has its own check, and a file that does not pass is not
used:

- kickstart: `ksvalidator <file>` on a host that has
  `pykickstart`.
- preseed: `debconf-set-selections --checkonly <file>` on a Debian
  host.
- autoinstall: `cloud-init schema -c <file> --annotate`, since the
  wrapper is a cloud-config file.
- AutoYaST:
  `yast2 autoyast check-profile filename=<file> output=result.xml`
  on a SUSE host. It runs pre-installation scripts and ERB as root,
  so run it only on a host meant for it, never on a production
  server.

The rendered cloud-init file is checked once, as
`references/user-data.md` → Checking it says. For autoinstall that
check is the wrapper's: `cloud-init schema` reads the body under
`user-data` with it.

## After creation

`SKILL.md` → After creation, with one difference: no manager
command enters the guest, and an install outlasts a call. The wait
is for the guest's SSH port, from the host:

```bash
timeout 570 sh -c 'until nc -z 192.0.2.21 22; do sleep 15; done'
```

Run it again where it ends first, then report; then go on at step
2 with `-o StrictHostKeyChecking=accept-new` and
`cloud-init status --wait --long` over SSH.

The guest's memory gets `- Origin: <installer image>` beside the
baseline line, so the next session knows it was installed rather
than cloned from an image.
