# Management Controller

A management controller is a second machine on the network, with
its own accounts and its own firmware, and the audit judges it as
one. Its traffic never passes through the host's firewall, so
nothing checked on the host covers it.

Run this on a bare-metal host whose `memory.md` has a
`Management:` line naming a BMC this host can reach. Where there
is no line yet, `rules/management-controller.md` → Detection
settles one first; this is one of the moments that does. A line
that names Intel AMT runs only the AMT check at the end. A line
that names a provider console, physical access or nothing, or a
BMC the host cannot reach, gives `ipmitool` no device node to
open: list the checks under "Skipped".

Everything here is read-only. Nothing is fixed from the host: a
finding names what it is, and the change is made in the
controller's own UI by the user.

## Probe

```
ipmitool lan print | grep -E '^(IP Address|Subnet Mask|Cipher Suite Priv Max)'
ipmitool user list
ipmitool channel getaccess 1
```

**`lan print` is filtered on the host**, as in
`rules/management-controller.md` → Detection and for the same
reason: its full output carries `SNMP Community String` in the
clear, and a secret never reaches the conversation or a report
(`rules/secrets.md`). Where detection ran in this same session,
its filtered output is reused rather than fetched again. `channel getaccess
<channel>` reads every user on that channel; 1 is the usual LAN
channel, and `ipmitool channel info <n>` says what a channel is
where 1 turns out to be something else. It is the read-only
counterpart of `setaccess`, which is a write and is out of
scope.

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
  Limit` — and no enabled or disabled state, which is why
  `channel getaccess` is in the probe: its `Enable Status` is
  `enabled`, `disabled` or `unknown` per user. An account named
  `root`, `ADMIN`, `admin` or `Administrator` with
  `ADMINISTRATOR` in `Channel Priv Limit` is the vendor's factory
  account, and it is a **WARN** only where `Enable Status` is
  `enabled`; `disabled` is the remediated state and is not a
  finding. Name it in the report with the note that whether its
  password was ever changed cannot be read from here and is a
  question for the user. An `Enable Status` of `unknown` is named
  as unknown, never as either.
- **The null user.** User ID 1 with an empty `Name` is IPMI's
  anonymous login. Anything but `NO ACCESS` in its `Channel Priv
  Limit`, with `Enable Status` `enabled`, is **WARN**.
- **Intel AMT on the network.** 16992 and 16994 carry no TLS.
  **`references/listening-services.md` cannot see them**, and
  neither can `ss`, `sockstat` or `lsof`: the Management Engine
  answers these ports below the operating system, so they are in
  no socket table the host can print. AMT has no `lan print`
  either, so there is no recorded address to judge.

  The only probe that settles it runs from the workstation, not
  on the host, and is one TCP connect per port:

  ```
  curl -s -o /dev/null -m 5 -w '%{http_code}\n' \
    http://<host>:16992/
  curl -s -o /dev/null --connect-timeout 5 -m 5 \
    -w 'connect=%{time_connect}\n' telnet://<host>:16994
  ```

  **Both plaintext ports, because either can be on without the
  other.** 16992 is HTTP and answers `401` unauthenticated, so a
  status code means it is there. 16994 is the redirection
  protocol and speaks no HTTP, so it gets a plain TCP connect
  through curl's `telnet://` scheme.

  **Read `connect=`, never curl's exit code**, which cannot tell
  the two failures apart: a port that accepts and then stays
  silent — which is what AMT redirection does — exits `28` when
  `-m` runs out, and so does a filtered port that never completed
  a handshake at all. `time_connect` separates them, because it
  is set only once the TCP handshake is done: above zero means
  something is listening whatever the exit code, and `0.000000`
  means nothing answered. Nothing ever authenticates — AMT
  credentials are out of scope (`rules/secrets.md`).

  Either port answering from the workstation is **WARN**, and
  **CRITICAL** where the host's address is public as
  `references/listening-services.md` defines it. The TLS ports
  16993 and 16995 are not a finding and are not probed; they are
  what the plaintext pair should be replaced by. Where the
  workstation cannot reach the host directly — NAT, a jump host —
  the check is **named as not checked**, never as passing.
