---
paths:
  - "AGENTS.md"
  - "CLAUDE.md"
  - "README.md"
  - "docs/**"
  - ".claude/rules/**"
  - ".claude/hooks/**"
  - "contrib/**"
description: How Hostwarden's own instruction text is written —
  layout, wrapping, example identifiers, and where a new
  instruction belongs. For work on this repository, never for a
  managed host.
---

# Writing Hostwarden's instructions

The product is the instruction set. These conventions apply to
`AGENTS.md`, everything under `rules/`, every `SKILL.md` and its
references, the files in `.claude/rules/`, and `contrib/`.

A `paths` glob fires on a *read*, and it cannot tell reading a
rule in order to follow it on a production host from reading it in
order to edit it. So `rules/**` and `.agents/skills/**` are not
listed above — a glob over the product would load these
conventions into every sysadmin session, which is the cost the
layout exists to remove.

An *edit* carries no such ambiguity, so that is the trigger for
those two: `.claude/hooks/authoring-conventions.sh`, a PostToolUse
hook on `Edit|Write`, names this file once per session when one of
them is touched. Where hooks do not run, read it yourself before
changing the product.

The mechanical half is checked rather than remembered, by
`instructions-test.sh`, before each commit and in CI
(`pull-requests.md` → Checks).

## Where a new instruction belongs

Four mechanisms, one question each:

- **Does it have to be in context before anything happens?**
  `AGENTS.md`. Only reflexes and facts every single session needs.
  It has a size budget; adding to it means taking something out.
- **Does it fire at a moment in the work, with no user asking?**
  A file in `rules/`, named from `AGENTS.md` → Where the Rest
  Lives by the moment that triggers it. The trigger line lives in
  `AGENTS.md`, the procedure lives in the file — never both.
- **Does the user ask for it by name?** A skill in
  `.agents/skills/`. Its `description` carries the phrasings a
  user would actually say — in every language they would say them
  in, which for this project means German alongside English
  wherever a German speaker would reach for the workflow.
  Keep `SKILL.md` short enough to read in one go, around 500
  lines; past that, route to `references/` instead of adding.
- **Is it about this repository rather than a managed host?**
  `.claude/rules/`, with a `paths` glob that matches files a
  sysadmin session never reads.

Why Hostwarden does something is none of these. A decision about
Hostwarden itself, with the options it turned down, is a record in
`docs/adr/` (`docs/architecture-decisions.md`), and the constraint
it leaves goes where the four questions put it. Before changing a
behaviour a record set, read `docs/adr/README.md`.

A file keyed by a fact rather than a moment — the OS-family files
— is reference data and lives in `rules/os/`. Reference data that
several OS files share, such as `rules/busybox.md`, lives in
`rules/` beside them, named by what it describes. It is reached
through the files that point to it, never by detection, so the
one-family cap still holds.

An appliance (`rules/first-detection.md` → Appliances) gets a file in
`rules/appliance/` and a row in that section's marker table. The
file opens with a `Base:` line naming its family file, or
`Base: none`, followed by a `Hardware:` line, `vendor` or `any`
as that section defines them, and has a
`## Housekeeping and Audits` section.
Decide per section of the base with the override prefixes; "this
file wins wherever the two disagree" leaves the reader to find the
disagreement on a live firewall.

A platform (`rules/first-detection.md` → Platforms) gets a file in
`rules/platform/` and a row in that section's marker table. It has
no `Base:` line and a `## Housekeeping and Audits` section;
`instructions-test.sh` holds its prefixed headings to the sections
every family file has.

A family file may have a `## Housekeeping and Audits` section too.
One whose commands are not `sh` — Windows — carries its checks
there in full, because the skills' baseline references are
written for `sh`.

A role (`rules/first-detection.md` → Roles) gets a file in
`rules/role/`. It changes no command, only expectations and
ratings, so it uses no override prefixes: each section says which
rule, expectation or check it changes, by name.

## For people and for the agent

`docs/` and the README are written for the person running
Hostwarden; `rules/` and the skills for the agent. Wherever a page
for people describes what a rule or skill makes the user write,
see or decide — overrides, parallel sessions, the Heinzel
takeover, scheduled runs, the guardrails — both use the same terms
and the same names for the same parts, and a change to that
behaviour changes both in the same commit. The page says what to
do and where; how the agent resolves the unclear cases stays in
the rule, and the rule never sends the agent to the page.

One term per thing. What a user writes under `memory/custom-rules/`
is an **override**, never a customization or a custom rule; the
directory keeps its name. `instructions-test.sh` fails on the
retired words.

