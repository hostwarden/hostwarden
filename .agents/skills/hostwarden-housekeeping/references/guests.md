# Guests

Runs on every housekeeping run, on every host.

## On a host without a `Hypervisor:` line

Run the `@hypervisor` lines of the step-1 probe
(`rules/os-detection.md`) in the first batch; on Windows the
`vmms` line of `rules/os/windows.md` → Version Detection. A
candidate is settled as `rules/os-detection.md` → Hypervisors
says, and a new hypervisor gets its full inventory
(`rules/hypervisors.md`) in this run.

## On a host with one

Run the full inventory (`rules/hypervisors.md` → Inventory) and
report its changes. Then rate:

- a stopped guest without a reason in `guests.md`: **WARN**
- a retired guest past its keep-until date: **INFO**, naming the
  guest and the date
- a running guest that does not start with the host and is not
  HA-managed (`HA` in its entry): **INFO**, it stays down after
  the next reboot
- a running VM whose entry says `no agent`: **INFO**

What the host passed to a guest belongs to that guest's entry,
and what it means for the host to its `Passthrough:` line
(`references/passthrough.md`).

A guest's own health is its own housekeeping run, never part of
this one.
