# Mail DNS

What a domain's DNS says about the mail a host sends or receives,
read from the workstation and rated. It reads and recommends; it
writes no record. A zone is changed as `rules/dns.md` → Writing
says, and only where `memory/dns.md` allows it, and the records of
a mail domain are proposed there in The proposal's form, never
written from this file.

## When

- **Housekeeping on a host whose MTA takes mail from the internet or
  sends it to the internet directly**
  (`.agents/skills/hostwarden-housekeeping/references/service-checks.md` → Mail
  server; the MTAs are those
  of `rules/service-class-check.md` → Service Classes). A host whose MTA only
  relays root's mail through a smarthost
  (`rules/baseline.md` → Mail Relay) has no mail domain of its own:
  only the smarthost's sender policy matters, and that is the
  user's.
- **The user asks** why mail is rejected or lands in spam, or
  whether a domain is set up for mail.
- **A domain the user holds sends or receives no mail** and they
  ask what it should publish (Parked and non-mail domains).
- **A mail server is set up or renamed:** the records it needs are
  The proposal of `rules/dns.md`, and this file's checks run after
  the user says they are in place.

## What is read

Everything is a query from the workstation (`rules/dns.md` → Checks
→ Where they run), never a login on the mail server, except two
facts only the host knows: the name its MTA gives in HELO and the
DKIM selectors it signs with. `dig` is the tool; without it
(`command -v dig`) the checks are `not checkable`. A lookup that gets no answer
at all is `not checkable`, never a missing record: the probes below go
through one function that prints the answer's `status`, as
`rules/dns.md` → Verify does, and `status none` when no server
replied. `status NOERROR` with no record after it, and `status NXDOMAIN`,
are a missing record; `SERVFAIL`, `REFUSED` and any other status
are `not checkable`.

**From the host,** read-only, one call. Never a whole file: DKIM
private keys sit beside the files below (`rules/secrets.md`):

```bash
postconf -xh myhostname smtp_helo_name 2>/dev/null
exim -bP primary_hostname 2>/dev/null
grep -rhE '^[[:space:]]*helo_data' /etc/exim4 /etc/exim \
  /usr/local/etc/exim 2>/dev/null
for d in /etc /usr/local/etc; do
  grep -hE '^[[:space:]]*(Selector|Domain|KeyTable|SigningTable)' \
    "$d/opendkim.conf" 2>/dev/null
  awk '{ split($2, a, ":"); print a[1], a[2] }' \
    "$d/opendkim/KeyTable" 2>/dev/null
  grep -hE '^[[:space:]]*(selector|domain)[[:space:]]*=' \
    "$d/rspamd/local.d/dkim_signing.conf" 2>/dev/null
done
```

A `KeyTable` line holds `name domain:selector:path`: the awk prints
the domain and the selector and leaves the path out. A `KeyTable`
line in `opendkim.conf` that names another file is read the same
way. The HELO name is `smtp_helo_name` where Postfix sets it,
otherwise `myhostname`; where Exim's `helo_data` shows, that is the
name, and a transport that sets none uses `primary_hostname`.
A host whose signing is done by
another product, or by the provider, gets its selectors from the
user; a selector nobody names is not guessed, and the DKIM check
reports `not checkable`.

**The names:** `D` is the domain of the `From:` addresses the user
names, where DMARC is looked up. SPF applies to the envelope sender
domain `E` and DKIM to the signing domain `G`, the `d=` of the
selector: each is `D` unless the user, or the host's signing
configuration, says otherwise. `H` is the HELO name, and `A` each public address
the host sends from (`rules/network-probe.md` → Public DNS view lists them).

## The checks

Probes for one domain and one host; run every query once, in one
call:

