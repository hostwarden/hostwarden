---
sidebar_position: 5
description: Compares key policies across every server Hostwarden
  knows about.
---

# Fleet audit

Compare key policies across every server Hostwarden knows about.

```
 ❯ Run a fleet audit
 ❯ Vergleiche die Policies auf allen Servern
```

## What it compares

Hostwarden probes each host in `memory/machines/` for
unattended-upgrades, sshd's effective config and SSH CA trust,
firewall posture, MTA, the network stack and resolver, time sync,
auto-reboot behaviour and needrestart's restart mode, mesh VPNs and
their SSH servers, accounts and sudo rules and, on Ubuntu, Pro/ESM
coverage.

- **The result is a side-by-side table** that highlights where
  servers disagree, with sections for drift, warnings, [what you
  decided](../../memory/decisions.md), and the hosts whose memory
  is stale or never onboarded.
- **Alpine, FreeBSD and macOS have probes of their own**; a setting
  a family does not have reads `n/a`, not drift.
- **An appliance is compared only with its own kind.**
- **Windows hosts are skipped.**

## How it runs

In Claude Code each host gets its own subagent and returns one
comparison row, which keeps the raw output out of the
conversation; elsewhere it probes one host after another. Each
guest stands right after the hypervisor its `Runs on:` line names,
whether it has SSH of its own or is reached through that
hypervisor; a VM in the cloud or on a host Hostwarden does not
manage stands on its own. In a container, the time sync, the
uptime and a kernel waiting for a reboot belong to its host and
read `n/a`; the host's own column shows them where the host is
audited.

It makes no configuration changes on any host — it only writes one
audit-trail line to each journal. Use it after fixing a config bug
on one server to find which others carry the same bug, or as a
periodic consistency check.
