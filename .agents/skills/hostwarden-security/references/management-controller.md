# Management Controller

A management controller is a second machine on the network, with
its own accounts and its own firmware, and the audit judges it as
one. Its traffic never passes through the host's firewall, so
nothing checked on the host covers it.

Settle the `Management:` line first where `memory.md` has none,
or has one `rules/management-controller.md` → When it applies
names as unsettled — on any host, guest included, as that section
says, since an audit is a calm moment and the rescue path is not.

The **checks** below then follow the line: a BMC this host can
reach runs all of them, a line naming Intel AMT runs only the AMT
check at the end, and anything else gives `ipmitool` no device
node to open and is **named as not checked**.

Everything here is read-only. Nothing is fixed from the host: a
finding names what it is, and the change is made in the
controller's own UI by the user.

## Probe

```
ipmitool lan print | grep -E \
  '^(IP Address|Subnet Mask|802\.1q VLAN ID|Cipher Suite Priv Max)'
ipmitool user list
ipmitool channel getaccess 1 | grep -E \
  '^(User ID|User Name|Privilege Level|Enable Status)'
```

Both filters run on the host. `lan print`'s full output carries
`SNMP Community String` in the clear, and a secret never reaches
the conversation or a report (`rules/secrets.md`); `getaccess`
prints a nine-line block per user slot, of which four lines are
read. The `lan print` filter is character for character the one
in `rules/management-controller.md` → Detection, so where
detection ran in this same session its output is reused instead —
two different filters would have dropped `Cipher Suite Priv Max`
and left the cipher-suite finding below with nothing to read. `channel getaccess
<channel>` reads every user on that channel; 1 is the usual LAN
channel, and `ipmitool channel info <n>` says what a channel is
where 1 turns out to be something else. It is the read-only
counterpart of `setaccess`, which is a write and is out of
scope.

## Findings

Severities as in `references/report-format.md`. An address is
**public** as `references/listening-services.md` defines it.

- **On the same network as everything else.** Compare the
  controller's recorded address and prefix with the host's own
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
  either, so its address is never read from the host.

  **Probe AMT's own address, which is not always the host's**:
  it is the host's `## Management controllers` row in
  `memory/network.md` (`rules/management-controller.md` → What to
  record). Where nobody knows it, the check is **named as not
  checked** — probing the SSH hostname instead would report no
  exposure while AMT answers somewhere else, which is worse than
  no answer.

  The probe runs from the workstation, not on the host, and is
  one TCP connect per port against that address:

  ```
  curl -s -o /dev/null --noproxy '*' -m 5 \
    -w '%{http_code}\n' http://<amt-address>:16992/
  curl -s -o /dev/null --noproxy '*' --connect-timeout 5 -m 5 \
    -w 'connect=%{time_connect}\n' telnet://<amt-address>:16994
  ```

  `--noproxy '*'` on both: with a proxy in the environment, curl
  connects to the proxy, which answers with a status code of its
  own and a nonzero `time_connect` — an AMT port that does not
  exist would then read as exposed.

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
  **CRITICAL** where that address is public as
  `references/listening-services.md` defines it. The TLS ports
  16993 and 16995 are not a finding and are not probed; they are
  what the plaintext pair should be replaced by. Where the
  workstation cannot reach the host directly — NAT, a jump host —
  the check is **named as not checked**, never as passing.
