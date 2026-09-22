# Firewall

The variants below are the family defaults. Where the loaded OS
file's `## Firewall` section names another firewall, its commands
and expectations win, at the same severities.

## Linux

Verify a firewall is installed, active, and the default incoming
policy is deny/drop. An inactive or missing firewall on a Linux
server is **CRITICAL** — aligned with the housekeeping severity.

Three variants count as a firewall: ufw, firewalld, and native
nftables (`nftables.service` loading `/etc/nftables.conf`,
installed on Debian with the unit off). Check them in that
order and judge the host by the first one that is active.
Report **CRITICAL** "No active firewall" only when none of
the three is.

`references/firewall-nftables-docker.md` checks native
nftables and iptables-legacy rules. Run its Docker check
whenever `command -v docker` finds Docker, whatever the
firewall.

### Debian/Ubuntu (ufw)

```bash
ufw status verbose
```

- Not installed or inactive → check native nftables
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

## macOS

Check Application Firewall status:

```bash
/usr/libexec/ApplicationFirewall/socketfilterfw \
  --getglobalstate
```

- Disabled → **WARN** on a server; on a workstation,
  `rules/role/workstation.md` rates it
- Enabled → OK
