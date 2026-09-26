---
sidebar_position: 3
description: The network profile, VPNs, and out-of-band access
  Hostwarden records for each host.
---

# A host's network

Each host gets a network profile in its memory, and a way to reach
it when SSH is gone.

## Network profile

The profile records who manages the network configuration, which
stack runs, whether it works, whether DNS agrees, and which way
traffic runs.

- **A traffic-flow section is added where it matters.** A host
  that forwards, bridges guests, does NAT or policy routing gets
  one, and it is read before a NAT or bridge change.
- **Mesh VPN agents are judged one by one** — Tailscale, NetBird,
  ZeroTier, Nebula, WireGuard, OpenVPN, cloudflared and others —
  for which runs, whether it is connected, whether its login is
  about to expire, and what would cut the host off.
- **Every probe is read-only.**
- **The full profile runs when you ask, on onboarding, and when a
  failure points at the network.**

## Firewalls and routers

Onboarding an OPNsense or pfSense firewall or a UniFi OS console,
and every housekeeping run on it, reads its interfaces, VLANs, DHCP
scopes, static routes and WAN interfaces.

- **The read goes over SSH, allow-listed.** It uses the SSH login
  the console already has, printing only allow-listed fields and
  no free text; no API account is needed.
- **UniFi without SSH is the exception.** A UniFi console whose SSH
  is off is read with its View Only user instead.
- **Each site records its uplinks** — the stack, the IPv4 address
  situation, static or dynamic, and the delegated IPv6 prefix.
- **CGNAT is recorded only on your word.** Onboarding asks once per
  site whether the address is static and whose NAT sits upstream.
- **An unlisted gateway gets an offer.** A host whose gateway is
  not in Hostwarden gets an offer to onboard it.

## Out-of-band access

Each host records a `Management:` line: the BMC, Intel AMT or
provider console to use when SSH is gone, or for a guest, the host
it runs on. Housekeeping and the security audit settle it, never
in the middle of an outage. A controller is only ever read; no
user, network, firmware or power setting on it is changed.
