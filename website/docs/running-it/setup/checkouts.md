---
sidebar_position: 1
sidebar_label: The operations checkout
description: What makes a checkout the one that administers your
  servers, and where a production clone comes from.
---

# The operations checkout

A Hostwarden checkout that administers servers is an **operations
checkout**, and the workspace is what makes it one.

`memory/` is the workspace (`bin/hostwarden-init`). Once it exists,
Hostwarden's own files are read-only: the auto-update keeps working,
and any change to Hostwarden itself goes through review rather than
an edit in place. A checkout without a workspace, and every git
worktree, is a **development checkout** instead: it works on
Hostwarden's own source and reaches no server. See
[Working on Hostwarden](../../development/index.md).

## Where production comes from

Production runs a **clone** — of `hostwarden/hostwarden` itself, or
of a mirror of your own.

- **Straight from GitHub** is the default and needs nothing else.
- **A mirror of your own** is optional. It is worth it when
  Hostwarden has to come from your internal git hosting, when an
  update should reach production only once your mirror has taken it
  (the mirror job is the gate), or when you carry local patches.
  Name it `hostwarden-mirror`. Its `main` stays an exact copy of
  upstream's so the mirror job can keep it current; patches of your
  own go on a branch of their own, and a checkout on that branch
  gets no auto-update. See [Your own mirror](mirror.md).
- **A GitHub fork is not a production copy.** It exists to send pull
  requests: a fork of a public repository cannot be private, and an
  owner gets one fork of a repository, which pull requests need.

These names are recommendations. Nothing checks them: the workspace
alone decides whether a checkout runs production, as described above.
