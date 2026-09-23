# Proxmox VE

`qm` and `pct` only, as `rules/appliance/proxmox-ve.md` says for
every guest on the node. Sources, unless noted:
<https://pve.proxmox.com/pve-docs/qm.1.html>,
<https://pve.proxmox.com/pve-docs/pct.1.html>,
<https://pve.proxmox.com/pve-docs/pveam.1.html>, and the code at
<https://git.proxmox.com> where the manual is silent.

Commands run as `root@pam`: only it may pass a plain file path to
`import-from`.

## Before the creation

```bash
pvesh get /cluster/nextid
pvesh get /nodes/$(hostname -s)/status --output-format json
pvesm status --enabled 1
grep -hE '^(net0|scsi0|rootfs):' /etc/pve/qemu-server/*.conf \
  /etc/pve/lxc/*.conf
```

- `nextid` is the ID; `pvesh get /cluster/nextid --vmid <n>`
  checks one the user chose.
- The node status gives memory and CPUs. What running guests hold
  is the sum of `maxmem` of this node's running guests in the
  inventory.
- `pvesm status --content <type> --enabled 1` lists the storages
  for one content type: `images` for a VM disk, `rootdir` for a
  container, `vztmpl` for templates, `snippets` for user-data,
  `iso` for an installer and its answer ISO.
- The config lines name the bridge and storage the other guests
  use: the defaults.

## A VM from a cloud image

### The image

Download it on the node into `/var/lib/vz/import/`, the directory
of `local`'s `import` content, creating it where that content is
not enabled, and verify it (`references/images.md`).

An image prepared before its first boot (`references/image-prep.md`)
is copied first, in the same call as its preparation, so the
verified original stays as it was:

```bash
cp /var/lib/vz/import/<image> /var/lib/vz/import/<vmid>-<image>
```

That copy is what `import-from` takes, and it is removed in the
call that imports it. Such an image carries its own seed, so
its VM gets no cloud-init drive, no `--cicustom` and no
`--ipconfig0`, and the snippet check after Creating it does not
apply: a second NoCloud source would compete with the one inside
the image. It takes its address by DHCP.

### The user-data snippet

`--cicustom` reads the file from a storage with `snippets`
content. On `local` that is `/var/lib/vz/snippets/`. Where no
storage has it, enabling it is a change to `/etc/pve/storage.cfg`,
which every node shares: ask, and give `--content` the storage's
whole list, read from that file, with `snippets` added:

```bash
pvesm set local --content iso,vztmpl,backup,snippets
```

A custom user file replaces what Proxmox VE would generate:
`--ciuser`, `--sshkeys`, `--ciupgrade` and the VM's name as the
hostname are ignored. So the snippet is the file for this guest
(`references/user-data.md` → Rendering it), names included.
Copy it, in the same `scp`, as `/var/lib/vz/snippets/<vmid>-user.yaml`
beside `/var/lib/vz/snippets/<vmid>-meta.yaml`, which holds the
fixed instance ID:

```yaml
instance-id: 101-web1
```