## Current state only

Instruction files describe how things are, never how they came
to be. `.claude/rules/repo-release.md` states the rule and owns
its one exception, `CHANGELOG.md` and the fragments in
`changelog.d/` that become it.

## Claims

A claim says what a flow does or guarantees: that a phase is
"read-only", that "every" guest gets a line, that a result is
"verified", that a snapshot covers the "whole" guest. It is a
promise every step of the flow has to keep, on every platform the
file covers. Write one only where you have checked each step
against it; otherwise say what the step does and leave the
guarantee out. A claim that a review has broken twice, or that no
change to the steps can keep, is dropped, not narrowed.

A prohibition is not a claim. "Never pass a secret as an argument"
tells the agent what not to do; a step that breaks it is the
defect, and the prohibition stays.

## Layout

- Wrap every `.md` at 80 characters. A URL or a command line that
  cannot be broken may exceed it, and so may `docs/adr/README.md`,
  which `scripts/decisions.py` generates. `bin/hostwarden-wrap`
  rewraps paragraphs, and its `--check` is the measure the layout
  test applies; a heading, a table row or front matter over 80 is
  shortened by hand.
- One `#` title per file, matching what the file is called. A
  file whose job is to load another has no content to title —
  `CLAUDE.md` opens with its import — and does not get one.
- **Hostwarden** and **Heinzel** are names and are capitalised in
  prose, comments and messages. What is spelled as an identifier
  stays as it is spelled: commands, paths, skill names, the
  journal tag, `HOSTWARDEN_*`, and the program name a script
  puts in front of its output (`hostwarden: …`,
  `hostwarden guard: …`).
- Sentences, not telegram style. The reader is a model that will
  act on this on a production server.
- State what to do before why. The reasoning earns its place when
  it stops someone from "improving" the rule away — the guard
  hook's header is the model.

## Example identifiers

Everything in an example is fictional, and fictional by a standard
somebody else already set, so nobody has to judge case by case.

- **Hostnames and domains: RFC 2606 and RFC 6761 only** —
  `example.com`, `example.net`, `example.org`, and anything under
  them (`server1.example.com`, `web1.example.com`,
  `db1.example.com`). For things that must not resolve at all,
  `.invalid`; for test fixtures, `.test`; for the local machine,
  `localhost`. Never a domain that belongs to someone.
- **IP addresses: RFC 5737 and RFC 3849 only** — `192.0.2.0/24`,
  `198.51.100.0/24`, `203.0.113.0/24`, `2001:db8::/32`. Private
  ranges, shared address space, loopback and link-local are fine
  where the example is genuinely about one (`127.0.0.1`,
  `10.0.0.0/8`, `192.168.0.0/16`, `100.64.0.0/10` for
  carrier-grade NAT, `169.254.169.254` for cloud metadata). Both
  families are checked.
- **People: Alice and Bob**, then Carol, Dave, Eve, and on through
  the alphabet when an example needs more actors — the convention
  cryptography has used for decades. `alice`, `bob` as usernames,
  `bob@example.com` as an address. Never a real person's name,
  not a colleague's, not an upstream author's, not the user's.
- **Never a real production host, internal URL, customer name or
  address**, in an instruction file, a commit message, an issue or
  a pull request. Where a command needs an address, a placeholder
  says more than a borrowed one: `root@<production-host>`.

A real domain is fine in a *link* to its documentation —
`https://mise.jdx.dev`, `https://brew.sh` — and in a command
that genuinely has to reach it, such as an apt source or an
NTP server. The rule is about identifiers an example pretends
to own, which no pattern can separate from the rest; the test
therefore checks the two places where the answer is never
ambiguous, mail addresses and the target of an `ssh` or `scp`
command. Everything else is a matter for review.

## Commands in instruction text

Every fenced block under `rules/` and `.agents/skills/` is run
through the taboo guard by the test matrix, because a block that
gets copied into a session has to survive the guard that protects
production disks.

Two fence markers change that:

- ```` ```bash operator ```` — the user types this at a console;
  Hostwarden never runs it.
- ```` ```bash guard-off ```` — Hostwarden runs it only after the
  operator relaunched with `HOSTWARDEN_GUARD_DISABLE=1`, and the
  file must say so.

How to write a probe that the guard does not mistake for an
invocation is in `AGENTS.md` → Critical Safety Rules, where it
is in context at the moment a probe is written. The fence
markers above are the part that is specific to writing
instruction text.
