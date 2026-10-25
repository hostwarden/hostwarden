---
sidebar_position: 3
description: Runs the OpenTofu stacks and Ansible trees you keep,
  checks them before every plan, hands you every command whole,
  and grows from a workstation to a pipeline with federated
  credentials.
---

# Infrastructure code

Infrastructure as code is hard to hold in your head after a few
months away from it, and harder still for someone new to it.
Hostwarden keeps the code where your team can see it, runs the
checks that catch a mistake before a plan, shows you every command
it wants you to run as one line that works, and applies only what a
plan proves harmless — asked, every time.

## Where the code lives

The workspace, the git repository Hostwarden keeps your machine
memory in, is also where your infrastructure code lives, so a team
shares one place:

```
memory/infra/ansible/            your Ansible tree
memory/infra/opentofu/<stack>/   one OpenTofu root module, one state
memory/infra/opentofu/modules/   modules the stacks share
memory/infra/credentials.md      what each stack and pipeline
                                 authenticates with, and when it
                                 expires — never a value
```

A tree you keep in a repository of your own works too: you register
its path once on your machine, and Hostwarden reads, checks and
plans it there, edits it when you ask, and commits only when you
tell it to, that one commit — it never pushes.

Each tree carries a `hostwarden.md` with a few lines: how it is
applied (`Deployment: local`, `ci` or `mixed`), where its state is,
where its credentials come from, and which pipeline applies it.

## Two commands, for you and for Hostwarden

`bin/hostwarden-tofu` and `bin/hostwarden-ansible` run the tools with
everything a bare call forgets — this checkout's SSH options, the
tree's inventory and configuration, the plan file's place outside
the workspace, the credentials from your vault — and refuse what
Hostwarden must not run. A session runs them, and so do you: every
command Hostwarden wants you to run arrives as one line, complete,
with the absolute paths filled in, in a block the desktop app runs
on a click.

```bash
/srv/hostwarden/bin/hostwarden-tofu hosting plan
```

## Check before you plan

A plan against a cloud takes a minute and needs credentials; the
mistakes an agent makes — a wrong argument name, a resource that
does not exist, a security group open to the world — take seconds
to find without either. So `hostwarden-tofu <stack> check` runs
after every edit: `tofu fmt`, `init -backend=false`, `validate`,
then tflint, Trivy and Checkov where your workstation has them
(`mise install` in the checkout brings all of them at pinned
versions), and stops at the first failure. `hostwarden-ansible
check` does the same with `--syntax-check` and `ansible-lint`. Only
a tree that passes goes on to a plan or a diff.

## Plan, review, apply

1. **`plan`** saves the plan under `~/.cache/hostwarden/`, since
   a plan holds values in the clear, and prints one line: what it
   adds, changes, destroys, replaces.
2. **`review`** shows the plan as OpenTofu prints it, then every
   change by action, deletes and replaces first. Hostwarden tells
   you what it means in your terms: a replace of a server is a new
   server.
3. **`apply`**, two ways:
   - A plan that only adds and changes, on a tree you apply locally:
     Hostwarden's `apply` runs the saved plan — after the guard has
     asked you, with the stack named, this run and no other
     ([What it asks first](../../safety/approvals.md#applying-infrastructure-code)).
   - A plan that destroys or replaces anything, or a tree your
     pipeline applies: you apply. Hostwarden shows the exact
     command — the same program with a flag the guard denies the
     session — or the merge that starts the pipeline.

Afterwards a second plan has to show no changes, and each host the
stack touched gets its journal line and its `Provisioned by:` line.
`drift` tells you when the real resources differ from the state,
`test` runs your `tofu test` files only when they plan, or when
they mock every provider the tree uses, none of them aliased; one
that would apply for real is yours to run.

## The state

The default for a stack Hostwarden sets up is an S3 bucket with
OpenTofu's native lock (`use_lockfile`) and versioning, at AWS or
at any S3-compatible storage — Hetzner, Scaleway, OVHcloud,
Cloudflare R2, MinIO. The lock is what makes `Deployment: mixed`
safe: a plan on your workstation and an apply in the pipeline
share one state and never write over each other. Encrypting state
and plan is proposed once, like a missing firewall, and set up when
you say so. Hostwarden never prints a state, never writes one by
hand; `state rm`, `import`, a migration between backends are your
commands, shown whole.

## Credentials

The order, for every provider and every forge: federated first — a
pipeline authenticates with its forge's OIDC token to an AWS role, a
user-assigned managed identity in Entra or a Google workload
identity pool, and nothing is stored; on your workstation `aws sso
login`, `az login`, `gcloud auth login`. A certificate where
federation is not offered. A static token last, only where the
provider has nothing else — Hetzner Cloud, Scaleway, OVHcloud and
Cloudflare today — and only when you say so.

Where a value has to be stored, it is never in the tree and never
in the conversation. A team keeps it in the 1Password vault kept for
Hostwarden, one item per credential; the stack's `secrets.env` names
the items as `op://` references, and each workstation stores the
service account's token once. One person on one machine keeps a
personal file under `~/hostwarden-keys/`, mode 600. The wrappers
hand the values to the tool and print none.

`memory/infra/credentials.md` lists every credential with where it
lives and when it expires; housekeeping warns 30 days ahead. A
federated identity has nothing to expire and nothing to rotate,
which is the strongest reason to prefer it.

## From a workstation to a pipeline

Everything above works from one workstation. When you want a second
pair of eyes and a record, Hostwarden writes the pipeline — GitHub
Actions or GitLab CI — from a template, fills in your stack, your
provider's identity for a plan and for an apply, and the environment
that holds the approval, and tells you what the forge has to have: a
protected branch, required checks, an environment with reviewers and
a plan environment without them. It never sets those
itself, and it never runs the pipeline; it reads a red run and fixes
the tree.

The steps, each resting on the one before, named once when you ask
what is next:

1. A pipeline that checks and plans on every pull or merge request,
   and applies nothing.
2. The apply in the pipeline, behind an environment with reviewers,
   with federated credentials; the tree becomes `Deployment: ci` or
   `mixed`.
3. Policy as code on the plan, a scheduled drift run, signed
   commits.

For Ansible a hosted runner cannot reach your hosts, so a pipeline
lints and syntax-checks; an apply from a pipeline needs a
self-hosted runner that does, which your operations host can be,
with a deploy user of its own on each host.

## Getting started

- "Set up OpenTofu", "übernimm meine Terraform-Konfiguration",
  "leg einen Stack für Hetzner an" — the `hostwarden-opentofu`
  skill walks through adopting or creating a stack, its state, its
  credentials and its pipeline.
- "Take over my playbooks", "Ansible einrichten" — the
  `hostwarden-ansible` skill does the same for an Ansible tree.
- One step at a time, by name: `/hostwarden-opentofu hosting plan`,
  `/hostwarden-opentofu hosting review`, `/hostwarden-ansible diff
  site.yml --limit web1.example.com`. The skill runs that step
  through the wrapper and reports, nothing more.

Hostwarden never proposes either on its own: it runs the code you
keep.

Rules: `rules/infra-code.md`, `rules/opentofu.md`,
`rules/workspace-playbook.md`.
