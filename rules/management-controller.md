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

Every host gets a `Management:` line, because every host can
have its SSH cut. What fills it differs: on bare metal the probe
below, and on a virtual machine or a container the machine
underneath, since a guest has no controller of its own. Detection
and the two audit checks are bare metal only, on a host whose
`Virtualization:` line records it with or without the `(user)`
marker (`rules/os-detection.md` → Virtualization).

The line is settled at first need, never in the onboarding
pipeline: the probe needs root, and
`rules/privilege-escalation.md` escalates only for a privileged
action that is actually wanted. Three moments need it — the
rescue path, the housekeeping event log and the security audit —
and each is already privileged.

A host whose memory has a `Management:` line is settled; read it
and go on. The one exception is `unknown (no root)`, which is
probed again by the first session that has root.

Where the appliance file loaded for this host names its own way
to the controller, that way wins **for what it actually covers**,
and no further. On an XCP-ng dom0 that is the sensor read:
`rules/appliance/xcp-ng.md` → Housekeeping and Audits runs
`get_all_sensors` through a XAPI plugin, so hardware health comes
from there and not from `ipmitool`. It reads no controller
identity, no firmware revision and no LAN address, and it writes
no memory — so Detection below still runs on such a host, and the
`Management:` line and the address still come from it. An
appliance file that covers those too would displace them; none
does today.

## Detection

Needs root (`rules/privilege-escalation.md`). One bundle, on
Linux:

```
dmidecode --type 38,42
cat /sys/class/dmi/id/sys_vendor
ls -d /dev/ipmi0 /dev/ipmi/0 /dev/ipmidev/0 /dev/mei0
lsmod | grep -E '^(ipmi|mei)'
ipmitool mc info
ipmitool lan print
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
loaded `ipmi_si` still settles it.

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
the host's: `IP Address Source` (`Static Address`, `DHCP
Address`, `BIOS or system software`), `IP Address`, `Subnet
Mask`, `Default Gateway IP`, `MAC Address` and `802.1q VLAN ID`.
An address of `0.0.0.0` or a source that never got one means the
BMC has no network — it is then reachable from this host and from
a crash cart, and from nowhere else.

**Intel AMT, only where there is no BMC.** `/dev/mei0` and a
loaded `mei_me` are the Management Engine interface, which most
Intel machines have; AMT is the vPro feature on top of it and may
be unprovisioned. So the node alone says the interface exists,
never that AMT is on. `amt-info` from the `amtterm` package says
which, where it is installed; otherwise ask the user and record
what they say. AMT answers on TCP 16992 and 16994 in the clear,
and on 16993 and 16995 with TLS.

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
- Management: Intel AMT, reachable from the host
- Management: node1.example.com console (Proxmox VE guest)
- Management: provider console (user)
- Management: unknown (no root)
```

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

- web1.example.com — iDRAC, 198.51.100.50, VLAN 40
- db1.example.com — BMC, 192.0.2.50
```

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

Read the `Management:` line. Where the host has none, settle it
first:

- **Bare metal** — run Detection above. It gives the controller,
  and `lan print` gives the address for `memory/network.md`.
- **A virtual machine or a container** — the console belongs to
  the machine underneath, and only an explicit guest-to-node fact
  names it. `Virtualization:` gives the kind of hypervisor, never
  which machine it is: `kvm` is not a host. `Reached as:` is no
  use either — `rules/server-memory.md` defines it as the SSH
  destination of that same instance, so taking it for the node
  names the guest as its own rescue console, which is no route at
  all once SSH is gone. What counts is a line that says which
  node or provider runs this guest: a `## Management
  controllers` row for it, or a note in `memory/network.md`.
  Where there is none, ask.
- **Nothing settled it** — a bare-metal host with no address, a
  guest whose node nothing names, a `Virtualization: unknown`
  machine. Ask the Provider console question above, adding the
  host's own hypervisor or provider as an option where one is
  known, and record the answer with `(user)`.

Then name the way back in: the controller from `memory.md`, its
address from `memory/network.md`. Where the line is
`none (user)`, say that there is no way back in, and let the user
decide whether the change still happens. Never report a way back
in that no address or recorded fact supports — a rescue path that
turns out not to exist is found out after SSH is already gone
(`rules/verify-before-reporting.md`).
