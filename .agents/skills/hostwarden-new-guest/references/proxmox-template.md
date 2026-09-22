# Proxmox VE Baseline Template

Sources as in `references/proxmox.md`.

Proxmox VE gives a container no cloud-init. The baseline template
is the distribution's `pveam` template with cloud-init and the
baseline packages installed and the rendered container baseline
in a cloud-init drop-in, so every container created from it
applies the baseline at its first boot. It is built once per distribution
release, and again when `rules/appliance/proxmox-ve.md` → Guests
says it is due, or when `pveam available` after `pveam update` no
longer lists the `pveam` template it was built from.

1. The `pveam` template, verified by `pveam` against its signed
   index:

   ```bash
   pveam update
   pveam available --section system
   pveam download local <template>
   ```

2. A build container, with the next free ID and an address the
   user gives or DHCP. It lives only until step 8: no memory
   directory, no entry in `guests.md` or in the session register.
   A container created from the finished template is a guest like
   any other, and a server with all that goes with it.

   ```bash
   pct create <id> local:vztmpl/<template> \
     --hostname hostwarden-build --unprivileged 1 \
     --features nesting=1 --rootfs <storage>:8 --memory 1024 \
     --net0 name=eth0,bridge=vmbr0,ip=dhcp --start 1
   ```

3. Inside it, with the family file's non-interactive package
   manager: an update and upgrade, then `cloud-init`,
   `openssh-server` and the packages of the rendered container
   baseline.
4. The drop-in `/etc/cloud/cloud.cfg.d/90-hostwarden.cfg`, written
   with `pct push <id> <local file> <path>` from a file copied to
   the node; steps 3 to 5 run in one call after that copy:

   ```yaml
   datasource_list: [NoCloud, None]
   network: {config: disabled}
   preserve_hostname: true
   manage_etc_hosts: false
   datasource:
     NoCloud:
       meta-data: |
         instance-id: hostwarden-debian-ct-3
       user-data: |
         #cloud-config
         # hostwarden-baseline debian-ct-3 (2026-09-22)
         …
   ```

   The user-data is `memory/baseline/debian-ct-3.yaml`, indented.
   Proxmox VE owns the network, the hostname and `/etc/hosts` of
   the container, so cloud-init leaves them alone.
   Source: <https://docs.cloud-init.io/en/latest/reference/datasources/nocloud.html>,
   Source 1.
5. `pct exec <id> -- cloud-init clean --logs`, so no container
   inherits a state of the build container.
6. Stop it with `pct shutdown <id>`. The guard asks: show ID,
   name, node and state in the same call first
   (`rules/system-containers.md` → Changes).
7. The archive, into the directory of `local`'s `vztmpl` content:

   ```bash
   vzdump <id> --mode stop --compress zstd \
     --dumpdir /var/lib/vz/template/cache
   ```

   Rename it to `<distribution>-<release>-<version>_<date>.tar.zst`,
   for instance `debian-13-debian-ct-3_20260922.tar.zst`.
8. Delete the build container with `pct destroy <id>`, asked like
   step 6.
9. Write the `Baseline template:` line into the node's memory
   (`rules/appliance/proxmox-ve.md` → Guests), replacing the one
   for an older archive of the same release. Name the older
   archive and offer to remove it
   (`pveam remove local:vztmpl/<file>`).

The archive carries `/etc/vzdump/pct.conf` of the build container
into every container made from it; it describes the build
container and does no harm.
