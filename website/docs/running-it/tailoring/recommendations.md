---
sidebar_position: 2
description: Recipes with reasons, never requirements — what a
  decision of yours turns off.
---

# What Hostwarden recommends

Recipes with reasons, never requirements: a decision of yours settles
any of them, and Hostwarden stops proposing it.

## Servers

A decision, for one host or a group, settles any of these
([rules/decisions.md](https://github.com/hostwarden/hostwarden/blob/main/rules/decisions.md)):

- **A firewall that denies incoming traffic by default** — a
  forgotten service stays unreachable from outside.
  [Server baseline](../../features/checks/baseline.md)
- **Automatic security updates** — a known vulnerability gets patched
  before someone finds it first.
  [Server baseline](../../features/checks/baseline.md)
- **Time sync, and the timezone you name** — logs and certificates
  across hosts line up.
  [Server baseline](../../features/checks/baseline.md)
- **SSH by key only, no password login** — a stolen or guessed
  password never gets anyone in.
  [Server baseline](../../features/checks/baseline.md)
- **Trust in your SSH CA, where you run one** — one certificate and
  one revocation list work the same way on every host it covers.
  [Server baseline](../../features/checks/baseline.md)
- **A persistent journal** — the activity check still sees what
  happened before the last reboot.
  [Server baseline](../../features/checks/baseline.md)
- **Storage maintenance on a schedule** — TRIM, RAID checks, ZFS and
  btrfs scrubs, `smartd` catch a failing disk before it fails.
  [Server baseline](../../features/checks/baseline.md)
- **The hypervisor's guest agent, running in every VM** — the host
  can read the guest and shut it down cleanly instead of pulling the
  plug. [Server baseline](../../features/checks/baseline.md)
- **A backup job** — the one thing that survives a mistake.
  [Server baseline](../../features/checks/baseline.md)
- **Mail through a relay where the site's IPv4 address is dynamic, or
  goes through CGNAT or DS-Lite** — receivers commonly reject mail
  sent directly from such an address.
  [A host's network](../../features/hosts/network.md)

## Password logins

For a device that takes no SSH key
([Password logins](../../features/ssh/passwords.md)):

- **A key wherever the host takes one** — Hostwarden sets up a
  password login only for a device that leaves no other way.
- **The password on this machine rather than in a password
  manager** — only Hostwarden's own passwords are in reach. A
  manager is used only through an identity that sees nothing but
  Hostwarden's entries, which is a requirement, not a
  recommendation.
- **A firmware without old SSH algorithms** — Hostwarden adds a
  weak key exchange, host key type or cipher for one host only, and
  says so each time.
- **No management of a DrayTek router from the internet** — the
  web UI facing the WAN is how DrayTek's recent vulnerabilities are
  reached. [Appliances](../../features/systems/appliances.md)

## Guests

- **SSH keys from the first boot, a password only on request** —
  with a key, nothing to guess over the network; without one, a
  generated password on the console instead, except a container from
  the Proxmox VE baseline template, where you set one yourself.
  [New guests](../../features/guests/new-guests.md) · decide
  against: ask for a password when you create the guest; Hostwarden
  never proposes one unasked.

## Software

Say so once to skip any of these for the task at hand, or record a
decision to keep Hostwarden from asking again
([rules/decisions.md](https://github.com/hostwarden/hostwarden/blob/main/rules/decisions.md)):

- **Language runtimes through mise, not the distribution's package**
  — a current version, per user, instead of whatever the distro
  froze at release.
  [Language runtimes and deploy users](../../features/changes/runtimes.md)
- **A community script read as a recipe, on Proxmox VE and Incus**
  — what an application needs is already written down at
  community-scripts.org; Hostwarden offers to read it, and installs
  by its own rules.
  [rules/community-scripts.md](https://github.com/hostwarden/hostwarden/blob/main/rules/community-scripts.md)
- **Long-running services under the host's service manager, not
  `nohup` or `screen`** — systemd, or rc on FreeBSD, handles
  restarts, logging and boot ordering for free.
  [rules/best-practices.md](https://github.com/hostwarden/hostwarden/blob/main/rules/best-practices.md)
- **A reverse proxy with TLS in front of an app, not its port opened
  directly** — the app never has to speak TLS or face the internet
  on its own.
  [rules/best-practices.md](https://github.com/hostwarden/hostwarden/blob/main/rules/best-practices.md)
- **A service bound to `127.0.0.1` when nothing outside the host
  needs it** — only the reverse proxy or the local caller can reach
  it.
  [rules/best-practices.md](https://github.com/hostwarden/hostwarden/blob/main/rules/best-practices.md)

Taboos — commands Hostwarden refuses outright, such as repartitioning
a disk or touching a running sshd's configuration — are not here:
nobody decides against those. They're in
[Hard guardrails](../../safety/guardrails.md).
