# Changing an Image Before Its First Boot

For a guest whose disk image cannot be configured at boot: an image
with no cloud-init and no Ignition, a hypervisor that attaches
neither a seed nor user-data, or a vendor's appliance image the
user brought. The image is changed on the host while nothing runs
from it, and the guest that boots from it is booting for the first
time (`SKILL.md` → The baseline).

The tool is libguestfs. It "modifies the guest or disk image *in
place*. The guest must be shut down", and using it "on live virtual
machines, or concurrently with other disk editing tools, can be
dangerous, potentially causing disk corruption"
(<https://libguestfs.org/virt-customize.1.html>). So: only on a
copy made for this guest, only before its first start, and never on
the disk of a guest that exists.

## Which image, and the copy

Work on a copy made for this guest, never on the verified original,
so the next guest starts from a file whose checksum still matches
the list: `references/libvirt.md` → The disk, or
`references/proxmox.md` → The image, which says what changes in
the creation there. The commands below name the libvirt copy; on
Proxmox VE they take that copy's path.

A checksum recorded in memory afterwards is the original's, not the
copy's, so the guest's memory records
`- Origin: <image file>, customised before first boot`.

## The first choice: give it cloud-init instead

An image that can run cloud-init needs nothing written into it by
hand. Copy the seed in and let the guest configure itself at its
first boot, with the same rendered file every other path uses:

```bash
virt-customize -a /var/lib/libvirt/images/web1.qcow2 \
  --copy-in /run/90-hostwarden.cfg:/etc/cloud/cloud.cfg.d
```

- The seed is `references/user-data.md` → The seed.
- `--copy-in LOCALPATH:REMOTEDIR` needs the directory to exist
  already; `--mkdir` makes it where it does not.
- Where the image has no cloud-init but does have a package
  manager and the host has network, `--install cloud-init` adds it
  in the same call. `--no-network` is the opposite and makes
  `--install` fail, which is the documented behaviour, not a bug
  to work around.
- `--run-command` runs chrooted in the image and is for what the
  seed cannot express — enabling a unit the distribution ships
  disabled, for instance. Prefer the seed: what runs at first boot
  is then the same on every path and is recorded by one version
  number.

Then create the guest from the image as its platform's reference
says, and go on at `SKILL.md` → After creation.

## Host keys and the machine ID

An image that has been booted once — a golden image, a vendor
appliance, a template someone built — carries that boot's SSH host
keys and machine ID. Every guest made from it would answer with
the same host key, so the fingerprint in `known_hosts` would prove
nothing.

`virt-sysprep` removes them, on the copy, before the first start:
`virt-sysprep -a <image copy>`, alone in its call. Its default
`ssh-hostkeys` operation deletes the image's host keys, so the
taboo guard asks about it with the image path in front of the
user, and refuses it where no prompt reaches one, with `-d`, or
with anything else on the line. Say so in the plan, so the prompt
is expected rather than a surprise.

Read `virt-sysprep --list-operations` on the host first and name
in the plan which of them will run: the default set differs
between versions, and this is the one command here that removes
files rather than adding them. sshd makes new host keys at the
next boot; nothing is copied in to replace them.

The image is a file and the keys in it belong to a boot that is
over, so this is not a change to an SSH server that runs.

A freshly downloaded cloud image needs none of this: it has no
host keys yet.

## Where this path ends

An image with no cloud-init that cannot be given any — no package
manager, no network, a filesystem the appliance owns — leaves only
one way to a login: writing `authorized_keys` and sshd's drop-in
into the image itself.

Hostwarden does not write those two files from outside the guest
(`SKILL.md` → The baseline): a login placed that way is in no
rendered file and in no version, so nothing afterwards can say
what the guest was built with. Say in one line that this image can
be prepared only by hand, give the user each file and where it
goes, and stop. Replacing the whole OS on such a machine is a
different workflow with a gate of its own, `hostwarden-os-install`.

## Checking it

Before the guest is created, read back what was written, in one
call:

```bash
virt-cat -a /var/lib/libvirt/images/web1.qcow2 \
  /etc/cloud/cloud.cfg.d/90-hostwarden.cfg
```

The seed must come back with the baseline's version line in it. An
image that does not show the file is not started: the guest would
come up with no login and no firewall, and finding that out costs
the creation twice.
