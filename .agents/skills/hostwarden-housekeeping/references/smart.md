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
  [ "$type" = scsi ] && type=auto
  smartctl -n standby -H -A -d "$type" "$dev" | grep -E "result:|Health Status:|Device is in|Reallocated_Sector|Current_Pending|Offline_Uncorrectable|Reported_Uncorrect|grown defect list|Media and Data|Percentage Used"
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
  `Media and Data Integrity Errors` and `Percentage Used`.
- **A sleeping disk:** `-n standby` leaves a disk in STANDBY or
  SLEEP alone and prints `Device is in STANDBY mode` (or `SLEEP`)
  in place of the rest.

The strings and the scan behaviour are smartmontools' own
(`ataprint.cpp`, `scsiprint.cpp`, `smartctl.cpp`, `os_linux.cpp`).

## Findings

Severities as in `references/report-format.md`:

- **CRITICAL:** health that is `FAILED!`, or on a SAS or SCSI disk
  anything but `OK`.
- **WARN:** reallocated, pending, offline-uncorrectable or
  reported-uncorrect sectors, a grown defect list above 0, NVMe
  media errors above 0, or NVMe `Percentage Used` at 90 or more.
- **Named as unknown**, never as passing: a disk whose health line
  is `UNKNOWN!`, or that prints neither a health line nor
  `Device is in`. A sleeping disk is named as asleep and read on
  the next run.

Record every WARN count in the host's `memory.md`, by disk, when it
first appears and whenever it changes; a disk with no entry had
none, so the next run can say whether a count grew. No other
threshold applies without a source for it.
