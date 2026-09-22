# Seed ISO

Where a hypervisor's UI has no field for user-data, cloud-init
reads it from a small ISO whose volume label is `cidata`
(<https://docs.cloud-init.io/en/latest/reference/datasources/nocloud.html>,
Source 2). Build it on the workstation, from an empty directory
under the scratch or temp directory that holds:

- `user-data`: the file for this guest
  (`references/user-data.md` → Rendering it);
- `meta-data`: `instance-id: <name>` and `local-hostname: <name>`;
- `network-config`: only for a static address, as
  `references/libvirt.md` shows.

On Linux:

```bash
genisoimage -output seed.iso -volid cidata -joliet -rock <directory>
```

On macOS, where the label comes out as `CIDATA`, which cloud-init
accepts too:

```bash
hdiutil makehybrid -iso -joliet -default-volume-name cidata \
  -o seed.iso <directory>
```

Either way the files sit at the root of the ISO under their own
lowercase names. The user uploads it where the UI keeps ISOs and
attaches it as the VM's second CD drive; it can be removed after
the first boot.
