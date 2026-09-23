# Configuration Management

A host can be managed by a configuration management tool — wholly,
in some areas, or not at all — and a change made by hand to what
such a tool owns lasts only until its next run. This file is read on
every connection and holds the probe that tells, and when to look
further. The second probe, what a lead means and how the answer is
recorded are in `rules/config-management-leads.md`; what a recorded
tool changes about working on the host is in
`rules/config-management-changes.md`.

## Never push for one

Do not suggest Ansible or any other tool on your own — not after a
repeated change, not after drift in a fleet audit, not in a
recommendation line. When the user asks whether one would pay off,
answer from what memory holds (how many hosts, how many share a
role) and name the cost as well as the gain.

## Detect

Two probes, both in the activity check's call
(`rules/activity-check.md` → What rides in this call), so neither
is an SSH call of its own. One case cannot be: the second
probe fired by a lead the first has just returned, since that
trigger is not known until the call is back. It follows in the next
call, which is another logical step on the same shared connection,
not another connection.

### Directories and agent services — every connection

```
echo "##cm-dirs"; ls -ld /etc/ansible/facts.d /root/.ansible \
  /home/*/.ansible /Users/*/.ansible /etc/puppetlabs \
  /usr/local/etc/puppet /etc/chef /etc/cinc /etc/salt \
  /usr/local/etc/salt /var/cfengine /opt/rudder 2>/dev/null || true
u='ansible|puppet|openvox|chef|cinc|salt[-_](minion|master)'
u="$u|cfengine|cf-(agent|execd|serverd)|rudder|##cm-units unread"
echo "##cm-units"; P=$u
{ { <Enabled services listing>
  } 2>/dev/null || echo "##cm-units unread"; } | grep -Ei "$u" || true
```

Ansible announces itself again through its journal entries
(`rules/activity-check.md` → Ansible runs); an agent of any other
tool announces itself nowhere. An agent installed after the first
connection, and every host whose memory was written before this
check existed, is found here or not at all.

The listing is the loaded OS file's Service Manager → Enabled
services, which is cheap enough for every connection; where the OS
file names none, it is `false`. `P` narrows a listing that looks up
each value on its own, FreeBSD's, to the names that can match. What
is enabled is what manages a host; where the listing also names
what is switched off, an agent installed and disabled shows too,
with its state.

`##cm-units unread` says the service list was not read, which is
not the same as one that held nothing. It stands for both ways that
happens: the OS file names no listing, and the listing failed — a
lister that exits non-zero prints nothing, and its diagnostic goes
to `/dev/null` with everything else, so without the `||` an
unperformed check would read as a clean host. The marker is in `$u`
as well, so that it survives the filter it is printed into. The
`##cm-` prefix keeps these headings apart from the Heinzel probe's
(`rules/heinzel-legacy.md`), which goes into the same call.

### Cron jobs and rendered files — first connection

The second probe is in `rules/config-management-leads.md` → Cron
jobs and rendered files. Run it on the first connection to a host,
the marker search included and whether or not anything else was
found: a host whose files carry a template header and whose agent
runs from elsewhere has nothing else to give away. Run it again
when:

- the activity check shows Ansible runs (`rules/activity-check.md`
  → Ansible runs) and the host's memory has no `Config management:`
  line, or a dismissal older than those runs — a `none` line or a
  `no ansible` entry;
- the probe above finds a directory, unit or service that the host's
  memory does not account for — no `Config management:` line at all,
  one that does not cover that tool, or a dismissal of it that this
  find outdates, by the rule in `rules/config-management-leads.md`
  → Ask once, record. This is the trigger that arrives too late for
  the activity check's call; run it in the next one, before
  reporting the leads;
- a `Config management: unknown` line is there and this session can
  read what the last one could not;
- the user says a tool manages the host.

As a non-root user, `/root`, root's crontab and parts of `/etc` are
unreadable, and `2>/dev/null` makes that look like absence. Run the
probe through `sudo -n sh -c` where sudo is available
(`rules/privilege-escalation.md`). Where it is not, say the check
was partial, and record
`Config management: unknown (privileged paths unread, <date>)` only
where the host has no answer yet, so that a later session with root
looks again. An answer already in memory stands: a partial probe is
a check that did not run, not a finding, and overwriting
`ansible (scope: base, nginx)` with `unknown` would send the next
session to change by hand what that tool owns. Since the first
probe runs on every connection, an unprivileged session on a
long-known host reaches this every time.

Nothing found and nothing left unread: say nothing, record nothing —
unless the user said a tool manages the host. What they said is a
fact the probe cannot overrule: ask the scope question
(`rules/config-management-leads.md` → Ask once, record) and record
the answer, leads or not.

**Not a lead:**

- On the local machine, `~/.ansible/` belongs to the user running
  Ansible from it, not to Ansible managing it.
- An appliance that uses one of these tools as its own mechanism —
  OpenMediaVault renders its system files from Salt states — is
  governed by its appliance file (`rules/appliance/`).
- Windows hosts are read-only (`rules/os/windows.md`), so nothing
  here changes what Hostwarden does there; neither probe is run.
