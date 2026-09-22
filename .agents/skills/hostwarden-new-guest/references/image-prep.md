# Changing an Image Before Its First Boot

For a guest whose disk image cannot be configured at boot: an image
with no cloud-init and no Ignition, a hypervisor that attaches
neither a seed nor user-data, or a vendor's appliance image the
user brought. The image is changed on the host while nothing runs
from it, and the guest that boots from it is booting for the first
time — the case `AGENTS.md` → Critical Safety Rules covers.

The tool is libguestfs. It "modifies the guest or disk image *in
place*. The guest must be shut down", and using it "on live virtual
machines, or concurrently with other disk editing tools, can be
dangerous, potentially causing disk corruption"
(<https://libguestfs.org/virt-customize.1.html>). So: only on a
copy made for this guest, only before its first start, and never on
the disk of a guest that exists.

## Which image, and the copy

Verify the downloaded image as `references/images.md` says, then
copy it for this guest and work on the copy. The verified original
stays untouched, so the next guest starts from a file whose
checksum still matches the list.

A checksum recorded in memory afterwards is the original's, not the
copy's: the guest's memory records
`- Origin: <image file>, customised before first boot`, which says
that the running disk is no longer bit-for-bit what was verified.

## The first choice: give it cloud-init instead

An image that can run cloud-init needs nothing written into it by
hand. Copy the seed in and let the guest configure itself at its
first boot, with the same rendered file every other path uses:

```bash
virt-customize -a /var/lib/libvirt/images/web1.qcow2 \
  --copy-in /run/90-hostwarden.cfg:/etc/cloud/cloud.cfg.d
```

- The seed is the form `references/answer-files.md` → What the
  answer file does describes, with `instance-id` set to the
  guest's name.
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

```bash
virt-sysprep -a /var/lib/libvirt/images/web1.qcow2
```

Read `virt-sysprep --list-operations` on the host first and name
in the plan which of them will run: the default set differs
between versions, and this is the one command here that removes
files rather than adding them. sshd makes new host keys at the
next boot; nothing is copied in to replace them.

This is not a change to an SSH server that runs. The image is a
file, the keys in it belong to a boot that is over, and the guest
they would otherwise be handed to has never started.

A freshly downloaded cloud image needs none of this: it has no
host keys yet.

## Where this path ends

An image with no cloud-init that cannot be given any — no package
manager, no network, a filesystem the appliance owns — leaves only
one way to a login: writing `authorized_keys` and sshd's drop-in
into the image itself.

The taboo guard denies that, and the denial is correct as the
guard stands today even though `AGENTS.md` now allows the case.
Do not reach the same effect with another tool or another spelling.
Say in one line that this image can only be prepared by hand, give
the user the two files and where they go, and stop. What would
have to change in the guard for Hostwarden to do it is in the pull
request that added this file, as a patch for the operator to
apply; until it is applied, the rule and the guard disagree here
and the guard wins.

## Checking it

Before the guest is created, read back what was written, in one
call:

```bash
virt-cat -a /var/lib/libvirt/images/web1.qcow2 \
  /etc/cloud/cloud.cfg.d/90-hostwarden.cfg
virt-ls -a /var/lib/libvirt/images/web1.qcow2 /etc/cloud
```

The seed must come back with the baseline's version line in it. An
image that does not show the file is not started: the guest would
come up with no login and no firewall, and finding that out costs
the creation twice.
