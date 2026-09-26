---
id: 20260926-onboarding-asks-by-site-at-run-close
status: proposed
waiting-on:
tags: [onboarding, questions, network]
---

# Several-host onboarding asks at the run's close, per site

## Context

A session that imported 45 hosts from Heinzel and onboarded three
hypervisors with about 30 guests asked the site, uplink, upstream
firewall, management and backup questions for every host, nearly
alike across one site, at 18 to 35 minutes per host. Each host was
closed, questions included, before the next one started, so no
answer could cover more than one host, and the co-presence that
groups hosts into sites only saw the hosts already done.

## Decision

With several hosts, step 6's questions wait until the last host is
measured; one about a place is asked once per site, naming each
host, and recorded on each.

## Consequences

The answers come later than the measurement, and a run cut off
before its close leaves them for the owning rules to ask again.
Site grouping sees the whole run. A host's measurement no longer
stops for a closing question, which running onboarding in rounds
(hostwarden/hostwarden#472) needs. The constraint lives in
`hostwarden-onboard` → Several hosts: questions by site and
`rules/network-topology.md` → The question.
