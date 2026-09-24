### Added

- **Onboarding records everything a host's memory holds.** Besides the
  full probe and the baseline measurement it records the USB devices,
  what a hypervisor passes to its guests, the disks, the accounts and
  sudo model, the backup, the container registries to trust and, where
  it has root, the management controller, so no housekeeping run is
  needed right after it. The report ends with what keeps the record
  current and offers to schedule housekeeping.
- **A registered guest finishes its onboarding on its first own
  login.** Whatever you asked for, the guest is recorded read-only
  first, and its baseline gaps follow the task as one offer. New
  guests are onboarded as they are created.
- **Housekeeping's records go stale after 90 days.** A host's memory
  carries `Onboarded:` and `Housekeeping:` dates; an answer that rests
  on an older record says so, and the fleet audit lists the hosts whose
  records are stale and those never onboarded.
