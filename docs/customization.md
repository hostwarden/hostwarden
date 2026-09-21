# Rule customization

Hostwarden supports layered rule overrides so you can
customize behavior without editing the upstream rule
files (which would cause merge conflicts on
`git pull`).

Four layers, read in order (later wins):

1. **Shipped** — the rule file or skill (upstream,
   git-tracked)
2. **Global custom** — the mirroring file under
   `memory/custom-rules/` (in the workspace)
3. **Every file** — `memory/custom-rules/all.md`
4. **Per-server** —
   `memory/servers/<hostname>/rules.md`

**Your file's path mirrors the shipped one**, minus
the top-level directory and minus `references/`:

| Shipped | Yours, under `memory/custom-rules/` |
| ----------------------------------- | ------------------------- |
| `rules/backups.md`                   | `backups.md`              |
| `rules/os/debian.md`                 | `os/debian.md`            |
| the `hostwarden-security` skill      | `hostwarden-security.md`  |
| that skill's `references/ssh.md`     | `hostwarden-security/ssh.md` |

Custom files use heading prefixes to control how
they interact with what was shipped:

```markdown
## Add: Docker cleanup
New rules applied alongside the base.

## Replace: Firewall
Replaces the matching base section entirely.

## Remove: Notes > snap
Drop one entry, leave the rest of that section.
```

Sections without a prefix are treated as additions.
Prefer `Add` to `Replace`: an addition that
contradicts a shipped default still wins, and it
does not leave you maintaining a copy of a section
that keeps evolving upstream.

Hostwarden names the customizations it loaded in one
line at session start, and tells you when a file
under `memory/custom-rules/` matches nothing shipped
— that is how you catch a typo, or a path that moved
in an upgrade.

Two things you cannot override: the Critical Safety
Rules in `AGENTS.md`, and whether a skill triggers at
all — a skill's description is matched before any of
your files are read. Trigger wording belongs in
`memory/custom-rules/all.md`, which is in context
from the start. Full rules: `rules/overrides.md`.

## Your own skills

A workflow Hostwarden does not ship goes into
`memory/.claude/skills/<name>/SKILL.md` and travels
with the workspace. Claude Code offers it as
`/memory:<name>` once the session has read your
memory, or at once after `/add-dir memory`. OpenCode
and Codex only find skills in the project's own
directories and in your home, so link it into
`~/.config/opencode/skills/` or `~/.agents/skills/`
there. To change what a shipped skill does, override
it as above instead — a copy stops receiving
updates.
