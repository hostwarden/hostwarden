# Coordination

A reboot, a firewall or network change or a restart on one host
reaches other hosts too: its guests, the hosts behind it as a jump
host, the hosts that need a service it runs. This file says how to
find them before the step is taken.

## Blast radius

`bin/hostwarden-impact radius <host>… <kind>` lists them. It reads
memory and `ssh -G` with the standard options, involves no model
and connects to nothing, so it needs neither a connection nor the
pipeline of `rules/first-connection.md`. `rules/multi-host.md` →
Order reads its jump groups from the same script, so the hops are
parsed in one place. Each host's way in is read for the SSH user
`memory/user.md` gives it, and for an alias with a user of its own
also for that one, since a `Match user` block can pick the jump
host; a host with a `Reached as:` line is read at that destination.
A hop counts by the hostname its own `ssh -G` prints, since one
bastion can be written several ways.

`<kind>` is what the step does to the host:

- `reboot`, `network`, `firewall` — the host is **out**: down, or
  cut off. So is everything that goes with it, recursively: its
  guests (`Runs on:`, a cluster's guests for every member, a guest
  its `guests.md` links), the guests reached through it
  (`Mode: via`), the hosts whose way in passes it as a jump host,
  and the hosts reached at a `Reached as:` destination that is it.
  Each host that is out **hits** the hosts whose `Depends on:`
  names it and its `Cluster:` peers; a hit host stays up, and
  nothing goes further from it.
- `restart:<unit>`, as the service manager names the unit — only
  the hosts whose `Depends on:` names the service the unit provides
  (→ Dependencies). A unit on the SSH path (`sshd`, a mesh VPN
  or WireGuard daemon, OpenVPN, strongSwan), the firewall's or the
  network's counts as `network`. A unit the script has no word for
  counts for every `Depends on:` entry that names the host.

Several hosts give one radius, for a step that takes them together.
A name memory does not know, such as a jump host that was never
onboarded, is matched by that name and the hostname its `ssh -G`
prints.

Without `--report` it prints one line per host for scripts, its
format in the script's `--help`. A host whose way in cannot be
read (`rules/access-control.md` → Server Blacklist) is in every
whole radius as `unreadable` rather than left out.

The radius is only as good as memory. A guest never inventoried, a
dependency never recorded, is not in it; including too much costs
a notice, leaving a host out is the incident. A host whose
`Depends on:` line is missing is not a host that depends on
nothing.

### What-if

When the user asks what a step would hit — "what goes down if pve1
reboots?", "wen trifft ein Neustart von unbound auf dns1?" — run the
radius with `--report` and print its output as it stands:

    bin/hostwarden-impact radius --report pve1.example.com reboot

It groups the hosts by relation, gives each its `Role:` and service
lines, lists the guests an inventory names that have no memory of
their own, the hosts only registered and never onboarded, and the
oldest record the radius relied on with the run that refreshes it.
A kernel or firmware update is a `reboot`; a package update names
the units its restarts will hit.

## Dependencies

In `memory.md`, what the host needs from other hosts Hostwarden
knows, one entry per service:

    - Depends on: nas1.example.com (NFS /srv/data), dns1.example.com (resolver)

The host is its memory directory's name. The first word in the
brackets is one of `NFS`, `SMB`, `resolver`, `DB`, `LDAP`, `auth`
or `other`; what follows it is free text that tells the entries
apart. A restart counts for an entry when its unit provides that
word: an NFS or Samba server, a DNS resolver, a database, an LDAP
server, a Kerberos KDC or identity provider. An `other` entry
counts for every restart on that host.

**Detected**, where the read leaves no doubt, by onboarding and by
housekeeping. Each runs one read-only call for it, no root needed,
bundled with its other probes. On Linux:

```bash
awk '$3 ~ /^(nfs4?|cifs|smb3)$/ { print $1, $3, $2 }' /proc/mounts
grep '^nameserver' /etc/resolv.conf
command -v resolvectl >/dev/null && resolvectl dns
```

On FreeBSD and macOS, `mount | grep -E '[(](nfs|smbfs)[,)]'` for
the shares, and the same `nameserver` lines; macOS resolves through
`scutil --dns`, whose `nameserver[…]` lines count instead. A
Windows host gets no detected entries; its come from the user.

- a mounted NFS or SMB share whose server is a known host: the
  source reads `<server>:/<path>` or `//[<user>@]<server>/<share>`,
  and the server is a memory directory's name, an alias of one, or
  a value of its `FQDN:` or `IP:` line. The entry names the mount
  point: `(NFS /srv/data)`;
- a nameserver the host resolves through that is a known host's
  `IP:`: a `nameserver` line, or behind a local stub such as
  systemd-resolved's `127.0.0.53` the servers `resolvectl dns`
  lists. The entry is `(resolver)`. The host itself as its own
  resolver is no entry.

A first label alone, or an address no known host carries, is no
match. Each such run writes these entries anew and keeps the rest.

**From the user**, and only from them: `DB`, `LDAP`, `auth` and
`other`. Record one when the user names it, with what they said
in its words, `(DB orders)`. A connection string or a client
configuration names the server too, but reading one reads the
credentials beside it (`rules/secrets.md`); never take an entry
from there. An entry stays until the user drops it or its host
leaves memory.
