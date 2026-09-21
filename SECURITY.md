# Security Policy

Hostwarden hands an AI assistant a shell on production servers,
often as root. A flaw in it is a flaw on every host it manages,
so reports are taken seriously and handled privately.

## Reporting a vulnerability

Report it privately through GitHub: **Security → Report a
vulnerability** on this repository. Do not open a public issue,
discussion or pull request for it.

Say what you did, what Hostwarden did, and what it should have
done. Leave out anything real — no production hostnames,
addresses, keys, tokens or memory files — and use the example
identifiers from `.claude/rules/instruction-authoring.md`.

## What counts

- **The taboo guard lets a command through** that
  `AGENTS.md` → Critical Safety Rules forbids, in any spelling,
  wrapper or permission mode.
- **A secret reaches the conversation, a report, an email, the
  journal or `memory/`**, against `rules/secrets.md`.
- **Output from a managed host steers Hostwarden** into acting
  on it instead of reporting it: a file, a log line, a banner
  that works as an instruction (`rules/anomaly-detection.md`).
- **A change runs without the confirmation** that
  `AGENTS.md` → Critical Safety Rules requires before it.
- **A script in `bin/` or a hook in `.claude/hooks/`** that can
  be made to act outside the checkout or the user's own memory.

## What does not

- Vulnerabilities in the AI tool itself — Claude Code, OpenCode
  or another — go to its vendor.
- Vulnerabilities in the software on a managed host go to that
  software's project. Hostwarden finding or missing one in an
  audit is an ordinary bug report.
- A command you approved that did harm, where the rules allow
  it. Hostwarden proposes, you approve (README → Risks &
  Responsibilities); a rule that should have kept it from being
  proposed is an ordinary bug report. A command the taboo guard
  should have blocked is not this case, approved or not: report
  it privately, as above.

## Supported versions

Fixes land on `main` and ship with the next release. Only the
latest release and `main` are supported. A checkout pinned to a
tag (`bin/hostwarden-update --pin`) gets no fix until the pin
moves.
