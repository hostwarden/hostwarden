---
sidebar_position: 3
description: How a WSL instance or a workstation is treated
  differently from a server.
---

# WSL and workstations

A platform is what the OS runs inside when something outside owns
part of a machine; a role says what the machine is expected to
have.

## WSL

Under
[WSL](https://github.com/hostwarden/hostwarden/blob/main/rules/platform/wsl.md),
Windows owns the kernel, the firewall, name resolution and the
instance's lifetime, so Hostwarden reads them and leaves them
alone. It records WSL 1 or 2, the networking mode and what runs as
PID 1, gets root through `wsl.exe -u root` where interop allows,
and judges the firewall from the Windows side.

## Workstations

A Mac, a WSL instance and the machine Hostwarden runs on are
inferred to be
[workstations](https://github.com/hostwarden/hostwarden/blob/main/rules/role/workstation.md)
and held to workstation expectations instead of the server
baseline: automatic reboots off, a firewall judged by what
listens, your home directory and your own tools left to you. A
workstation that is offline is skipped, not reported unreachable.
