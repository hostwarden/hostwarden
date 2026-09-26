---
sidebar_position: 2
description: A copy of Hostwarden on your own git hosting, and a
  mirror that gates what production gets.
---

# Your own mirror

## A copy, or a gate

A mirror that is only a copy — a public one on your own git hosting,
say — needs no script. The pull mirror built into Forgejo and Gitea
copies branches and tags on an interval of its own, with nothing
between upstream and the copy; GitLab has one in Premium and
Ultimate. Forgejo sets one up only on a repository it creates for
it, not on one that exists already. Turn
Actions off in it: Forgejo, like GitHub, would otherwise run the
workflows Hostwarden ships, since it reads `.github/workflows/`
where a repository has no `.forgejo/workflows/`.

`bin/hostwarden-mirror` is for a mirror production clones from. It
moves only when its job runs, so the job is the gate, and it never
overwrites what the mirror has of its own.

## The mirror job

`bin/hostwarden-mirror` fast-forwards the mirror's `main` to
upstream's and pushes every tag it lacks. It needs git and nothing
else, so it runs from any CI or cron job — not from an operator's
machine: it refuses to run in an operations checkout. It never
overwrites: when the mirror's `main` has commits of its own, or a
tag of the mirror names another commit, it lists them, pushes
nothing and fails the job.

The token goes into `HOSTWARDEN_MIRROR_TOKEN`, the user into the URL,
so the token never lands on a command line. Run the job from a
repository other than the mirror, whose `main` has to stay
upstream's. Give the token write access to the mirror's contents —
on GitHub also to its workflows, since Hostwarden ships some — and
turn Actions off in the mirror, as above.

<details>
<summary>GitHub Actions (also Gitea and Forgejo Actions)</summary>

```yaml
name: hostwarden mirror
on:
  schedule:
    - cron: "17 3 * * *"
  workflow_dispatch:
permissions: {}
jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - run: git clone --depth 1 https://github.com/hostwarden/hostwarden.git
      - run: >-
          hostwarden/bin/hostwarden-mirror
          https://x-access-token@github.com/<org>/hostwarden-mirror.git
        env:
          HOSTWARDEN_MIRROR_TOKEN: ${{ secrets.HOSTWARDEN_MIRROR_TOKEN }}
```

</details>

<details>
<summary>GitLab CI</summary>

A pipeline schedule runs it, with the token as a masked CI/CD
variable:

```yaml
hostwarden-mirror:
  image:
    name: alpine/git
    entrypoint: [""]
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
  script:
    - git clone --depth 1 https://github.com/hostwarden/hostwarden.git
    - hostwarden/bin/hostwarden-mirror
      "https://oauth2@gitlab.example.com/<group>/hostwarden-mirror.git"
```

</details>

Production then clones the mirror instead of GitHub.
