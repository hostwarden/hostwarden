---
sidebar_position: 3
description: What every server is expected to have, and how to
  bring one up to it.
---

# Server baseline

What every server is expected to have is written down in one
place, `rules/baseline.md`:

- a firewall that denies incoming traffic by default and keeps SSH
  open
- automatic security updates
- time sync
- SSH by key only, and trust in your SSH CA where you run one
- a persistent journal
- storage maintenance on a schedule
- the guest agent in a VM
- a backup

A firewall in front of the host, at the provider or a router, is
recorded and weighed against the ports that still reach it.

## Checking and applying the baseline

Housekeeping and the security audit measure every server against
it. Ask Hostwarden to bring a server up to the baseline —
`/hostwarden-baseline web1` in Claude Code — and it lists what is
missing and applies it one asked step at a time. It never changes
sshd on a running server: for SSH it gives you the change to make.

## Your own additions

Your own additions go into `memory/custom-rules/baseline.md`, as
an override
([Overrides](../../running-it/tailoring/overrides.md)), with
sections for admin keys, the timezone, a mail relay and
monitoring:

```markdown
## Add: Admin Keys
- alice: ssh-ed25519 AAAAC3Nza… alice@example.com

## Add: Timezone
Europe/Berlin

## Add: Monitoring
node_exporter from the distribution's package.
```

Public keys only: passwords and tokens never go there. A
`# baseline` block in a host's own `rules.md` changes it for that
host, and a [decision](../../memory/decisions.md) can settle a
section a host is meant to go without.
