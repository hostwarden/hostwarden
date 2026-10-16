# Intrusion Prevention — Linux, FreeBSD and macOS

A ban on repeated failed logins protects a service that takes a
password. Against a key-only sshd it only thins the log, and its
counting can lock out the user's own automation
(`rules/ssh-connections.md`). So the rating follows what takes a
password from the internet, not whether a ban tool runs.

## Services that take a password

- sshd, where `references/ssh.md` raised "SSH accepts passwords";
- each listener `references/listening-services.md` marks as a
  password service.

Such a service is **public** when it listens on an address that
`references/listening-services.md` → Evaluation calls public, or
on all addresses of a host that has one, and neither the host's
firewall nor the `Upstream firewall:` line closes that way in
(`rules/baseline.md` → Filtering in front of the host, read for
its port); or when the host's memory names a port forwarding from
the internet to it. Behind NAT without such a line, say that a
forwarding is not visible from the host.

## What protects one

A ban tool covers a service only where the probe shows all three:
it runs, it reads the log that service writes now, and its bans
reach a filter that is enforcing. A tool the probe shows to miss
one of them — no jail for the service, a log it no longer writes,
an action for a firewall that is off — covers nothing. One whose
coverage the probe could not read is rated apart (→ Rating).

- **fail2ban** — a jail for the service whose `File list:` names a
  file the service still writes (modified within the last day) or
  whose `Journal matches:` name its unit or its process: the terms
  joined by `+` are alternatives, so `_COMM=sshd` matches sshd
  whose unit is `ssh.service`, as on Debian and Ubuntu. Its
  actions, as `fail2ban-client get <jail> actions` names them,
  write to the firewall `references/firewall.md` found active:
  `ufw` only where ufw is active, `firewallcmd*` only with
  firewalld, `nftables*` or `iptables*` where that backend's rules
  are enforced, `pf` only with the `anchor "f2b/*"` rule in
  pf's loaded ruleset, `bsd-ipfw` with ipfw.
- **CrowdSec** — an acquisition source in the `Acquisition
  Metrics` of `cscli metrics` for the service's log or unit with
  lines read, an installed collection for the service, and a
  bouncer that has pulled decisions recently and blocks the
  service's port: a firewall bouncer for every service, a web
  server's or proxy's bouncer only for the web interfaces behind
  it.
- **sshguard** — the services its `LOGREADER` or `FILES` read, and
  a `BACKEND` for the firewall found active. Its pf backend blocks
  only where pf's loaded ruleset blocks from the `<sshguard>` table, its
  iptables backend only where INPUT jumps to the `sshguard` chain;
  its nftables and firewalld backends bring their own.
- **blocklistd** on FreeBSD (`blacklistd` up to 14.x) — sshd, where
  `sshd -T` shows `useblocklist yes` (`useblacklist` on older
  releases, off by default) and pf's loaded ruleset carries the
  `anchor "blocklistd/*"` rule (`blacklistd/*` for `blacklistd`).
  With ipfw, its coverage is not readable.

- **An appliance's own lockout** — pfSense's sshguard and
  OPNsense's `sshlockout`, for SSH and the web interface, where the
  loaded ruleset blocks from their table (`rules/appliance/pfsense.md`,
  `rules/appliance/opnsense.md`).

sshd's `PerSourcePenalties` does not count. On pf, the loaded
ruleset, `pfctl -sr` and `pfctl -sA`, is what counts, not
`/etc/pf.conf`: an appliance generates its own, and a host's
`pf_rules` or an `include` can name another file.

## Probe

One call, as root, beside the checks of the first batch. On a host
without systemd, the loaded OS file's Service Manager → Service
status replaces the first line; on FreeBSD,
`service <name> onestatus` for `blocklistd`, `blacklistd`,
`sshguard`, `fail2ban` and `crowdsec`. On macOS a ban tool comes
from Homebrew, and its fail2ban runs as `Python`, so the line
matches the command line and prints only the tool's name:

```bash
ps -axo command= | grep -oE '[f]ail2ban-server|[s]shguard|[c]rowdsec' | sort -u
```

Every variant ends with `true`: a tool that is not there, or a
`grep` that finds nothing, is a result, and a call that exits
non-zero cancels the calls beside it. `fc` is the firewall-listing
filter `rules/secrets.md` gives, set at the top of the call: rule
comments and labels print as `...`, and the `sed` after `cscli`
cuts an acquisition source's URL, which can carry credentials, to
its scheme.

```bash
systemctl is-active fail2ban crowdsec sshguard 2>/dev/null
for j in $(fail2ban-client status 2>/dev/null \
    | sed -n 's/.*Jail list:[[:space:]]*//p' | tr ',' ' '); do
  fail2ban-client status "$j"; fail2ban-client get "$j" actions
done 2>/dev/null
grep -rnE '^[[:space:]]*(\[|mode[[:space:]]*=)' /etc/fail2ban/jail.local \
  /etc/fail2ban/jail.d/ 2>/dev/null
{ cscli metrics show acquisition 2>/dev/null || cscli metrics 2>/dev/null; } \
  | sed -E 's#([a-z]+://)[^ |]*#\1...#g'
cscli bouncers list 2>/dev/null
cscli collections list 2>/dev/null
grep -hE '^(BACKEND|LOGREADER|FILES)=' /etc/sshguard/sshguard.conf \
  /etc/sshguard.conf /usr/local/etc/sshguard.conf 2>/dev/null
pfctl -sr 2>/dev/null | sed -E "${fc:?}" \
  | grep -E 'b(lock|lack)listd|f2b|sshguard|sshlockout'
pfctl -sA 2>/dev/null
iptables -S INPUT 2>/dev/null | sed -E "${fc:?}" | grep -w sshguard
true
```

For each file a jail's `File list:` names, `ls -l` gives its
modification time; add it to the same call where the list is
already known, or run it in the next one.

## Rating

Rate once `references/ssh.md`, `references/listening-services.md`
and `references/firewall.md` have run.

- A public service that takes a password, and nothing covers it
  → **WARN** "No brute-force protection for <service> (<port>),
  public with password login", naming a tool that runs and what it
  misses. sshd's line adds that key-only login is the better fix
  (`rules/baseline.md` → SSH Login). The tool to install, and how,
  is the family file's Brute-Force Protection section.
- A tool runs whose coverage the probe could not read — without
  root (`references/unprivileged.md`), or blocklistd with ipfw →
  **INFO** "<tool> runs, coverage not readable", with the reads
  under Skipped.
- Otherwise → OK, naming what covers each password service or why
  it is not public, or "no password login from the internet"; a
  ban tool that runs is named on the line.
- A `mode` line above in the `[sshd]` section reading `aggressive`
  or `ddos`, or an `sshd-ddos` jail in the jail list, as Alpine's
  package enables → **INFO** "fail2ban counts SSH connections that
  never log in" (`rules/ssh-connections.md`).

A ban tool is a recommendation, not part of the baseline: a
decision settles the WARN (`rules/decisions.md`).
