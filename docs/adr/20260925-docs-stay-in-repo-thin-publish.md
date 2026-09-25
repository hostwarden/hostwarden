---
id: 20260925-docs-stay-in-repo-thin-publish
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [docs, release]
---

# Docs stay in this repo, only publishing lives elsewhere

## Context

Julian wants a Docusaurus documentation site reachable at
`hostwarden.github.io/docs`, and a stylish one-pager at the bare
domain in front of it (#312). GitHub Pages names a project site's
path after its repository — `hostwarden.github.io/hostwarden/` by
default — so only the org's one user-site repo,
`hostwarden/hostwarden.github.io`, can serve the bare domain and an
arbitrary `/docs` path. The 80-column wrap is not an obstacle
either — confirmed live against `bin/hostwarden-wrap`, which
already never touches a table, a code block or front matter.

## Decision drivers

- Docs must change atomically with the code that needs them, in one
  pull request.
- GitHub Pages project-site paths are fixed to the repository name;
  reaching `/docs` instead of `/hostwarden/` needs the org's one
  user-site repo.

## Considered options

### Content stays here; a thin repo only publishes it — chosen

`website/` in this repo holds the Docusaurus config, theme and
content, edited in the same pull requests as the code it documents.
`hostwarden/hostwarden.github.io` holds the one-pager and a publish
workflow that pulls that config and the current brand assets on
every dispatch and deploys the result — it never receives
hand-written content, only generated output and CI plumbing.

### A separate content repo for the whole docs site

Rejected. A development session's worktree only carries this
repository; reaching a second content repo for every docs edit
reopens the exact reliability gap the decision drivers name, and
would need each documented change to become two pull requests in
two repositories instead of one.

### Accept the default path and skip the second repo

Rejected. `hostwarden.github.io/hostwarden/` needs no second repo
at all, but Julian wants the one-pager at the bare domain and the
docs at exactly `/docs` — not negotiable in #312.

## Decision

`website/` stays in `hostwarden/hostwarden`. A new repo,
`hostwarden/hostwarden.github.io`, holds only the one-pager and the
publish workflow.

## Consequences

`website/docusaurus.config.js` sets `baseUrl: '/docs/'` on the
assumption that a downstream repo serves it there.
`.github/workflows/docs-publish-dispatch.yml` and the `release-cut`
step in `tag-release.yml` call
`.github/actions/dispatch-docs`, which targets
`hostwarden/hostwarden.github.io` and a `DOCS_DISPATCH_TOKEN`
secret; neither the repo nor the secret exists yet; both dispatches
are no-ops until they do (part of #312, not yet built). A proposal
to merge docs content into that second repo, or to accept the
default `/hostwarden/` path instead, is answered with this record.

## Confirmation

Editing `website/docs/` ever needs a second pull request, in
another repository, to actually reach a reader — the split has
stopped doing the one thing it was for.
