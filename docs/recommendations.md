# What Hostwarden recommends

Recipes with reasons, never requirements: a decision of yours settles any
of them, and Hostwarden stops proposing it.

## Servers

A decision, for one host or a group, settles any of these
([rules/decisions.md](../rules/decisions.md)):

- **A firewall that denies incoming traffic by default** — a forgotten
  service stays unreachable from outside.
  [Server baseline](features.md#server-baseline)
- **Automatic security updates** — a known vulnerability gets patched
  before someone finds it first.
  [Server baseline](features.md#server-baseline)
- **Time sync, and the timezone you name** — logs and certificates across
  hosts line up. [Server baseline](features.md#server-baseline)
- **SSH by key only, no password login** — a stolen or guessed password
  never gets anyone in. [Server baseline](features.md#server-baseline)
- **Trust in your SSH CA, where you run one** — one certificate and one
  revocation list work the same way on every host it covers.
  [Server baseline](features.md#server-baseline)
- **A persistent journal** — the activity check still sees what happened
  before the last reboot. [Server baseline](features.md#server-baseline)
- **Storage maintenance on a schedule** — TRIM, RAID checks, ZFS and btrfs
  scrubs, `smartd` catch a failing disk before it fails.
  [Server baseline](features.md#server-baseline)
- **The hypervisor's guest agent, running in every VM** — the host can
  read the guest and shut it down cleanly instead of pulling the plug.
  [Server baseline](features.md#server-baseline)
- **A backup job** — the one thing that survives a mistake.
  [Server baseline](features.md#server-baseline)

## Guests

- **SSH keys from the first boot, a password only on request** — with a
  key, nothing to guess over the network; without one, a generated
  password on the console instead, except a container from the Proxmox
  VE baseline template, where you set one yourself.
  [New guests](features.md#new-guests) · decide against: ask for a
  password when you create the guest; Hostwarden never proposes one
  unasked.

## Software

Say so once to skip any of these for the task at hand, or record a
decision to keep Hostwarden from asking again
([rules/decisions.md](../rules/decisions.md)):

- **Language runtimes through mise, not the distribution's package** — a
  current version, per user, instead of whatever the distro froze at
  release.
  [Language runtimes and deploy users](features.md#language-runtimes-and-deploy-users)
- **Long-running services under the host's service manager, not `nohup`
  or `screen`** — systemd, or rc on FreeBSD, handles restarts, logging
  and boot ordering for free. [rules/best-practices.md](../rules/best-practices.md)
- **A reverse proxy with TLS in front of an app, not its port opened
  directly** — the app never has to speak TLS or face the internet on its
  own. [rules/best-practices.md](../rules/best-practices.md)
- **A service bound to `127.0.0.1` when nothing outside the host needs
  it** — only the reverse proxy or the local caller can reach it.
  [rules/best-practices.md](../rules/best-practices.md)

Taboos — commands Hostwarden refuses outright, such as repartitioning a
disk or touching a running sshd's configuration — are not here: nobody
decides against those. They're in [Safety and guardrails](safety.md).
