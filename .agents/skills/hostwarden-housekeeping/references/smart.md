# SMART

How housekeeping reads a disk's SMART state with `smartctl`, as
root. It runs on every bare-metal Linux and FreeBSD host, in a VM
for the disks its host passes through, and wherever an appliance's
`## Housekeeping and Audits` section sends you here. A VM has no
other disk of its own to read (`rules/storage-inventory.md` →
Detection).

Where `smartctl` is missing, the disks' health is named as not
checked, never as passing: **INFO**, smartmontools is not
installed. Whether the distribution installs it is the family
file's Storage Maintenance section; installing it is a change the
user approves.

## The Disk List

In the same call, the disk list of `rules/storage-inventory.md` →
Disks. Compare it with `storage.md` by serial and report each
difference in one line. A disk that is no longer listed is
handled as a guest that is not listed (`rules/hypervisors.md` →
Changes Between Connections): its line keeps its counts and gains
`not listed <date>`, and it stays **WARN** until the user says it
was removed — or it is one the host's `Passthrough:` line gives to
a VM, which takes it out of the host's view. Change the section
only where something differs; a host without a `storage.md` gets
one now.

## Probe

Every disk in one call:

```
smartctl --scan | while read -r dev x type rest; do
  echo "== $dev $type"
  [ "$type" = scsi ] && type=auto
  smartctl -n standby -i -H -A -d "$type" "$dev" | grep -E "Serial Number|Firmware Version|result:|Health Status:|Device is in|Reallocated_Sector|Current_Pending|Offline_Uncorrectable|Reported_Uncorrect|grown defect list|Critical Warning|Available Spare|Media and Data|Percentage Used"
done
```

`--scan` prints each disk as `<device> -d <type> # …` without
opening it, so on Linux every `/dev/sd*` disk is `scsi` there, SATA
disks included. `-d scsi` turns off the detection that reads a
SATA disk through its SCSI layer or a USB bridge, and the ATA
attributes with it, so the loop hands those disks to `-d auto`.
Any other type is passed on and goes in the label: behind a RAID
controller several disks share one device node
(`/dev/bus/0 -d megaraid,0`, `megaraid,1`, …).

A caller that names its own disk list loops over that list with
this `smartctl … | grep -E` line verbatim, leaving out `-d`.

In a VM, the probe covers only the disks its host passes to it,
recognised by the serials the host's `Passthrough:` line or its
disk record gives, or behind the passed-through controller. Its
virtual disks have no SMART and are left out, not named as
unknown.

## Reading the output

- **Health** is one line, and which one depends on the disk:
  - SATA and NVMe: `SMART overall-health self-assessment test
    result:`, then `PASSED`, `FAILED!` or `UNKNOWN!`.
  - SAS and other SCSI disks: `SMART Health Status: OK`, or the
    failure in its place followed by `[asc=…, ascq=…]`, or nothing
    when the disk has no Informational Exceptions mode page.
- **Counts:** on SATA the ATA attributes, whose raw value is the
  last column. A SAS disk has no ATA attributes and prints
  `Elements in grown defect list: <n>` instead. NVMe prints
  `Critical Warning` (a bit field, `0x00` when nothing is wrong),
  `Available Spare` beside `Available Spare Threshold`,
  `Media and Data Integrity Errors` and `Percentage Used`
  ([nvmeprint.cpp](https://github.com/smartmontools/smartmontools/blob/main/src/nvmeprint.cpp)).
- **Identity:** `Serial Number` matches the disk to its line in
  `storage.md`, and `Firmware Version` fills in what `lsblk`
  leaves empty for NVMe.
- **A sleeping disk:** `-n standby` leaves an ATA or SCSI disk in
  STANDBY or SLEEP alone and prints `Device is in STANDBY mode`
  (or `SLEEP`) in place of the rest. It does not apply to NVMe.

The strings and the scan behaviour are smartmontools' own
(`ataprint.cpp`, `scsiprint.cpp`, `smartctl.cpp`, `os_linux.cpp`).

## Findings

Severities as in `references/report-format.md`:

- **CRITICAL:** health that is `FAILED!`, on a SAS or SCSI disk
  anything but `OK`, or an NVMe `Critical Warning` other than
  `0x00`.
- **WARN:** reallocated, pending, offline-uncorrectable or
  reported-uncorrect sectors, a grown defect list above 0, NVMe
  media errors above 0, NVMe `Available Spare` below its
  threshold, or NVMe `Percentage Used` at 90 or more.
- **Named as unknown**, never as passing: a disk whose health line
  is `UNKNOWN!`, or that prints neither a health line nor
  `Device is in`. A sleeping disk is named as asleep, its health
  as not checked; waking it is the user's call.

Record every WARN count on the disk's line in `storage.md`
(`rules/storage-inventory.md` → Disks), when it first appears and
whenever it changes; a disk with no count had none, so the next
run can say whether a count grew. No other threshold applies
without a source for it.

## Between Runs

Housekeeping reads SMART when someone runs it; `smartd` reads it
all the time and mails when a disk degrades. In the same call, on
bare metal only: `smartd` does not start in a VM, so a VM's
passed-through disks are read by housekeeping alone.

- **Linux:** whether `smartd` runs, in the form the family
  file's Service Manager gives (`systemctl is-active
  smartd.service` with systemd, `rc-service smartd status` on
  Alpine), and its configuration:

  ```sh
  grep -sE '^(DEFAULT|DEVICESCAN|/dev)' /etc/smartd.conf \
    /etc/smartmontools/smartd.conf
  ```

- **FreeBSD:** `sysrc -n smartd_enable`, and
  `sysrc -f /etc/periodic.conf -n daily_status_smart_devices`
  for the daily report (`rules/os/freebsd.md` → Storage
  Maintenance).

**INFO** where `smartctl` exists and nothing reads SMART between
runs: a disk that starts failing is noticed at the next
housekeeping at the earliest. `smartd` mails root, so whether
anyone reads it is `rules/baseline.md` → Mail Relay. Say whether
the configuration schedules self-tests (`-s`), which catch
surface errors that no attribute shows yet
([smartd.conf](https://github.com/smartmontools/smartmontools/blob/main/src/smartd.conf)).
Turning `smartd` on is a gap in `rules/baseline.md` → Storage
Maintenance, handled as `references/storage-maintenance.md` →
What Is Missing says; the family file names the unit.
