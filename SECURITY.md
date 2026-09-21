# Security Policy

hostwarden hands an AI assistant a shell on production servers,
often as root. A flaw in it is a flaw on every host it manages,
so reports are taken seriously and handled privately.

## Reporting a vulnerability

Report it privately through GitHub: **Security → Report a
vulnerability** on this repository. Do not open a public issue,
discussion or pull request for it.

Say what you did, what hostwarden did, and what it should have
done. Leave out anything real: no production hostnames, IP
addresses, keys, tokens or memory files. Use `example.com`,
`192.0.2.0/24` and placeholders such as `<production-host>`
instead.

## What counts

- **The taboo guard lets a command through** that
  `AGENTS.md` → Critical Safety Rules forbids — a partition
  table write, a whole-disk erase, a write to `sshd_config`, an
  SSH key deleted or overwritten, a halt or power-off — in any
  spelling, wrapper or permission mode.
- **A secret reaches the conversation, a report, an email, the
  journal or `memory/`**, against `rules/secrets.md`.
- **Output from a managed host steers hostwarden** into acting
  on it instead of reporting it: a file, a log line, a banner
  that works as an instruction (`rules/anomaly-detection.md`).
- **A change runs without the confirmation** the rules require
  before it — a restart, a firewall change, a destructive
  command.
- **A script in `bin/` or a hook in `.claude/hooks/`** that can
  be made to act outside the checkout or the user's own memory.

## What does not

- Vulnerabilities in the AI tool itself — Claude Code, OpenCode
  or another — go to its vendor.
- Vulnerabilities in the software on a managed host go to that
  software's project. hostwarden finding or missing one in an
  audit is an ordinary bug report.
- A command you approved that did harm. hostwarden proposes,
  you approve (README → Risks & Responsibilities). If the rules
  should have kept it from being proposed, that is an ordinary
  bug report.

## Supported versions

Fixes land on `main` and ship with the next release. Only the
latest release and `main` are supported. A checkout pinned to a
tag (`bin/hostwarden-update --pin`) gets no fix until the pin
moves.
