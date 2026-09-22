# Management Controller

A server's management controller is a second computer on the
board. It runs while the host is powered down, carries its own
network address, its own accounts and its own firmware, and it
answers when the host's own OS does not. A BMC is the IPMI kind,
under whatever name its vendor gives it; Intel AMT does the same
job on a machine that has no BMC.

Everything here is read-only. Changing a BMC user, its network,
its firmware or its power state is out of scope, and so is
clearing its event log; those commands are never run, not even
where a check below would be easier with one.

## When it applies

Every host gets a `Management:` line, because every host can have
its SSH cut. Detection below and the two audit checks are bare
metal only (`rules/os-detection.md` → Virtualization); on a
virtual machine or a container the line is filled by The rescue
path instead, since a guest has no controller of its own.

The line is settled at first need, never in the onboarding
pipeline: the probe needs root, and
`rules/privilege-escalation.md` escalates only for a privileged
action that is actually wanted. Each moment that needs it is
already privileged, and each names itself.

**Settle it before it is needed, not during.** A housekeeping run
and a security audit both settle the line on every host they
touch, guests included, even where the checks that follow are
bare metal only — that is one clause in each and it costs a
question the user answers at leisure. Leaving it to The rescue
path means asking while a change is about to cut SSH or after it
already has, which is the one moment this file exists to avoid.

**A run with nobody at the keyboard never asks.** A scheduled
housekeeping run (`references/scheduled.md` in the
`hostwarden-housekeeping` skill) records what the probe alone
gives it and, where that is nothing, `unknown (not asked)`. It
does not wait: an unanswered question idles until the job times
out, and then the report and the mail do not arrive either. The
line is named in the report as unsettled, and the next
interactive session asks.

A host whose memory has a `Management:` line is settled; read it
and go on. Two values are not settled and are taken up again:
`unknown (no root)` by the first session that has root, and
`unknown (not asked)` by the first that has a human to ask.

On an XCP-ng dom0, hardware health comes from the XAPI plugin
`rules/appliance/xcp-ng.md` → Housekeeping and Audits names, not
from `ipmitool`. That covers sensors only: Detection below still
runs there, and the `Management:` line still comes from it.

## Detection

Needs root (`rules/privilege-escalation.md`). One bundle, on
Linux:

```
dmidecode --type 38,42
cat /sys/class/dmi/id/sys_vendor
ls -d /dev/ipmi0 /dev/ipmi/0 /dev/ipmidev/0 /dev/mei0
lsmod | grep -E '^(ipmi|mei)'
grep -l 046b /sys/bus/usb/devices/*/idVendor
grep -l Virtual /sys/bus/usb/devices/*/product
ipmitool mc info
ipmitool lan print | grep -E \
  '^(IP Address|Subnet Mask|802\.1q VLAN ID|Cipher Suite Priv Max)'
```

On FreeBSD, `kldstat -m ipmi` takes the place of `lsmod`, there
is no `/sys/class/dmi`, and `dmidecode` is a port that is often
not installed — its absence is not an answer either way; the
vendor comes from `ipmitool mc info` alone there. On macOS there
is no controller to find. On a bare-metal Windows Server the
probe does not run; ask as Provider console below says and record
the answer.

Expect errors: every one of these commands is missing on some
host, and `ipmitool` on a machine without a BMC prints
`Could not open device at /dev/ipmi0 or /dev/ipmi/0 or
/dev/ipmidev/0`.

**The DMI records say whether the board has a controller**, and
they answer even where the driver is not loaded. Type 38,
`IPMI Device Information`, is the BMC; its `Interface Type` is
how the host reaches it — `KCS (Keyboard Control Style)`,
`SMIC (Server Management Interface Chip)`, `BT (Block Transfer)`
or `SSIF (SMBus System Interface)`. Type 42,
`Management Controller Host Interface`, is the Redfish-era
interface; a host can have both, one or neither, and a host with
only type 42 is recorded as a BMC all the same. Some boards
describe their BMC in neither record, so a device node or a
loaded `ipmi_si` still settles it — and so does a third signal,
below.

**A virtual USB device is the third signal**, and often the only
one on a board with no DMI records: a BMC presents a keyboard,
mouse or CD-ROM to the host for its remote console, from vendor
`046b` (American Megatrends) or with `Virtual` in the product
string. The two `grep` lines above are that check — they read
sysfs, need no root and no `lsusb`, print the matching device's
path and nothing at all when there is no match. On FreeBSD
`usbconfig list` shows the same devices.

