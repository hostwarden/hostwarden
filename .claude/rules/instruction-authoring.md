---
paths:
  - "AGENTS.md"
  - "CLAUDE.md"
  - "README.md"
  - ".claude/rules/**"
  - ".claude/hooks/**"
  - "contrib/**"
description: How hostwarden's own instruction text is written —
  layout, wrapping, example identifiers, and where a new
  instruction belongs. For work on this repository, never for a
  managed host.
---

# Writing hostwarden's instructions

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

The mechanical half is checked rather than remembered:
`sh .claude/hooks/instructions-test.sh`.

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

A file keyed by a fact rather than a moment — the OS-family files
— is reference data and lives in `rules/os/`.

## Current state only

Instruction files describe how things are, never how they came
to be. `.claude/rules/repo-release.md` states the rule and owns
its one exception, `CHANGELOG.md`.

## Layout

- Wrap every `.md` at 80 characters. A URL or a command line that
  cannot be broken may exceed it.
- One `#` title per file, matching what the file is called. A
  file whose job is to load another has no content to title —
  `CLAUDE.md` opens with its import — and does not get one.
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
  ranges, loopback and link-local are fine where the example is
  genuinely about one (`127.0.0.1`, `10.0.0.0/8`,
  `192.168.0.0/16`, `169.254.169.254` for cloud metadata). Both
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
  hostwarden never runs it.
- ```` ```bash guard-off ```` — hostwarden runs it only after the
  operator relaunched with `HOSTWARDEN_GUARD_DISABLE=1`, and the
  file must say so.

How to write a probe that the guard does not mistake for an
invocation is in `AGENTS.md` → Critical Safety Rules, where it
is in context at the moment a probe is written. The fence
markers above are the part that is specific to writing
instruction text.
