# SMART

How housekeeping reads a disk's SMART state with `smartctl`. Run it
only when an appliance's `## Housekeeping and Audits` section sends
you here; a virtual machine has no disk to read, so the Linux
baseline does not.

## Probe

Every disk in one call:

```
smartctl --scan | while read -r dev x type rest; do
  echo "== $dev $type"
  smartctl -n standby -H -A -d "$type" "$dev" | grep -E "result:|Health Status:|Device is in|Reallocated_Sector|Current_Pending|Offline_Uncorrectable|Reported_Uncorrect|grown defect list|Media and Data|Percentage Used"
done
```

`--scan` prints each disk as `<device> -d <type> # …`. The type
is passed on so a disk behind a USB bridge is still read, and it
goes in the label: behind a RAID controller several disks share
one device node (`/dev/bus/0 -d megaraid,0`, `megaraid,1`, …).

A caller that names its own disk list loops over that list with
this `smartctl … | grep -E` line verbatim, leaving out `-d`. Its
file says where the list comes from.

## Reading the output

- **Health** is one line, and which one depends on the disk:
  - SATA and NVMe: `SMART overall-health self-assessment test
    result:`, then `PASSED`, `FAILED!` or `UNKNOWN!`.
  - SAS and other SCSI disks: `SMART Health Status: OK`, or the
    failure in its place followed by `[asc=…, ascq=…]`. A SCSI
    disk without an Informational Exceptions mode page prints no
    health line at all.
- **Counts:** on SATA the ATA attributes, whose raw value is the
  last column. A SAS disk has no ATA attributes and prints
  `Elements in grown defect list: <n>` instead. NVMe prints
  `Media and Data Integrity Errors` and `Percentage Used`.
- **A sleeping disk:** `-n standby` leaves a disk in STANDBY or
  SLEEP alone and prints `Device is in STANDBY mode` (or `SLEEP`)
  in place of the rest; it is read on the next run.
- **Unknown:** a disk that prints neither a health line nor
  `Device is in` has unknown health.

The strings are smartmontools' own (`ataprint.cpp`,
`scsiprint.cpp`, `smartctl.cpp`).

## Findings

Severities as in `references/report-format.md`:

- **CRITICAL:** health that is not `PASSED` or `OK`.
- **WARN:** reallocated, pending, offline-uncorrectable or
  reported-uncorrect sectors, a grown defect list above 0, NVMe
  media errors above 0, or NVMe `Percentage Used` at 90 or more.
- **Named as unknown**, never as passing: a disk whose health the
  probe could not read. A sleeping disk is named as asleep.

Record each disk's counts in the host's `memory.md` on the first
run and whenever they change, so the next run can say whether they
grew. No other threshold applies without a source for it.
