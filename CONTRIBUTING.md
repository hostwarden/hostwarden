# Contributing

For anything beyond a small fix, open an issue first, so the
approach is settled before the work is done. Security problems go
privately, as [SECURITY.md](SECURITY.md) describes.

## Setup

Clone with symbolic links working; native Windows needs three
settings first (README → Windows). The checks need ShellCheck,
actionlint, betterleaks and `python3`. `mise.dev.toml` pins the
versions CI uses; mise asks you to trust it once:

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

## Checks

```bash
sh scripts/check.sh
```

That is what CI runs.

## What goes where

Two files in `.claude/rules/` hold the conventions for changing
this repository, and the `paths` at the top of each lists the
files it governs. Read the one that covers what you change:
[instruction-authoring.md](.claude/rules/instruction-authoring.md)
for the instruction text — where a new instruction belongs, the
wrap, the example identifiers allowed — and
[repo-release.md](.claude/rules/repo-release.md) for releases,
CI and the checks. Claude Code loads them on its own; every
other tool has to be pointed at them.

## Commits and pull requests

[Conventional Commits](https://www.conventionalcommits.org/)
for commit messages and pull request titles. Pull requests are
squash-merged, so the title is what lands on `main`.
