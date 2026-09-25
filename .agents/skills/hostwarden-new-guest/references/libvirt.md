# libvirt

`virt-install` and `virsh`, always against `qemu:///system`
(`rules/hypervisors.md` → Inventory). Sources: the `virt-install`
manual, <https://github.com/virt-manager/virt-manager/blob/main/man/virt-install.rst>,
and <https://libvirt.org/manpages/virsh.html>. `--cloud-init` needs
virt-install 3.0 or later, `network-config=` 4.0 or later:
`virt-install --version` first.

## Before the creation

In one call: `virsh -c qemu:///system nodeinfo`, `dominfo` of each
running domain for the memory it holds,
`virsh -c qemu:///system pool-list --details` for free space, and
`ip -br link show type bridge` for the bridges.

## The disk

Download and verify the image on the host into
`/var/lib/libvirt/images/` (`references/images.md`), then give the
guest a copy of its own, so it never depends on the download:

```bash
test ! -e /var/lib/libvirt/images/web1.qcow2 &&
  cp /var/lib/libvirt/images/<image> /var/lib/libvirt/images/web1.qcow2 &&
  qemu-img resize /var/lib/libvirt/images/web1.qcow2 20G
```

A disk of that name that exists already belongs to something
else, a domain or not: stop and show it to the user, never
overwrite it.

`/var/lib/libvirt/images` carries the SELinux label libvirt
needs on the hosts that use it. cloud-init grows the root
filesystem into the new size at first boot.

## Creating it

```bash
virt-install --connect qemu:///system --import --name web1 \
  --memory 2048 --vcpus 2 --osinfo debian13 \
  --disk path=/var/lib/libvirt/images/web1.qcow2,format=qcow2,bus=virtio \
  --network bridge=br0,model=virtio,mac=52:54:00:12:34:56 \
  --cloud-init user-data=<file>,network-config=<file> \
  --graphics none --noautoconsole --autostart
```

- `--osinfo`: the ID from `virt-install --osinfo list` on this
  host. Where its database lacks the release, the newest one of
  the same distribution it has.
- `--network bridge=` for a guest with its own address on the
  LAN; `network=default` is libvirt's NAT network.
- `mac=`: pick one under `52:54:00`, check no domain has it
  (`domiflist`), and match it in the network config.
- `user-data=` makes virt-install ignore its other cloud-init
  options. The NoCloud ISO it builds is attached for the first
  boot only and deleted once the VM has started, so the rendered
  file in `memory/baseline/` is the only copy.
- virt-install adds the guest agent's channel on its own.

The network config, for a static address; leave it out for DHCP
on a libvirt network:

```yaml
version: 2
ethernets:
  eth0:
    match:
      macaddress: "52:54:00:12:34:56"
    set-name: eth0
    addresses: [192.0.2.23/24]
    routes:
      - to: default
        via: 192.0.2.1
    nameservers:
      addresses: [192.0.2.53]
```

As its own document, the network config starts at `version:`;
the `network:` key around it belongs only inside cloud-config
(<https://docs.cloud-init.io/en/latest/reference/datasources/nocloud.html>,
network-config). Validate it like the user-data, with
`-t network-config`.

## A guest that reads something other than cloud-init

`--cloud-init` is for images that run cloud-init. The call above
carries Ignition instead for Fedora CoreOS and Flatcar
(`references/ignition.md` → libvirt), and an installer's answer
file for a guest that has to be installed
(`references/answer-files.md` → libvirt). Each names the options
it changes.

## Waiting for the first boot

libvirt cannot run a command in the guest or read its host key.
The guest agent answers once cloud-init has installed it, near the
end of the first boot; one call waits for it and shows the
address:

```bash
timeout 570 sh -c 'until virsh -c qemu:///system domifaddr web1 \
  --source agent >/dev/null 2>&1; do sleep 15; done' &&
  virsh -c qemu:///system domifaddr web1 --source agent
```

Then go on at `SKILL.md` → After creation step 2.
