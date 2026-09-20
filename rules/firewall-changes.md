# Firewall Implications of a Service Change

Installing, removing or reconfiguring a network-facing
service changes what the host exposes, whether or not
anyone touches the firewall. Raise it with the user every
time — the change they asked for is the service, not the
exposure that comes with it.

A firewall mistake cuts off SSH. Before any of this, re-read
`AGENTS.md` → Critical Safety Rules: read the ports sshd
listens on and keep every one of them open, and never remove
or block port 22.

## The five steps

1. **Does the service need a port opened at all?** Many do
   not. A database behind an application on the same host,
   or anything a reverse proxy fronts, is better off on a
   Unix socket or bound to `127.0.0.1` with nothing opened
   (`rules/port-check.md`).
2. **Read the current rules before proposing a change.**
   Use the host's own tool — `ufw status verbose`,
   `firewall-cmd --list-all`, `nft list ruleset`,
   `pfctl -sr`. Report what is there, not what you expect.

   Ports published by Docker bypass ufw and firewalld
   entirely: `-p 5432:5432` writes its own `DOCKER` chain
   rule and the host firewall never sees the traffic. Bind
   to `127.0.0.1:5432:5432` instead, or restrict it in
   `DOCKER-USER` (`rules/best-practices.md`).
3. **Ask before changing anything.** Open to everyone, or
   to named addresses? Reachable from the internet, or only
   from the internal network? This is the user's decision,
   and it is not implied by "install nginx".
4. **Recommend a safe default and say why.** Narrowest rule
   that makes the service work: a specific source range
   over `any`, a single port over a range, the service name
   the firewall already knows over a hand-written rule.
5. **Explain the risk in plain language** — what becomes
   reachable, by whom, and what an attacker gets if the
   service has a bad day. This is one of the few places
   where the length ceilings in `AGENTS.md` → Talking to
   Humans do not apply.

## Removing a service

Offer to close the ports that existed only for it. Check
first that nothing else uses them (`rules/port-check.md`) —
a shared port closed with its former owner takes a working
service down with it.

Leaving a rule behind is the quieter mistake and the more
common one: the port stays open for a service that no
longer answers, and the next audit reports an exposure
nobody can explain.

## Always

Use the distribution's own firewall tool, never raw
`iptables` on a host that runs ufw or firewalld — the two
fight, and the surviving rule set is whichever wrote last.

Verify after applying: re-read the rules, and confirm from
a second connection that SSH still answers **before** the
session that made the change ends.

Log the change (`rules/changelog.md`) and record the
resulting exposure in the host's memory file
(`rules/server-memory.md`).
