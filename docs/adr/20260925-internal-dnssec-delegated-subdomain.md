---
id: 20260925-internal-dnssec-delegated-subdomain
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [dns, security]
---

# Internal DNSSEC uses a delegated subdomain, never a shared key

## Context

Decided in the design of #270, from the maintainer's requirement of
2026-09-24 that internal DNSSEC be possible without breaking the
registrar's delegation. An internal zone under the user's public
domain can be signed in several ways; some put the key that can
forge the public zone on internal machines.

## Decision drivers

- The public zone's signing key stays where it is.
- The registrar's DS must never be changed by Hostwarden.
- Internal resolvers should validate a public chain of trust.

## Considered options

### A delegated subdomain signed internally — chosen

`int.example.com` is signed on the internal server with its own
keys; the public zone holds its NS records, glue for nameservers
named inside it, and a DS, which is a hash, not a secret. Against it:
the public zone names the internal nameservers and, through glue,
their addresses, and queries from outside time out.

### The same KSK on the internal and the public signer

Lost as the default: it works, but the key that can forge the public
zone then lies on two machines. Hostwarden names it for split-brain
under one zone name, and copying the key is the user's step.

### Multi-signer (RFC 8901), or one signer with the provider as secondary

Kept as options Hostwarden names for split-brain, never chosen:
both need the provider's cooperation and a signing setup the user
runs.

## Decision

Where the user wants internal DNSSEC, Hostwarden proposes a
delegated subdomain. It never moves or copies a DNSSEC private key,
never changes a DS at the registrar and never rolls a key.

## Consequences

`rules/dns.md` → Internal domain and DNSSEC carries the proposal and
the three ways for split-brain. A request to copy a key or change a
DS is the user's step, answered with this record.

## Confirmation

Nothing would tell us on its own. A proposal that needs a key
copied to be valid is the moment to reread this record.
