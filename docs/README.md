# Hostwarden documentation

The detail behind the [README](../README.md), grouped
by task.

## Getting started

- [Installing Hostwarden](install.md) — what each
  prerequisite is for, and the WSL setup Windows
  needs.
- [Supported AI tools](ai-tools.md) — Claude Code in
  the terminal and in the desktop app, OpenCode with
  Ollama, and what the others miss.
- [Features](features.md) — what Hostwarden does, with
  example prompts, and the systems it knows:
  appliances, WSL, workstations, Windows Server.

## Running it

- [Safety and guardrails](safety.md) — what it asks
  before doing, the hard taboos, how it keeps
  hallucinated commands off your servers, how to read
  its logs, and who it's for.
- [What Hostwarden recommends](recommendations.md) —
  what it proposes by default, why, and how to decide
  against any of it.
- [Automation and scripting](automation.md) —
  one-shot commands, auto mode, scheduled
  housekeeping.
- [Overrides](overrides.md) — changing a rule or a
  skill without editing Hostwarden's files, and
  adding skills of your own.
- [Running Hostwarden in production](operations.md)
  — operations and development checkouts, mirrors,
  updates, teams and several machines, backup and
  restore, moving over from Heinzel.

## Working on Hostwarden

- [Project structure](project-structure.md) — what
  every file in the repository is for.
- [CONTRIBUTING.md](../CONTRIBUTING.md) — setup,
  checks, and where a change goes.
- [Architecture decisions](architecture-decisions.md)
  — when a decision about Hostwarden gets a record,
  and the format; the records are indexed in
  [adr/README.md](adr/README.md).
- [SECURITY.md](../SECURITY.md) — how to report a
  vulnerability.