Naming the signal is not enough on its own: nothing else in a
session enumerates USB, since the housekeeping inventory that
also sees these devices
(`.agents/skills/hostwarden-housekeeping/references/usb-devices.md`
→ Reading the output) does not run during a security audit, and
leaves the BMC out of `USB:` for this file's line to record.

**The device node says whether the OS can reach it.** A type 38
record with no `/dev/ipmi*` and no `ipmi_si` in `lsmod` means the
controller is there and the driver is not loaded: it is still
reachable over its own network and through the vendor's web UI,
only not from this host. Record it that way rather than as
absent.

**`ipmitool mc info` names the controller.** `Manufacturer Name`
and `Manufacturer ID` are the vendor, `Firmware Revision` the
BMC's own firmware — not the host's BIOS — and `IPMI Version`
what it speaks. Where `Manufacturer Name` is blank or an IANA
number ipmitool does not resolve, `sys_vendor` names the maker
and the maker names the controller: Dell is iDRAC, HPE and HP are
iLO, Lenovo is the XClarity Controller on current machines and
IMM2 on older ones, Fujitsu is iRMC, Supermicro's has no name
beyond BMC. An unknown maker is recorded as `BMC`.

**`ipmitool lan print` is the BMC's own network**, and it is not
the host's. The filter keeps `IP Address Source` (`Static
Address`, `DHCP Address`, `BIOS or system software`), `IP
Address`, `Subnet Mask`, `802.1q VLAN ID` and `Cipher Suite Priv
Max` — the last for the security audit, which runs this same
filter rather than one of its own, so that either caller's output
serves the other.

**It is filtered on the host, never read whole.** The full output
carries `SNMP Community String` in the clear, and a secret never
reaches the conversation, a report or memory
(`rules/secrets.md`). The filter is an allow-list of the fields
actually read rather than a `grep -v` of that one field: a
deny-list would keep whatever the next firmware adds.
An address of `0.0.0.0` or a source that never got one means the
BMC has no network — it is then reachable from this host and from
a crash cart, and from nowhere else.

**Intel AMT, only where there is no BMC.** `/dev/mei0` and a
loaded `mei_me` are the Management Engine interface, which most
Intel machines have; AMT is the vPro feature on top of it and may
be unprovisioned. So the node alone says the interface exists,
never that AMT is on. `amt-info` from the `amtterm` package says
which, where it is installed; otherwise ask the user.

AMT has no `lan print`, so its address is never read from the
host: it either shares the host's address or has a static one of
its own. Ask for it in the same exchange — the user is already
being asked — and record it as What to record says.

## Provider console

A rented bare-metal machine often has no controller the tenant
may reach, and a console the provider offers in its panel
instead. Hostwarden never infers that from the hosting: a machine
at a provider may have a full BMC, and a machine in a rack at
home may have none.

So where detection finds no controller, ask **once** per host and
record the answer. Interview format as in `rules/ssh-user.md` →
Interview format:

```
No management controller found on <hostname>.
How do you reach this machine when SSH is gone?

  1. provider console   (a KVM or rescue console in the panel)
  2. physical access    (a crash cart, or someone on site)
  3. nothing            (SSH is the only way in)

[1/2/3]:
```

The three answers record as `provider console (user)`,
`physical access (user)` and `none (user)`, and the question is
never asked again.

## What to record

One line in `memory/servers/<hostname>/memory.md`
(`rules/server-memory.md`), naming the controller and whether
this host can reach it:

```
- Management: iDRAC (BMC), reachable from the host
- Management: BMC, not reachable from the host (driver not loaded)
- Management: Intel AMT
- Management: guest (Runs on)
- Management: provider console (user)
- Management: unknown (no root)
- Management: unknown (not asked)
```

A guest's line is `guest (Runs on)` and never names the node. The
node is read from `Runs on:` each time it is needed, because that
line moves when the guest does (`rules/hypervisors.md` → Changes
Between Connections) — a node copied into `Management:` would
still point at the old one after a migration, which is a way back
in to a machine the guest has left.

`reachable from the host` is what the two audit checks depend
on: without it there is no device node for `ipmitool` to open,
and both checks list themselves as not checked rather than
running a command that cannot work.

It also decides whether there is an **address**. `lan print` is
the only thing that reads one, so a controller the host cannot
reach has none, and neither has one whose `IP Address` is
`0.0.0.0`. That a BMC exists is not evidence that its network is
configured, routed, or reachable from where the user sits — the
LAN channel may be switched off entirely. Record the controller,
record no address, and let the rescue path ask.

The controller's **address goes in `memory/network.md`**, under a
`## Management controllers` heading — one line per host, the
address and the VLAN it sits on and nothing judged:

