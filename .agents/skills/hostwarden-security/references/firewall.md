# Firewall

The variants below are the family defaults. Where the loaded OS
file's `## Firewall` section names another firewall, its commands
and expectations win, at the same severities. Every finding that
the host does not filter a family — no firewall, or the IPv6 gap
— is then weighed by `rules/baseline.md` → Filtering in front of
the host.

Each firewall below also says where it leaves IPv6 open; the
IPv6 section at the end weighs that gap.

## Linux

Verify a firewall is installed, active, and the default incoming
policy is deny/drop. An inactive or missing firewall on a Linux
server is **CRITICAL** — aligned with the housekeeping severity.

Four variants count as a firewall: ufw, firewalld, native
nftables (`nftables.service` loading `/etc/nftables.conf`,
installed on Debian with the unit off), and iptables without a
manager on the legacy backend. Check them in that order and
judge the host by the first one that is active. Report
**CRITICAL** "No active firewall" only when none of the four
is.

`references/firewall-nftables-docker.md` checks the variants
after ufw and firewalld. Run its Docker check whenever
`command -v docker` finds Docker, whatever the firewall.

### Debian/Ubuntu (ufw)

```bash
ufw status verbose
grep '^IPV6=' /etc/default/ufw
```

- Not installed or inactive → check native nftables
- `IPV6=no` → ufw writes no IPv6 rules. Before calling that the
  IPv6 gap, read the effective rules as
  `references/firewall-nftables-docker.md` → Native nftables
  does: another ruleset may carry a default-deny input chain for
  IPv6
- Active but default incoming is not `deny` → **WARN** "Firewall
  default incoming policy is not deny"
- Active and default deny → OK

### RHEL/Fedora/SUSE (firewalld)

```bash
firewall-cmd --state
firewall-cmd --get-default-zone
```

Then check the default zone's target:

```bash
firewall-cmd --zone=<zone> --get-target
```

- Not running → check native nftables
- Zone target is `ACCEPT` → **WARN** "Default zone target is
  ACCEPT (allows all incoming)"
- Zone target is `default` (reject/drop) → OK

A zone applies to IPv4 and IPv6 alike, so firewalld has no IPv6
gap of its own.

## FreeBSD

Run the status probe in `rules/os/freebsd.md` → Firewall, which
also says how each firewall's default reads. Then, as root, the
rules of whichever runs in full — `pfctl -s rules`, `ipfstat -i`
or `ipfw list` — for the ports passed in; the default comes from
them as the OS file describes. Unprivileged, report the status
lines and list the rules as skipped.

- None running → **CRITICAL** "No active firewall"
- Running but its `_enable` variable is not `YES` → **WARN**: the
  firewall is gone after the next reboot
- No default block of incoming traffic → **WARN** "Firewall
  default incoming policy is not deny"
- Otherwise OK; list the ports passed in for review

**On a firewall appliance** (OPNsense, pfSense) the vendor owns the
ruleset and its default deny; skip the default check above. Read
`pfctl -s rules` once and report every rule that passes traffic in
on a WAN interface from any source, **WARN** when one reaches SSH
or the web UI. The appliance file names where those rules live in
its web UI.

IPv6: a pf rule without `inet` or `inet6` covers both families,
so the gap is a default block that carries `inet` with none for
IPv6 beside it. In ipfw, the unconditional rule that sets the
default counts for IPv6 only when it names `ip`, not `ip4`.
IPFilter keeps its IPv6 rules apart: report INFO "IPv6 coverage
not checked" rather than guess.

## macOS

Check Application Firewall status:

```bash
/usr/libexec/ApplicationFirewall/socketfilterfw \
  --getglobalstate
```

- Disabled → **WARN** on a server; on a workstation,
  `rules/role/workstation.md` rates it
- Enabled → OK

The Application Firewall filters per application, whatever the
family: no IPv6 gap.

## IPv6

A firewall that filters only IPv4 leaves every service open over
IPv6. Take the addresses in the same batch as the firewall status;
no root needed:

```bash
ip -6 -o addr show 2>/dev/null
```

On FreeBSD, `ifconfig -a inet6`. Where a section above found a
gap:

- No address but `::1` → IPv6 is off; no finding.
- A public address, as `references/listening-services.md` defines
  it, on an interface that is not a container or VM bridge
  (`docker0`, `br-*`, `veth*`, `virbr*`, `lxcbr*`, `cni*`,
  `podman*`) → **CRITICAL** "Firewall does not filter IPv6"
- Otherwise the local network still reaches the host over IPv6 →
  **WARN** "Firewall does not filter IPv6 (local network)"
