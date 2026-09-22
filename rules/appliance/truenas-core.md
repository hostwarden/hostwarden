# TrueNAS CORE

Base: `rules/os/freebsd.md`

TrueNAS CORE (FreeBSD, 13.x) is end of life: 13.3-U1.2 was its last
release, and TrueNAS names 25.10, the Linux edition, as the
migration target
(<https://www.truenas.com/docs/core/13.3/gettingstarted/corereleasenotes/>).
Hostwarden covers it only far enough to report that. The base file
supplies the vocabulary; like on the Linux edition, the middleware
owns the configuration (`rules/appliance/truenas.md` →
Configuration Model).

## Add: Version Detection

- `midclt call system.version` prints e.g. `TrueNAS-13.3-U1.2`.
- Record in server memory: `Appliance: TrueNAS CORE <version>
  (end of life)`.

## Replace: Package Manager

- `pkg info` and `pkg audit -F` are fine for reading. Never
  `pkg install`, `pkg upgrade` or `pkg bootstrap`: packages belong
  to the TrueNAS image.

## Replace: Automatic Security Updates

- No updates exist any more; see Housekeeping and Audits. Never
  run `freebsd-update`: base and kernel belong to the TrueNAS
  image.

## Replace: Firewall

- TrueNAS CORE manages no host firewall. A missing pf ruleset is
  not a finding, and none is set up by hand.

## Replace: Service Manager

- `service <name> status` is fine for reading. Services are
  started, stopped and enabled in the web UI (Services), never with
  `service`, `sysrc` or `/etc/rc.conf`: the middleware renders
  their configuration.

## Replace: Filesystem

- `zpool status`, `zpool list`, `zfs list` and `bectl list` are fine
  for reading. Pools, datasets, snapshots and boot environments are
  changed in the web UI only, never with `zfs`, `zpool` or `bectl`
  writes. The disk taboos in `AGENTS.md` hold unchanged.

## Replace: Directory Conventions

- `/mnt/<pool>`: the pools. `/etc`, `/usr/local/etc` and
  `/boot/loader.conf` are rendered by the middleware; read only.

## Replace: Networking

- `ifconfig` and `netstat -rn` are fine for reading. Interfaces,
  routes, DNS and the hostname are set in the web UI (Network),
  never in `rc.conf`, `resolv.conf` or with `service netif`.

## Remove: Console Configuration

## Remove: Boot Loader (Lua-based, 14.x+)

## Remove: QEMU/UTM Emulated x86_64 Workarounds

## Remove: Common Pitfalls

## Housekeeping and Audits

- The release is the finding: an operating system without updates.
  Report it first, in every housekeeping report and audit.
- Change nothing unless the user asks for a specific change, and
  then only through the web UI: never `sysrc`, `pkg` or a file the
  middleware renders.
- The migration to the Linux edition is a major upgrade through the
  web UI. Hand it to the user with the migration notes of the
  target release; never start it yourself.
