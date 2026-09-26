# Naming Scheme

Whether the fleet's hostnames and domains follow a scheme, what
that scheme is, and how a name is checked against it. Hostwarden
settles this early, records it, applies it to every new host from
then on, and never forces an existing host to move.

The store is `memory/naming.md`, shared like the rest of the
workspace (`rules/machine-memory.md` → Personal versus shared),
created on first need. **A name is never judged whole.** Once a
scheme is recorded, its hostname label and its domain are each
checked in their own mechanical way (Checking a name, below), never
a judgement call: two runs of the same check must agree.

## The store

```markdown
# Naming scheme

## Servers
- Applies to: Role: server
- Adopted: user, 2026-09-24 (decision: Naming scheme: Servers,
  decisions/naming.md)
- Hostname: <site>-<role><nn>
- Regex: ^(muc|fsn)-[a-z]+[0-9]{2}$
- Domain: corp.example.com, one for every site
- Role: lowercase letters, what the host does (web, db, pve, nas)
- Index: two digits, the next free per site and role, from 01
- Exempt: nas1.corp.example.com — vendor appliance, named in its
  UI (user, 2026-09-24)
```

- **Every scheme is a `## <name>` block, even the only one.** The
  name is the user's own label for the group (`Servers`,
  `Site fsn`). A second scheme is then a second block, and the
  first never has to be restructured when it arrives.
- **The block's first line is `Applies to:`,** in the selector
  syntax of `rules/decisions.md` → Where it goes — `all`,
  `<Field>: <value>`, or `hosts <name>, <name>, …` — always written,
  `all` included.
- **`Adopted:`** who and when, and the decision that settled it
  (below), naming this block by its heading.
- **`Hostname:`** the template, written with the token vocabulary
  below inside `<>` and every literal character — hyphens, dots —
  as itself.
- **`Regex:`** built from the template and shown to the user before
  it is recorded (Detection and The best-practice proposal below).
  It anchors both ends (`^…$`) and matches the first label only,
  never the domain, which `Domain:` covers instead (Checking a name
  below). Everything that checks a name —
  `hostwarden-new-guest`, the fleet audit, the onboarding report —
  applies both mechanically, so no two runs judge the same name
  differently.
- **`Domain:`** the domain model (Domain models below), with one
  value per site where the model needs one.
- **A line per token the template uses that needs more than its
  name** — `Role:`, `Index:` above — spelling out what its values
  mean or how the next one is picked. A `site` token needs no such
  line: its codes live with the sites they name, in
  `rules/network-topology.md` → A site's code. A `literal` or
  `free` token needs no such line either.
- **`Exempt:`** one line per host that deliberately stays off this
  block's scheme, each with the reason and who and when. Kept
  centrally so a host's own `memory.md` gets no new line, and
  #232's line audit is not touched by it.

The token kinds, the only vocabulary Hostwarden brings to a
template: `site`, `role`, `index`, `environment`, `literal` (a
character or word that never changes), and `free` (any label, which
is how a pet name is recorded). Their order and their separators are
the user's; Hostwarden never invents one of its own past the
default template (The best-practice proposal below).

### Domain models

- **One domain for every host.**
- **One subdomain per site:** `<name>.<site>.<domain>`.
- **One subdomain per environment:** `<name>.<environment>.<domain>`.

`Domain:` in the store names which model is in force and the domain
or domains it uses. A second regex checks the domain part where the
model needs one — a subdomain-per-site model checks that the
subdomain names a site the scheme knows.

### Checking a name

A full name is checked in two parts, never as one string: the
hostname label — the first label of its FQDN, up to the first dot —
against `Regex:`, and the domain that follows it against `Domain:`.
A name whose label matches but whose domain does not is `off
scheme` like any other mismatch, never `on scheme`.

- **One domain for every host:** the domain after the label must
  equal `Domain:` exactly.
- **A subdomain model:** the domain after the label is checked
  against that model's own regex (above).

Every consumer checks a name this way — never the full FQDN against
`Regex:` alone, which only ever matches the label:
`hostwarden-new-guest` → The request, `rules/host-rename.md` → The
New Name, the fleet audit's Naming row, and the onboarding report.

### Which block applies to a host

A block's selector reaches a host when `Applies to:` matches it. A
block **governs** a host when its selector reaches it and the host
is not on that block's `Exempt:` line — governing is what decides
which `Regex:` and `Domain:` a name is checked against.

- **Exactly one block governs:** the name is checked against it
  (Checking a name, above) — `on scheme` or `off scheme → <name>`.
- **No block governs, and no block's selector reaches the host
  either:** it has **no scheme**. The fleet audit's row says
  `no scheme`, never `off scheme`, and no name is proposed for it.