```bash
q() { t=$1; shift
  dig +time=3 +tries=1 +noall +comments +answer -t "$t" "$@" |
  awk -v t="$t" '
    /status:/ { s = $6; sub(/,/, "", s); print "status", s }
    $4 == t { v = $5; for (i = 6; i <= NF; i++) v = v " " $i
      if (t == "TXT") gsub(/" "/, "", v); print v }
    END { if (s == "") print "status none" }'; }
D=example.com E=$D G=$D H=mail.example.com S=selector1 A=192.0.2.25
q TXT "$E" | tr -d '"'
q TXT "_dmarc.$D" | tr -d '"'
q TXT "$S._domainkey.$G" | tr -d '" ' | tee /dev/stderr |
  sed -n 's/.*p=\([^;]*\).*/\1/p' | openssl base64 -d -A |
  openssl pkey -pubin -inform DER -noout -text | head -1
q MX "$D"
q MX "$D" | awk '$1 ~ /^[0-9]+$/ { print $2 }' | while read -r m; do
  case $m in -*|.|*[!A-Za-z0-9._-]*) continue ;; esac
  echo "@$m"; q A "$m"; q AAAA "$m"; q CNAME "$m"; q TLSA "_25._tcp.$m"
done
q TXT "_mta-sts.$D" | tr -d '"'
curl -fsS --max-time 10 "https://mta-sts.$D/.well-known/mta-sts.txt"
q TXT "_smtp._tls.$D" | tr -d '"'
q PTR -x "$A"
q A "$H"; q AAAA "$H"
dig +dnssec +time=3 +tries=1 +noall +comments MX "$D" |
  awk '/flags:/ { f = 1; print } END { if (!f) print "flags none" }'
```

`q` joins a TXT record that `dig` prints as several quoted strings
with no separator, as RFC 7208 §3.3 and RFC 6376 read it. A selector
that publishes a CNAME (Microsoft 365) gives
the target's record, which `q` prints too. The DKIM line shows the
record (to the terminal's error stream, so the pipe carries only
the key) and then `Public-Key: (2048 bit)` for an RSA key, nothing
for a revoked one, `p=` empty. A record with `k=ed25519` (RFC 8463)
holds a raw 32-byte key that `openssl` cannot read: it is a valid
record with no length to rate. `openssl` on macOS is LibreSSL and
prints the same line. `ad` among the DNSSEC flags means the answer
validated. The DMARC record is also looked up at the parent, one
label up at a time, when `D` is a subdomain with none of its own
(RFC 9989 walks the tree): a policy found there counts.

### Severity

**WARN**

- **SPF** (RFC 7208): a sending domain with no `v=spf1` record,
  with more than one (a permanent error, RFC 7208 §4.5, so SPF
  fails for every mail), or whose record ends in `+all`, `all` or `?all`, or has
  neither an
  `all` nor a `redirect=` (RFC 7208 §6.1). `~all` and `-all` are no finding
  (Strict values).
- **DKIM** (RFC 6376): the selector the MTA signs with has no
  record, or its `p=` is empty (a revoked key: nothing it signs
  verifies), or a key under 1024 bits (RFC 8301 §3.2 makes 1024 the
  least a signer may use).
- **DMARC** (RFC 9989, which obsoletes RFC 7489): a sending domain
  with no `_dmarc` record.
- **Reverse DNS:** the PTR of a sending address missing, a
  provider's pool name (`rules/network-probe.md` → Public DNS
  view), or not the HELO name, and the HELO name's A or AAAA not
  holding the address back. A receiver commonly rejects a sender
  without this forward-confirmed reverse DNS. A PTR is the address
  owner's to set: usually the provider, not the zone.
- **MX:** a target that is a CNAME (RFC 2181 §10.3), or has no A
  or AAAA record.
- **CAA** where the host's TLS certificate names a domain that has
  one: the host's certificate issuer not in the set (RFC 8659 §4).
  The CAA lookup climbs from the name to its parents until a record
  is found, so the probe asks each parent in turn, in the call that
  defined `q`:

  ```bash
  n=mail.example.com
  while [ -n "$n" ]; do
    r=$(q CAA "$n")
    case $r in
      *'status NOERROR'*|*'status NXDOMAIN'*) ;;
      *) echo "$n not checkable"; break ;;
    esac
    r=$(printf '%s\n' "$r" | grep -v '^status')
    [ -n "$r" ] && { echo "$n $r"; break; }
    case $n in *.*) n=${n#*.} ;; *) break ;; esac
  done
  ```

  No CAA anywhere is INFO. How a certificate and its issuer are read
  is `rules/service-class-check.md`'s and the housekeeping SSL
  check's, not repeated here.

**INFO**

- **DKIM** key of 1024 bits: recommend 2048.
- **DMARC** `p=none`, or no `rua=` address, so no report ever says
  who else sends as the domain. A new sending domain starts at
  `p=none` on purpose; it stays INFO for as long as the user keeps
  it.
