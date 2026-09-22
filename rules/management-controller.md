# Management Controller

A server's management controller is a second computer on the
board. It runs while the host is powered down, carries its own
network address, its own accounts and its own firmware, and it
answers when the host's own OS does not. A BMC (Baseboard
Management Controller) is the IPMI kind; Dell calls its own
iDRAC, HPE iLO, Lenovo XClarity Controller, Fujitsu iRMC,
Supermicro ships one without a product name of its own. Intel
AMT is not a BMC but does the same job on a machine that has no
BMC.

Hostwarden records it for three reasons: it is the rescue path
when a firewall or network change cuts SSH, it logs hardware
failures the OS never sees, and it is a second way into the
machine that a security audit has to judge.

Everything here is read-only. Changing a BMC user, its network,
its firmware or its power state is out of scope; those commands
are never run, not even when a check below would be easier with
one.

## When it applies

Only on a host whose memory records `Virtualization: none
(bare metal)` (`rules/os-detection.md` → Virtualization). A
virtual machine and a container have no controller of their own,
and what they would report belongs to the machine underneath.

It applies on Linux and FreeBSD, where the commands below exist.
On macOS there is no controller to find. On a bare-metal Windows
Server, ask the user as the Provider console section says and
record the answer; the probes below do not run there.

A host whose memory already has a `Management:` line is settled.
Read it and go on — the probe runs once per host, not per
session.

## Detection

Needs root (`rules/privilege-escalation.md`). Without it, record
nothing and say the check was skipped; a guess is worse than a
gap.

One bundle, on Linux:

```
dmidecode --type 38,42
ls -d /dev/ipmi0 /dev/ipmi/0 /dev/ipmidev/0 /dev/mei0
lsmod | grep -E '^(ipmi|mei)'
ipmitool mc info
ipmitool lan print
```

On FreeBSD, `kldstat -m ipmi` takes the place of `lsmod`, and
`dmidecode` is a port that is often not installed — its absence
is not an answer either way.

Expect errors: every one of these commands is missing on some
host, and `ipmitool` on a machine without a BMC prints
`Could not open device at /dev/ipmi0 or /dev/ipmi/0 or
/dev/ipmidev/0`. Read what the commands that ran printed.

**The DMI records say whether the board has a controller**, and
they answer even where the driver is not loaded:

- Type 38, `IPMI Device Information`, is the BMC. `Interface
  Type` is how the host reaches it — `KCS (Keyboard Control
  Style)`, `SMIC (Server Management Interface Chip)`, `BT (Block
  Transfer)` or `SSIF (SMBus System Interface)` —
  and `Specification Version` the IPMI version.
- Type 42, `Management Controller Host Interface`, is the
  Redfish-era interface. A host can have both, one, or neither.
- No type 38 and no type 42 on a machine that has a BMC happens:
  some boards describe it nowhere in DMI. A device node or a
  loaded `ipmi_si` still settles it.

**The device node says whether the OS can reach it.** A type 38
record with no `/dev/ipmi*` and no `ipmi_si` in `lsmod` means the
controller is there and the driver is not loaded: the BMC is
still reachable over its own network and through the vendor's web
UI, only not from this host. Record it that way rather than as
absent.

**`ipmitool mc info` names the controller.** `Manufacturer Name`
and `Manufacturer ID` are the vendor, `Firmware Revision` the
BMC's own firmware — not the host's BIOS — and `IPMI Version`
what it speaks. Where `Manufacturer Name` is blank or an IANA
number ipmitool does not resolve, the `sys_vendor` line the
step-1 probe already printed (`rules/os-detection.md` →
Virtualization) names the maker, and the maker names the
controller: Dell is iDRAC, HPE and HP are iLO, Lenovo is the
XClarity Controller on current machines and IMM2 on older ones,
Fujitsu is iRMC, Supermicro's has no name beyond BMC. An unknown
maker is recorded as `BMC`.

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
what they say. AMT answers on TCP 16992 (HTTP), 16993 (HTTPS),
16994 and 16995 (redirection, for serial and KVM).

## Provider console

A rented bare-metal machine often has no controller the tenant
may reach, and a console the provider offers in its panel
instead. Hostwarden never infers that from the hosting: a machine
at a provider may have a full BMC, and a machine in a rack at
home may have none.

So where detection finds no controller, ask **once** per host and
record the answer. Use `AskUserQuestion` where the tool has it,
otherwise the ASCII form:

```
No management controller found on <hostname>.
How do you reach this machine when SSH is gone?

  1. provider console   (a KVM or rescue console in the panel)
  2. physical access    (a crash cart, or someone on site)
  3. nothing            (SSH is the only way in)

[1/2/3]:
```

The answer is recorded with `(user)` and never asked again.

## What to record

One line in `memory/servers/<hostname>/memory.md`
(`rules/server-memory.md`), naming the controller and how the
host reaches it:

```
- Management: iDRAC 9 (BMC, KCS), firmware 7.10
- Management: BMC (KCS), driver not loaded
- Management: Intel AMT (MEI)
- Management: provider console (user)
- Management: none (user)
- Management: unknown (no root)
```