```
## Management controllers

- web1.example.com — iDRAC, 198.51.100.50/24, VLAN 40
- db1.example.com — BMC, 192.0.2.50/24
- app1.example.com — Intel AMT, 198.51.100.60/24 (user)
```

The address carries its prefix length, from `Subnet Mask`, so
that the security audit can compare it with the host's own `IP:`
without asking the BMC again. An AMT row is marked `(user)`,
since nothing on the host reads that address.

A host whose memory directory goes away, or whose `Management:`
line is probed again, has its row here removed or rewritten in
the same edit; a row nothing owns any more is worse than none.

Never record a BMC password, and never a password file's
contents (`rules/secrets.md`). An account **name** from
`ipmitool user list` is not a secret and is recorded where a
finding needs it.

## The rescue path

`rules/ssh-safety-net.md`, `rules/ssh-unreachable.md` and the
OS-replacement path in the `hostwarden-os-install` skill send you
here when a change is about to cut SSH, or already has. Name the
way back in; never ask the user whether they have one.

**Nothing here is ever called verified.** Every way back in is
named to the user as theirs to confirm before the change, and
nothing Hostwarden checks turns that into a green light. The
checks below are what can be learnt from here, and each proves
less than "this works": a port that answers says something is
listening, not that it is the controller; a login to a node says
the account can log in, not that it can open this guest's
console; a provider console may be switched off for the account.
What proves a way back in is the user using it, so the user is
the one who confirms it, with what the checks found in front of
them.

### Finding the way in

Read the `Management:` line. A line that names a controller but
has no row in `memory/network.md` — a BMC the host cannot reach,
one whose `IP Address` was `0.0.0.0` — names no way in: treat it
as Nothing settled it below. Where the host has no line at all,
settle it first:

- **Bare metal** — run Detection above while SSH still works. It
  gives the controller, and `lan print` its current address. Where
  a row already exists and SSH still works, read `lan print` again
  rather than trusting the row: a DHCP lease or a network change
  moves the address, and the old one may now belong to something
  else. Where SSH is already gone, no probe can run, what memory
  holds is all there is, and the user is told it may be out of
  date.
- **A virtual machine or a container** — the console belongs to
  the machine underneath, and `Runs on:` names it
  (`rules/hypervisors.md` → Linking Guest and Host). That rule
  owns the question too: where the guest has no `Runs on:` line,
  it settles one, and this file asks nothing of its own.
  - `Runs on: pve1.example.com (VM 101)` — the node's console,
    and behind it the node's own `Management:` line for when the
    node is what went down;
  - `Runs on: Hetzner (cloud)` — the provider's console;
  - `Runs on: <name> (user, not managed)` — that machine;
  - `Runs on: unknown (user)`, or `unknown (left <host> <date>)`
    for a guest that has disappeared from its host — no way back
    in is known, which is the same answer as `none (user)` below.

  Read `Runs on:` as it stands now, never a node remembered from
  an earlier session: it moves when the guest does. And never
  read the node off anything else. `Virtualization:` gives the
  kind of hypervisor, never which machine it is: `kvm` is not a
  host. `Reached as:` is the SSH destination of the guest itself
  (`rules/server-memory.md`), so taking it for the node names the
  guest as its own rescue console, which is no route at all once
  SSH is gone.
- **Nothing settled it** — a bare-metal host with no address, or
  a `Virtualization: unknown` machine. Ask the Provider console
  question above and record the answer with `(user)`.

### What to tell the user

Name the way back in that the above gave — for bare metal the
controller from `memory.md` with its address from
`memory/network.md`, for a guest the node or provider from
`Runs on:` — and ask the user to confirm they can use it before
the change goes ahead. Where the line is `none (user)`, say that
there is no way back in, and let the user decide whether the
change still happens.

For a controller's address, reach for it once from the
workstation first — port 443 for a BMC's web interface, 16993 for
Intel AMT's — and put the result in front of the user as they
confirm:

```
curl -s -o /dev/null --noproxy '*' --connect-timeout 5 -m 5 \
  -w 'connect=%{time_connect}\n' telnet://<address>:<port>
```

`connect=` above zero means something at that address answered
from here, `0.000000` that nothing did. Say which, as a fact about
the address, never as a verdict on the way back in: an answer does
not show it is the controller, and no answer may only mean the
user reaches it over a VPN or a jump host. `--noproxy '*'` keeps
the fact honest — with `ALL_PROXY` or `HTTP_PROXY` set, curl
connects to the proxy instead, and an unroutable address then
reads as answering.
