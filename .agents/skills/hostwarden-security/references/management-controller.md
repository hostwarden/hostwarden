# Management Controller

A management controller is a second machine on the network, with
its own accounts and its own firmware, and the audit judges it as
one. Its traffic never passes through the host's firewall, so
nothing checked on the host covers it.

Run this on a host whose `memory.md` has a `Management:` line
naming a BMC this host can reach; a host with no line yet is
settled first by `rules/management-controller.md` → Detection. A
line that names Intel AMT runs only the AMT check at the end. A
line that names a provider console, physical access or nothing,
or a BMC the host cannot reach, gives `ipmitool` no device node
to open: list the checks under "Skipped".

Everything here is read-only. Nothing is fixed from the host: a
finding names what it is, and the change is made in the
controller's own UI by the user.

## Probe

```
ipmitool lan print
ipmitool user list
```

Where detection ran in this same session, its `lan print` output
is reused rather than fetched again.

## Findings

Severities as in `references/report-format.md`. An address is
**public** as `references/listening-services.md` defines it.

- **On the same network as everything else.** Compare the `IP
  Address` and `Subnet Mask` from `lan print` with the host's own
  `IP:` in `memory.md`. One subnet means the BMC is reachable by
  everything that reaches the host: **WARN**, and the fix is a
  separate management VLAN, not a firewall rule on the host.
- **IPMI over LAN at all.** The IPMI 2.0 RAKP exchange hands a
  salted password hash to anyone who can reach UDP 623, without
  authenticating them first, and that is the specification rather
  than a bug in one vendor's firmware (CVE-2013-4786). So judge
  it by who can reach the port: a BMC on a management network of
  its own is **INFO**, one sharing the host's subnet is
  **WARN**, and one on a public address is **CRITICAL**.
- **Cipher suite 0.** In `Cipher Suite Priv Max` each character
  is one cipher suite's maximum privilege, suite 0 first, where
  `X` is unused and `c`, `u`, `o`, `a`, `O` are CALLBACK, USER,
  OPERATOR, ADMIN and OEM. A first character that is not `X`
  leaves suite 0 usable, and suite 0 accepts any password at that
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
  AMT has no `lan print` and so no address of its own in
  `memory/network.md`; `references/listening-services.md` is what
  shows whether either port answers. Answering on an address
  other than loopback is **WARN**; on a public one, **CRITICAL**.