- **No block governs, but some block's selector reaches the host:**
  it is on that block's `Exempt:` line — the row says `exempt`, and
  no name is checked or proposed.
- **`Role: workstation`** reaches no block's selector unless a
  block names it, so it always falls into the second case.
- **A selector's `Site:` value** is matched against the site a guest
  is read as having — its host's, through `Runs on:` — where the
  host itself is a guest, since a guest never carries a `Site:` line
  of its own (`rules/network-topology.md` → Sites). A guest is never
  left unmatched by a site-scoped block just for lacking that line.

**Blocks have no scope hierarchy.** Nothing is "narrower" than
anything else, and the file's order decides nothing. **Two blocks
that both govern one host cannot both be meant** — the same
principle as `rules/decisions.md` → When it is read. The overlap is
caught when a block is written or its selector changed: the
question names every host both blocks would govern now, and the
user narrows one selector or adds those hosts to one block's
`Exempt:` — which removes that block from governing them, leaving
the other as the sole governor, never a renewed overlap. An overlap
that appears later, because a host's fields changed after the
blocks were written, is caught the next time that host's name is
checked — the fleet audit's Naming row or the onboarding report,
the only two places that recheck an existing host. **With a person
present,** it is asked right there, once, as one `AskUserQuestion`
(the ASCII fallback of `rules/ssh-user.md` → Interview format where
the tool lacks it) naming both blocks, with the same two answers,
before that row or line is written: what gets rendered is the
answer's outcome — `on scheme`, `off scheme → <name>`, or `exempt`
— never a placeholder. A fleet audit never runs unattended, so this
is its only path. **An onboarding run with nobody at the
keyboard** (a scheduled run, or an agent of `rules/multi-host.md`)
asks nothing and writes `ambiguous (<block>, <block>) — not asked`
on that host's report line instead, left for the next interactive
onboarding run or fleet audit to resolve. Nothing is picked
silently.

## Adopting a scheme is a decision

Recorded in `memory/decisions/naming.md` with `Applies to: all` —
that the fleet is named by these schemes is a fleet-wide decision,
and each block's own selector decides which scheme applies where.
One `##` entry per block, headed `Naming scheme: <block name>`, in
the shape `rules/decisions.md` → The entry gives:

```markdown
# Decisions — all hosts
Applies to: all

## Naming scheme: Servers
- Decided: user, 2026-09-24
- Why: the user's reason for this block's scheme
- Settles: the fleet audit's Naming row for this block's hosts; the
  naming question in the first onboarding
```

The decision holds who decided, when and why; `memory/naming.md`
holds the definition, the same split `memory/service-policy.md`
keeps beside its own decision (`rules/service-reload.md`). **No
naming scheme** is recorded the same way, as a single
`## No naming scheme` entry where `memory/naming.md` does not exist
at all, and ends every question about setting one up.

**`## Naming scheme: pending`** is a third kind of entry, written
by answer 1 of the onboarding question below in place of a real
scheme or "No naming scheme":

```markdown
## Naming scheme: pending
- Decided: user, 2026-09-24
- Why: not enough hosts yet to detect a pattern
- Settles: the naming question in the first onboarding — replaced
  once a scheme is adopted or "No naming scheme" is recorded
```

It marks only that the question has been asked and answered once,
and it is what tells a later onboarding run to run Detection
instead of asking again. It is replaced, never left standing beside
another entry: a scheme adopted afterwards, by detection or by
answer 2 or 3, deletes it in the same edit that adds the real
entry, as does "No naming scheme".

## The question in the first onboarding

Asked once, at the end of the first `hostwarden-onboard` run in a
workspace that has neither `memory/naming.md` nor a naming decision
(above), after that run's report, as one `AskUserQuestion` (the
ASCII fallback of `rules/ssh-user.md` → Interview format where the
tool lacks it):

1. **I'll detect it once there are a few more hosts** (default) —
   writes `## Naming scheme: pending` (above); Detection below runs
   at the end of a later onboarding run once there are enough
   hosts.
2. **Propose a best-practice scheme now** — The best-practice
   proposal below, run at once.
3. **I'll describe mine now** — the user's own words go through the
   same confirmation a detected scheme gets: template, regex, and
   which hosts match.
4. **No naming scheme** — recorded as the decision above; the
   question is never asked again.

Never asked on a run with nobody at the keyboard (a scheduled run,
an agent of `rules/multi-host.md`): it is left for the next
interactive onboarding run. The user can also start any of the four
at any time by asking in words, such as "what is our naming
scheme" or "set up a naming scheme" — the same four options, the
same confirmation. Once a decision is recorded, `rules/decisions.md`
→ Proposing applies: the question is never raised again, and a
request for something the decision rules out is answered as that
file's Proposing section says.

