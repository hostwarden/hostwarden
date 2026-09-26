---
sidebar_position: 6
description: Finds everywhere the old name is used before renaming
  a host.
---

# Renaming a host

```
 ❯ Rename web1.example.com to web2.example.com
```

A rename happens only when you ask, one host at a time. Hostwarden
first lists what the old name reaches:

- the files under `/etc` that name it
- certificates
- cloud-init settings
- memberships keyed by the node name
- the places in memory
- what only you can change, such as DNS, the DHCP reservation,
  backups and monitoring

You add the new DNS name first; Hostwarden then sets the hostname
and `/etc/hosts`, the references you agree to and, for a Proxmox VE
container, its name on the hypervisor, and moves the host's memory
to the new name.

- **The old name stays an alias** until you remove it from DNS.
- **The host key does not change**, and sshd and certificates are
  left alone.
- **History keeps the old name.**

## Renames that are yours

Some renames are yours: Windows and WSL, a Proxmox VE cluster
node, an appliance that is named in its web interface, and a host
joined to a directory. Hostwarden says so and updates memory once
you have renamed it. It never renames an Incus or LXD instance, or
a VM whose cloud-init drive takes its name, on the hypervisor:
that would regenerate its SSH host keys at the next boot.