The controller's **address goes in `memory/network.md`**, not in
the host's memory, under a `## Management controllers` heading —
one line per host, with the network it sits on:

```
## Management controllers

- web1.example.com — iDRAC, 198.51.100.50, management VLAN 40
- db1.example.com — BMC, 192.0.2.50, same subnet as the host
```

They belong together because they are one network: a BMC's
address says nothing on its own, and whether the management
network is separate from the production one — which is the
security question below — is only visible when the addresses
stand side by side. A host's own memory stays about the host.

Never record a BMC password, and never a password file's
contents (`rules/secrets.md`). An account **name** from
`ipmitool user list` is not a secret and is recorded where a
finding needs it.

## The rescue path

Where a rule is about to make a change that can cut SSH — a
firewall or network change, a login-shell change, an OS
replacement — the `Management:` line and the address in
`memory/network.md` are what the user is pointed at, by name and
address, instead of being asked whether they have console access.
`Management: none (user)` is the answer that stops the change:
say so, and let the user decide.

## The event log

The BMC's System Event Log records power supply failures, fan
failures, memory errors and thermal events, often before the OS
notices and always when the OS was not running. Housekeeping
reads it on a host whose memory has a `Management:` line naming a
BMC.

```
ipmitool sel info
ipmitool sel elist last 20
```

`sel info` gives `Entries`, `Percent Used` and `Overflow`;
`elist` resolves each entry's sensor name through the SDR, which
`list` does not. `last 20` keeps a log with thousands of entries
out of the conversation.

**The SEL is a history, not a state.** An entry that reads
`Asserted` is a condition that began; the same sensor later
`Deasserted` is that condition ending. A failure from two years
ago whose part was replaced still stands in the log. So a finding
needs an `Asserted` entry with no later `Deasserted` for the same
sensor, and nothing else counts as a fault now.

Record the newest record ID in `memory.md` beside the
`Management:` line, so the next run reports what came after it
rather than the same entries again.

An entry whose timestamp reads `Pre-Init Time-stamp` was written
while the BMC's clock was unset: the event happened, its age is
unknown. Setting that clock is a write and is out of scope.

Severities as in the housekeeping skill's
`references/report-format.md`:

- **CRITICAL:** an asserted and not deasserted failure of a power
  supply, a fan, a processor or a voltage rail, and an
  uncorrectable memory error.
- **WARN:** any other asserted and not deasserted entry,
  correctable memory errors, a thermal event, and a log that
  reports `Overflow` or `Percent Used` at 90 or more — a full SEL
  stops recording, so the next failure is not logged at all.
  Clearing it is a write and is the user's call.
- **INFO:** new entries since the recorded record ID that are
  none of the above, by count.
- **Named as not checked**, never as passing: no root, no
  `ipmitool`, or no device node to reach the BMC through.

## Security

The security audit judges a management controller as a second
machine on the network, because that is what it is. It runs on
a host whose memory has a `Management:` line.

```
ipmitool lan print
ipmitool user list
```

- **On the same network as everything else.** Compare the `IP
  Address` and `Subnet Mask` from `lan print` with the host's own
  address in `memory.md`. One subnet means the BMC is on the
  production network, reachable by everything that reaches the
  host: **WARN**, and the fix is a separate management VLAN, not
  a firewall rule on the host — the BMC's traffic never passes
  through the host's firewall.
- **IPMI over LAN at all.** The IPMI 2.0 RAKP exchange hands a
  salted password hash to anyone who can reach UDP 623, without
  authenticating them first, and that is the specification rather
  than a bug in one vendor's firmware (CVE-2013-4786). Judge it
  by who can reach the port: a BMC on its own management network
  is **INFO**, one on a general network is **WARN**, and one
  reachable from the internet is **CRITICAL**.
- **Cipher suite 0.** In `Cipher Suite Priv Max` each character
  is one cipher suite's maximum privilege, suite 0 first, where
  `X` is unused and `c`, `u`, `o`, `a`, `O` are CALLBACK, USER,
  OPERATOR, ADMIN and OEM. A first character that is not `X`
  leaves suite 0 usable, which accepts any password at that
  privilege (CVE-2013-4782): **CRITICAL**.
- **Factory accounts.** `ipmitool user list` gives each user's
  ID, `Name`, `Callin`, `Link Auth`, `IPMI Msg` and `Channel Priv
  Limit`. An enabled `ADMINISTRATOR` named `root`, `ADMIN`,
  `admin` or `Administrator` is the vendor's factory account:
  **WARN**, named in the report, with the note that whether its
  password was ever changed cannot be read from here and is a
  question for the user.
- **The null user.** User ID 1 with an empty `Name` is IPMI's
  anonymous login. Anything but `NO ACCESS` in its `Channel Priv
  Limit` is **WARN**.
- **Intel AMT on the network.** 16992 and 16994 carry no TLS.
  Where the listening-services check
  (`references/listening-services.md`) or the recorded address
  shows AMT answering on either from a general network, that is
  **WARN**; from the internet, **CRITICAL**.

None of these are fixed from here. Each one is reported with what
it is, and the change is made in the BMC's own UI by the user.