- **MTA-STS** (RFC 8461) on a domain that receives mail: no
  `_mta-sts` TXT record, or one whose policy file does not answer
  at `https://mta-sts.<domain>/.well-known/mta-sts.txt`; the policy
  `mode` is `testing` or `none`. **TLS reporting** (RFC 8460): no
  `_smtp._tls` record with a `rua=`.
- **DANE** (RFC 7672): no TLSA record at `_25._tcp.<mx>` on a
  domain whose zone is signed.
- **DNSSEC:** the zone is unsigned, or the parent has no DS
  (`rules/dns.md` → Checks gives the comparison).
- **CAA** absent, as above.

Everything else, such as an SPF record of exactly the sending
services and nothing more, is read and reported only on request.

### Strict values

DMARC `p=reject`, SPF `-all` against `~all`, DNSSEC and MTA-STS
`enforce` are recommendations and the user's choice, never a
failure of the baseline (`rules/baseline.md`): each has a cost
that depends on who else sends as the domain and what the mail
provider supports.

- **SPF.** `~all` is the recommendation for a domain that sends:
  `-all` makes a receiver that rejects during the SMTP dialogue
  refuse a forwarded message before DMARC sees the DKIM signature
  that would have passed (RFC 9989 §7.1 describes the problem).
  Both are valid.
- **DMARC.** `p=reject` with `sp=reject` and `np=reject` is the
  target for a sending domain, reached from `p=none` once the
  aggregate reports show every legitimate sender aligned. Hostwarden
  never reads the reports as proof of that: it recommends the step
  and the user decides. `pct`, `rf` and `ri` are not part of the
  current standard (RFC 9989), and Hostwarden does not propose them.
- **A strict value the user declines** is a decision
  (`rules/decisions.md`), and the finding is then `DECIDED`
  (`rules/decisions.md` → Rating findings). Ask once, as that file
  says; a run with nobody to ask reports the finding and asks
  nothing.

### Findings

One line per finding in the housekeeping report's form
(`.agents/skills/hostwarden-housekeeping/references/report-format.md`),
each with its recommendation, the record spelled out as a proposal
(`rules/dns.md` → The proposal):

```text
WARN      example.com has no DMARC record. Proposed, in the zone:
  _dmarc.example.com.  TXT  "v=DMARC1; p=none; rua=mailto:dmarc@example.com"
```

The proposal names the zone, and where `memory/dns.md` has no line
for it, the name space is asked about first as `rules/dns.md` →
The inventory says. The reports' address is the user's: Hostwarden
proposes none of its own.

## Parked and non-mail domains

A domain the user holds that sends no mail, receives none, and
serves nothing is a sender anyone can forge unless it says so. The
recommendation, as a proposal for the user, never a change:

```text
example.net.  MX   0 .
example.net.  TXT  "v=spf1 -all"
_dmarc.example.net.  TXT  "v=DMARC1; p=reject; sp=reject; np=reject"
*.example.net.  MX   0 .
*.example.net.  TXT  "v=spf1 -all"
```

- The null MX (`MX 0 .`, RFC 7505) says the domain accepts no mail.
  A domain that sends mail takes a real MX instead, even where
  nobody reads what arrives: replies and bounces need somewhere
  to go, and RFC 7505 tells senders not to deliver to a null MX.
- `v=spf1 -all` (RFC 7208) is the one place the hard fail costs
  nothing, since the domain forwards nothing.
- The wildcards cover names that do not exist; a subdomain that
  exists carries its own records. No DKIM record, and no MTA-STS or
  TLS-reporting record, which a domain without mail never serves.
- A domain with no host behind it also needs no address record, and
  a CAA `0 issue ";"` (RFC 8659 §4.2) asks every CA not to issue
  for it. A domain that does serve a site or a mail server names
  the CAs that issue for it instead.

The checks above run on such a domain too: an MX that is not a
null MX, an SPF that allows senders, or a missing DMARC is `INFO`
here, the user having said the domain sends no mail. Without that
word the domain is the sending domain above and is rated as one.

## Never

- A DKIM private key read, printed or copied (`rules/secrets.md`);
  only the public record and its length are looked at.
- A guess at a selector, or at a sender the user did not name.
