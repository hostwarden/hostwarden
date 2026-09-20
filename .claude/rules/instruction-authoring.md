---
paths:
  - "AGENTS.md"
  - "CLAUDE.md"
  - "README.md"
  - "CHANGELOG.md"
  - ".claude/rules/**"
  - ".claude/hooks/**"
  - "contrib/**"
  - ".github/**"
description: How hostwarden's own instruction text is written —
  layout, wrapping, example identifiers, and where a new
  instruction belongs. For work on this repository, never for a
  managed host.
---

# Writing hostwarden's instructions

The product is the instruction set. These conventions apply to
`AGENTS.md`, everything under `rules/`, every `SKILL.md` and its
references, the files in `.claude/rules/`, and `contrib/`.

A `paths` glob cannot tell reading a rule in order to follow it
from reading it in order to edit it, so this file does not list
`rules/**` — it would then load in every sysadmin session, which
is exactly the cost the layout removes. What matters most here is
checked mechanically instead:
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
  `.agents/skills/`. Its `description` carries the phrasings that
  should trigger it, in English and German. `SKILL.md` stays under
  500 lines; detail goes to `references/`.
- **Is it about this repository rather than a managed host?**
  `.claude/rules/`, with a `paths` glob that matches files a
  sysadmin session never reads.

A file keyed by a fact rather than a moment — the OS-family files
— is reference data and lives in `rules/os/`.

## Current state only

Instruction files describe how things are. Never "previously",
never "this used to live in", never a migration note. A reader of
`rules/backups.md` needs to know what to do, not what the file
said last month.

`CHANGELOG.md` is the only place a change is recorded as a change,
one entry per item.

## Layout

- Wrap every `.md` at 80 characters. A URL or a command line that
  cannot be broken may exceed it.
- One `#` title per file, matching what the file is called.
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
  `192.168.0.0/16`, `169.254.169.254` for cloud metadata).
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
`https://mise.jdx.dev`, `https://brew.sh`. The rule is about
identifiers an example pretends to own.

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

The guard scans the whole command string and cannot tell a taboo
word used as data from an invocation, so a probe that merely
*mentions* `mkfs` or a key path gets denied. Write patterns that
never spell one from the start (`grep 'power[o]ff'`), and keep a
probe naming a guarded path in a call of its own — two innocent
commands deny each other when batched.

The same applies to writing about this. A commit message piped
into `git commit -m` flows through the command string; write it to
a file and use `git commit -F <file>`.