Without that file Proxmox VE derives the instance ID from the
user-data and the network config (`nocloud_gen_metadata` in
qemu-server's `Cloudinit.pm`), and a later `qm set --ipconfig0`
changes it (`rules/system-containers.md` → Changes).

Keep both files as long as the VM exists: the cloud-init drive is
built from them again when its settings change, and `--cicustom`
fails without them. A VM that may migrate needs them on every node
it can go to, so a shared storage with `snippets` is the better
place in a cluster.

### Creating it

In one call:

```bash
qm create <vmid> --name web1 --memory 2048 --cores 2 \
  --cpu x86-64-v2-AES --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci --ostype l26 --agent enabled=1 \
  --serial0 socket --vga serial0 --onboot 1
qm set <vmid> --scsi0 <storage>:0,import-from=/var/lib/vz/import/<image>
qm set <vmid> --ide2 <storage>:cloudinit --boot order=scsi0
qm set <vmid> --ipconfig0 ip=192.0.2.21/24,gw=192.0.2.1
qm set <vmid> --cicustom \
  user=local:snippets/<vmid>-user.yaml,meta=local:snippets/<vmid>-meta.yaml
qm disk resize <vmid> scsi0 20G
grep '^cicustom:' /etc/pve/qemu-server/<vmid>.conf
sha256sum /var/lib/vz/snippets/<vmid>-user.yaml \
  /var/lib/vz/snippets/<vmid>-meta.yaml
```

- `--cpu` explicitly: the default on the command line is `kvm64`,
  the web UI's is `x86-64-v2-AES`.
- The serial console is what the Debian and Ubuntu cloud images
  expect; without it, some show nothing on the console.
- `import-from` takes size `0` and an absolute path. The image is
  copied; the file stays.
- `--ipconfig0` always, `ip=dhcp` included: Proxmox VE writes no
  network configuration for a NIC without one. With `ip=dhcp`,
  leave `gw=` out.
- `qm disk resize` sets the size; cloud-init grows the root
  filesystem into it at first boot. It never shrinks.
- The `cicustom:` line must name both snippets, and their
  checksums must match those of the copies on the workstation.
  Anything else: stop before `qm start`, since a cloud image
  without its user-data has no login at all. `qm cloudinit dump`
  proves nothing here: it prints what Proxmox VE would generate,
  not the snippet (`dump_cloudinit_config` in `Cloudinit.pm`).

Then `qm start <vmid>`.

### Waiting for the first boot

The QEMU guest agent answers once cloud-init has installed it. One
call waits for it and for cloud-init, within the time a call may
take, then reads the public host key:

```bash
timeout 570 sh -c 'until qm guest cmd <vmid> ping 2>/dev/null
  do sleep 15; done
  qm guest exec <vmid> --timeout 0 -- cloud-init status --wait --long' &&
  qm guest exec <vmid> -- cat /etc/ssh/ssh_host_ed25519_key.pub
```

`qm guest exec` prints JSON: `exitcode` is the command's exit
code, `out-data` its output. Judge cloud-init by the first
object's `exitcode`, not by the call's exit status, and use the
key only when that is 0.

### A VM that reads Ignition

Fedora CoreOS and Flatcar read an Ignition config: one `qm set`
changes, named in `references/ignition.md` → Proxmox VE, and
everything else above is unchanged.

## A VM from an installer ISO

A guest installed rather than imported gets a creation of its own:
an empty disk, no cloud-init drive, no `import-from`, no
`--cicustom` and no `--ipconfig0`. Its network comes from the
answer file (`references/answer-files.md`). Before the creation
above still gives the ID, the capacity and the defaults.

Both ISOs go on a storage with `iso` content, `local`'s
`/var/lib/vz/template/iso/` by default. Copy the answer ISO there
first with `scp`, built on the workstation as
`references/seed-iso.md` says. Then one call downloads the
installer ISO there, verifies it with a keyring of its own as
`references/images.md` → Keys on the host says, and creates the
VM, each step joined to the next with `&&`, so a failed check
creates nothing:

```bash
qm create <vmid> --name web1 --memory 2048 --cores 2 \
  --cpu x86-64-v2-AES --scsihw virtio-scsi-pci --ostype l26 \
  --net0 virtio,bridge=vmbr0 --agent enabled=1 --onboot 1
qm set <vmid> --scsi0 <storage>:20
qm set <vmid> --ide2 local:iso/<installer iso>,media=cdrom
qm set <vmid> --ide3 local:iso/<answer iso>,media=cdrom
qm set <vmid> --boot 'order=scsi0;ide2'
```

- `<storage>:20` allocates a new, empty 20 GiB disk
  (<https://pve.proxmox.com/pve-docs/qm.1.html>).
- `order=scsi0;ide2`: the empty disk boots nothing, so the first
  start falls through to the installer; after the install the disk
  boots, and the installer never runs twice.
- No `--vga serial0`: the user needs the web UI's console for the
  installer's boot menu.

The installer reads the answer ISO only once its kernel command
line names it, and Hostwarden cannot edit the installer ISO's boot
menu. So the user adds that argument once, at the VM's console in
the web UI, as `references/answer-files.md` → A host whose UI owns
the guests says. Say so in the plan, and start the VM only once the
user is at the console. The start, the wait for the guest's SSH
port and the cleanup are one call:

```bash
qm start <vmid> && timeout 570 sh -c 'until nc -z 192.0.2.21 22; do sleep 15; done' && qm set <vmid> --delete ide2,ide3 && rm /var/lib/vz/template/iso/<answer iso>
```

An install often outlasts one call. When the wait ends first, the
next call repeats it without `qm start`; the cleanup still runs
only after it succeeds. The answer ISO names the guest and is read
once, so it goes with the drives.

## A container from the baseline template

Where the node has no `Baseline template:` line for the
distribution and release, or the one it has is due for a rebuild
(`rules/appliance/proxmox-ve.md` → Guests), build it first
(`references/proxmox-template.md`), and say so in the plan.

```bash
pct create <vmid> local:vztmpl/<archive> --hostname web2.example.com \
  --unprivileged 1 --features nesting=1 --rootfs <storage>:8 \
  --cores 2 --memory 2048 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=192.0.2.22/24,gw=192.0.2.1 \
  --onboot 1
```

Then, in one call:

```bash
pct start <vmid> &&
  timeout 570 pct exec <vmid> -- cloud-init status --wait --long &&
  pct exec <vmid> -- cat /etc/ssh/ssh_host_ed25519_key.pub
```

Chained, so the call's exit status is the first step that failed.

- `<archive>` is the one the `Baseline template:` line names.
  Never the plain `pveam` template: it carries no baseline.
- The container gets the keys the template carries: the Admin
  Keys override at the time it was built. Where the override has
  none, record the chosen key there and build the template with
  it first. A key for this one guest only goes in with
  `--ssh-public-keys <file>`, which reaches root alone, so only
  where the SSH user is root.
- `--unprivileged 1` always: Proxmox VE 8 creates a privileged
  container without it.
- `--features nesting=1`: systemd isolates services with it
  (<https://pve.proxmox.com/pve-docs/chapter-pct.html>).
- `ip=dhcp` instead of an address and gateway where the user
  chose DHCP.

Never `pct clone` for a new server
(`rules/appliance/proxmox-ve.md` → Guests).