## Detection

**When it runs.** `memory/decisions/naming.md` has the
`## Naming scheme: pending` entry (answer 1 above), and an
interactive onboarding run ends with at least 3 hosts in memory
that count (below). Three is the fewest names in which a shared
structure can be told apart from coincidence; two names always
share something.

**What counts.** Every host under `memory/machines/`, skipping
symlinks (DNS aliases), a `Role: workstation` host, and a host
already `Exempt:` in `memory/naming.md`.

**What it reads,** for each host that counts:

- its directory name and `- FQDN:`;
- `Site:` (a guest's: its host's, through `Runs on:`) and, through
  it, the site's code in `rules/network-topology.md` → A site's
  code, the service lines (`Web server:`, `Database:`, …), and
  `Appliance:` or `Hypervisor:`, for correlation.

**Method.** Split the first label — the directory name, or the
FQDN's first component where it differs — at every hyphen and at
every boundary between a letter and a digit. Classify each position
across the hosts that count:

- a `site` token when its values line up with the code recorded
  for the host's `Site:` (a guest's: its host's, through
  `Runs on:`) in `rules/network-topology.md` → A site's code;
- an `index` when it is digits at that position on every host that
  has one there. Its width is the width every host that counts
  shares; where they disagree, the regex takes `[0-9]+` at that
  position instead of a fixed width, and the question below flags
  the disagreement so the user can settle it;
- a `role` token when its values line up with a service line
  (`Web server:` → `web`, `Database:` → `db`, …) or with the host's
  `Appliance:` or `Hypervisor:` line, where the position's value is
  a recognisable abbreviation of it — `pve` for a `Hypervisor:` or
  `Appliance:` line naming Proxmox VE, `nas` for a storage
  appliance's `Appliance:` line. A position on an otherwise plain
  host that lines up with none of these is asked about in the same
  exchange as a site whose code names no site yet (below);
- a `literal` when its value never changes across the hosts that
  count;
- `free` otherwise.

`Role:` in `memory.md` only ever holds `server` or `workstation`
(`rules/first-detection.md` → Roles), never a function, so it plays
no part in this classification — a `Role: workstation` host is
excluded before it starts (What counts above).

Build the domain model from the FQDNs' suffixes, compared per site:
one suffix for every host is one domain for every host; a suffix
that varies by site and matches `<site>.<domain>` is one subdomain
per site. A host whose `- FQDN:` is `none` or `unknown`
(`rules/dns-aliases.md` → The FQDN) contributes no suffix to this
comparison, though it still counts toward the three hosts and its
hostname label is still classified and checked. **Where no host
that counts contributes a suffix,** no domain model can be built:
the question below asks for the domain directly, alongside the
template, or offers the same two alternatives as no structure found
(below). Build the template and the regex from the classified
positions and the domain model, and apply the regex to every host
that counts.

**The question,** one `AskUserQuestion` (the ASCII fallback of
`rules/ssh-user.md` → Interview format where the tool lacks it),
showing:

- the template and what each token means;
- the domain model;
- the hosts that match, with a count, and every host that does not.

The answers: **correct** (record as detected) / **correct with
these changes** (the changed template and regex go through the same
confirmation once more) / **not a scheme** (offer The best-practice
proposal below, or no scheme at all, in the same exchange). A site
position whose value names no site with that code yet in
`rules/network-topology.md` → A site's code is asked about in the
same exchange; the answer names or creates the site, and the code
is recorded there, never in `memory/naming.md`. **No structure
found:**
say so in one line and offer the same two alternatives.

Nothing is adopted without a yes — a `correct` or `correct with
changes` answer writes `memory/naming.md` and the decision above; any
other answer writes neither.

## The best-practice proposal

Offered on request, as answer 2 of the onboarding question, or after
a detection that found nothing. Shown with three names from the
actual fleet rewritten to it, so the user sees what `web1` would
become, then asked once: **adopt** / **adopt with changes** / **no**.
**Adopt** or **adopt with changes** writes `memory/naming.md` and
the decision above. **No**, where no scheme and no naming decision
exist yet, writes or refreshes `## Naming scheme: pending` — the
same entry answer 1 of the onboarding question writes — so the
fleet is not asked the whole question again from scratch on the
next onboarding run; where a scheme or a decision already exists,
declining a proposal shown out of curiosity changes nothing.

