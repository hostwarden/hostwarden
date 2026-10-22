### Fixed

- **The taboo guard blocks the partition and RAID tools of NetBSD, OpenBSD
  and illumos.** `disklabel`, `mbrlabel`, `fmthard`, `raidctl` and
  `bioctl` rewrote a partition table or a RAID set without the guard
  stopping them. Their write options are now denied, in every permission
  mode, while the display forms stay allowed.
