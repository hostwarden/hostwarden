# Contributing

Bug reports, ideas and pull requests are welcome — better
guardrails, another distribution, a rule that caught you out.
For anything beyond a small fix, open an issue first, so the
approach is settled before the work is done.

Security problems are the exception: report them privately, as
[SECURITY.md](SECURITY.md) describes.

## Setup

Clone with symbolic links working. On native Windows that takes
three settings before cloning — README → Windows.

The checks need ShellCheck, actionlint and betterleaks, plus
`python3` and a POSIX shell. `mise.dev.toml` pins the versions
CI uses:

```bash
MISE_ENV=dev mise install
```

Any recent version works locally too:

```bash
brew install shellcheck actionlint betterleaks
```

Then let git run the checks for you, once per clone:

```bash
git config core.hooksPath .githooks
```

Every commit is then scanned for secrets, and every push runs
the full check first.

## Checks

```bash
sh scripts/check.sh
```

That is exactly what CI runs, so green here is green there. A
new check goes into that script, not into the workflow.

## What goes where

hostwarden's product is its instruction text, and where a new
instruction lives decides when it reaches a session. Read
[.claude/rules/instruction-authoring.md](.claude/rules/instruction-authoring.md)
before changing anything under `rules/`, `.agents/skills/` or
`AGENTS.md`: which of the four mechanisms fits, the 80-column
wrap, and the example identifiers allowed.

[.claude/rules/repo-release.md](.claude/rules/repo-release.md)
covers the rest: `VERSION` is not bumped in a pull request,
`CHANGELOG.md` gets an entry under `## Unreleased` written for
someone who uses hostwarden, and a change to the taboo guard
comes with a new line in its fixture matrix.

Working with an AI assistant is fine. It reads the same two
files through `AGENTS.md` and `CLAUDE.md`.

## Commits and pull requests

- [Conventional Commits](https://www.conventionalcommits.org/)
  for commit messages and pull request titles:
  `fix(email): queue mail when the relay is down`.
- Pull requests are squash-merged, so the title is what lands
  on `main`. Branch commits can be as small as you like.
- Nothing real in a commit, an issue or a pull request: no
  production hostnames, addresses, customer names or secrets.
  `server1.example.com`, `192.0.2.10` and `alice` are there for
  that.