**Syntax.** Lowercase letters, digits and hyphens. A label starts
with a letter, does not end with a hyphen, and has at most 63
characters (RFC 1123 §2.1, RFC 952).

**Content.** A name says what is stable: site, function, index. It
never says what changes — OS or version, hardware, address, owner,
customer.

**Default template:** `<site>-<role><nn>`, one domain for every
host.

- The site is a site's code (`rules/network-topology.md` → A
  site's code).
- The index is shown zero-padded to two digits (`01`, `02`, …) —
  the default, not a rule: unpadded (`1`, `2`, …) or another width
  is a change to the shown template like any other, taken with
  **adopt with changes**.
- A short name stays unique across the fleet and is what people
  type; a subdomain per site is offered as the alternative, never
  chosen for the user.

**Domain, in order of preference:**

1. a subdomain of a domain the user owns (`int.example.com`). It is
   the only choice public CA certificates work with — ACME's
   DNS-01 challenge issues them without any internal host being
   reachable from outside — and the only one that allows internal
   DNSSEC through a signed delegation from a public chain of
   trust;
2. otherwise `home.arpa` (RFC 8375) for a home network. Its
   delegation is insecure, so a validating resolver accepts local
   answers for it without extra configuration;
3. or `.internal` for an organisation. ICANN reserved it for
   private use and will never delegate it (Board resolution
   2024.07.29.06). The root proves its absence, signed, so a
   validating resolver that does not serve the zone itself needs an
   exception (`domain-insecure` in Unbound, or a negative trust
   anchor).

With `home.arpa` or `.internal`, no public certificate authority
issues a certificate: the CA/Browser Forum's Baseline Requirements
exclude internal names. Where the domain is one of these two, the
proposal names the options that remain, without choosing one: an
internal CA, whose certificates clients trust once the CA is
installed on them; self-signed certificates, trusted one at a time;
or no TLS on the internal network. Nothing else in Hostwarden
requires a CA.

**Never proposed:** `.local`, which is mDNS (RFC 6762); an invented
top-level domain such as `.lan`, `.home` or `.corp`, which may be
delegated or already collide with something; or a public domain the
user does not own.

## New hosts follow it immediately

`hostwarden-new-guest` → The request defines the mechanism: propose
the next name a scheme gives the target, confirm it or take a typed
name instead, and report a name that does not match before the
target is created or written to. `hostwarden-os-install` → Naming a
target with no memory yet is its second consumer, for a machine
with no `memory/machines/` entry yet. Neither invents a
name-proposal step of its own; a third consumer reaches for this
section too, rather than a new one.

## Existing hosts: gradually, never forced

- **The fleet audit's Naming row,** one per host, computed from
  memory alone at render time, with no probe on the host:
  `on scheme` (checked as Checking a name, above) ·
  `off scheme → <proposed name>` · `exempt` · `no scheme` (Which
  block applies to a host, above, resolves an overlap into one of
  these before the row is written). A
  difference from a fleet-wide scheme is drift, which is what the
  audit reports; it is never a finding in housekeeping
  or the security audit, which would otherwise repeat the same INFO
  line in every report while a fleet is halfway through a migration.
  The proposed name is computed for that run only and never stored:
  the next free index depends on the fleet as it stands when the
  audit runs. Its site and role tokens are derived the same way
  Detection derives them — the site from `Site:` (a guest's: its
  host's, through `Runs on:`), the role from a service line or the
  host's `Appliance:` or `Hypervisor:` line — and where the role
  cannot be derived this way, the row reads `off scheme, name not
  proposed` instead of naming one.
- **A range's suffix.** Where `rules/network-topology.md` → Ranges
  records a DNS suffix for a range that differs from the scheme's
  domain for that site, the audit's Naming row says so for that
  range's hosts.
- **No deadline and no reminder** beyond the audit's row and the
  onboarding report line below. `Exempt:` silences the row for that
  host for good.
- **A rename happens only when the user asks, one host at a time**
  (`rules/host-rename.md`). Naming a host onto the scheme is a
  rename like any other; nothing here starts one, batches one, or
  schedules one.

### Onboarding a host whose name does not match

A first connection or a full re-probe that finds a scheme in force
and a name that does not check out against it (Checking a name,
above) adds
`not on naming scheme (would be <proposed name>)` to the host's
line in the onboarding report (`hostwarden-onboard` step 7), or
`not on naming scheme (name not proposed)` where its role token
cannot be derived (Existing hosts: gradually, never forced, above).
It is not a finding, and it does not ask: the fleet audit's row and
a rename on request are how a mismatch is acted on — except a host
two blocks now govern, resolved the same way Which block applies to
a host (above) resolves it everywhere else, unattended runs
included.
