---
sidebar_position: 1
description: The OS families, appliances, platforms, and roles
  Hostwarden tells apart.
---

# Supported systems

The OS families Hostwarden supports are listed in the
[README](https://github.com/hostwarden/hostwarden#supported-distributions).

## Three layers on top of a family

On top of a family, three more layers can apply to a host: an
appliance, a platform and a role. Hostwarden detects each, records
it in the host's memory, and tells you; say so when it is wrong.

- An **appliance** runs its own updater, configuration and
  firewall, often on top of an OS family — see
  [Appliances](appliances.md).
- A **platform** is what the OS runs inside when something outside
  owns part of the machine, such as WSL — see
  [WSL and workstations](workstations.md).
- A **role** says what the machine is expected to have, such as a
  workstation instead of a server — see
  [WSL and workstations](workstations.md).
