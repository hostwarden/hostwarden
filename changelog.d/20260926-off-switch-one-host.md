### Changed

- **The taboo guard's off switch names the one host an OS install
  writes on.** Its value is the name of the host the disk writes run
  on, the hypervisor for a guest's disk, or `localhost` for this
  machine; the guard stays on for every other host and for any
  command whose destination it cannot read, and a value of `1` is
  refused with a message naming the new form.
