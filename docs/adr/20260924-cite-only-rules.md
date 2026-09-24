---
id: 20260924-cite-only-rules
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [records, tooling]
---

# Convention files in `.claude/rules/` need no record behind them

## Context

Hostwarden took up architecture decision records on 2026-09-24, in the
format of Workoho's decision-records skill. Its check, `decisions.py`,
treats every file in `.claude/rules/` as derived from a record and
fails on one without a `Source:` line. The skill asks for the script
to be copied byte for byte. Hostwarden's `.claude/rules/` is older
than its records: three convention files, for instruction text, pull
requests and releases. Each carries many decisions, or none. The
script also looks for records in `docs/decisions/`, which Hostwarden
keeps in `docs/adr/`, apart from a user's decisions about their hosts.

## Decision drivers

- Claude Code loads those files by their `paths` glob, only from
  `.claude/rules/`, and nowhere else carries them to the session.
- One `Source:` line per file cannot name the many decisions a
  convention file carries.

## Considered options

### Two marked changes in `decisions.py` — chosen

A file in `.claude/rules/` counts as a rule only when its `Source:`
line points into `docs/adr/`, and `--root` defaults to `docs/adr`.
Against it: a derived rule there that loses its `Source:` line is
no longer caught, and every update from the skill has to make both
changes again.

### The script byte for byte, the conventions moved out

Move the three files where the check does not look. Lost: Claude
Code would no longer load them by path, and `AGENTS.md`, which
every tool reads, has a size budget they would break.

### Templates and index without the script

Write the index by hand and check nothing. The skill forbids a
hand-written index, and nothing would notice a record and the index
disagreeing.

## Decision

`scripts/decisions.py` is the skill's copy with two changes, each
marked by a comment naming this record: the line in
`collect_rules`, and `docs/adr` as the default for `--root`.

## Consequences

The three convention files keep their place and their globs. A
record's constraint goes into the file that governs its area, and
the record has no `rule:` field, as
`docs/architecture-decisions.md` says.

## Confirmation

Without the line, the check fails on each of the three convention
files; without the default, it finds no records. A copy that forgot
either cannot pass CI.
