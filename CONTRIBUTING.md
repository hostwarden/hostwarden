# Contributing

For anything beyond a small fix, open an issue first, so the
approach is settled before the work is done. Security problems go
privately, as [SECURITY.md](SECURITY.md) describes.

## Setup

Work in a development checkout: a clone of Hostwarden, or of your
fork, without `bin/hostwarden-init`
([docs/operations.md](docs/operations.md#operations-and-development)).
One git worktree per branch keeps parallel sessions apart;
[docs/project-structure.md](docs/project-structure.md) says where
things live.

Clone with symbolic links working, on Windows inside WSL 2
(docs/install.md → Windows). The checks need
ShellCheck, actionlint, betterleaks and `python3`. `mise.dev.toml`
pins the versions CI uses; mise asks you to trust it once:

```bash
mise trust mise.dev.toml
MISE_ENV=dev mise install
```

Any recent version from your package manager works too. Once per
clone, let git run the checks — a secret scan on every commit,
and before every push what the pushed commits need:

```bash
git config core.hooksPath .githooks
```

To try a command on a Linux family instead of guessing its
syntax, install docker or podman (OrbStack provides docker on
macOS); `bin/hostwarden-lab` runs disposable containers with it.
What only a full VM can answer goes to a test clone
([docs/operations.md](docs/operations.md#operations-and-development)).

The CLI of the second reviewer — currently the
[Codex CLI](https://github.com/openai/codex), signed in — is
optional: with it, an agent session runs the second review of its
pull request locally instead of asking for one on GitHub
([pull-requests.md](.claude/rules/pull-requests.md#the-second-review)).

## Checks

```bash
sh scripts/check.sh
```

That is what CI runs. An agent session runs only its secret scan,
`sh scripts/check.sh --pre-commit`, and not the hooks above: it
pushes and reads CI
([pull-requests.md](.claude/rules/pull-requests.md#checks)).

## What goes where

The files in `.claude/rules/` hold the conventions for changing
this repository, and the `paths` at the top of each lists the
files it governs. Read the one that covers what you change:

- [instruction-authoring.md](.claude/rules/instruction-authoring.md)
  for the instruction text — where a new instruction belongs, the
  wrap, the example identifiers allowed;
- [repo-release.md](.claude/rules/repo-release.md) for releases,
  CI and the checks;
- [pull-requests.md](.claude/rules/pull-requests.md) for taking a
  pull request from open to merged, checks included.

Claude Code loads them on its own; every other tool has to be
pointed at them.

## Commits and pull requests

[Conventional Commits](https://www.conventionalcommits.org/)
for commit messages and pull request titles. Pull requests are
squash-merged, so the title is what lands on `main`. Update a
branch by rebasing it on `main`, never by merging `main` into it.
