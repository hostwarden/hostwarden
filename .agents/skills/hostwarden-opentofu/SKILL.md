---
name: hostwarden-opentofu
argument-hint: "<stack> <step> [args]"
description: Set up an OpenTofu stack Hostwarden runs — take over a
  configuration the user already has, or start one from nothing —
  with its remote state (an S3 bucket by default), where its
  credentials come from (1Password, a personal file, federated
  identities in a pipeline), the checkers that run before every plan,
  an optional Terragrunt layout, and a GitHub Actions or GitLab CI
  pipeline that plans on a request and applies behind an approval.
  Use when the user asks to "set up OpenTofu", "take over my
  Terraform code", "adopt my tofu stack", "create a stack for
  <provider>", "move the state to S3", "set up the pipeline for
  <stack>", "how do I give the pipeline access without a secret",
  "OpenTofu einrichten", "übernimm meine Terraform-Konfiguration",
  "leg einen Stack für Hetzner an", "State nach S3 umziehen", "die
  Pipeline für <stack> einrichten". With a stack and one of the
  wrapper's verbs as arguments — "/hostwarden-opentofu hosting plan",
  "/hostwarden-opentofu hosting review", "/hostwarden-opentofu hosting
  drift" — it runs that one step of `rules/opentofu.md` and reports.
  Not for Ansible (`hostwarden-ansible`).
---

# hostwarden-opentofu

**Overrides.** Load them before anything else, key
`hostwarden-opentofu`, per `rules/overrides.md`.

Read `rules/infra-code.md` and `rules/opentofu.md` first: the
trees, the modes, the credentials, the four steps and what the
session never runs are there, and nothing here repeats them. This
skill is the setup — a stack that exists afterwards is worked on
through the rule alone.

Everything the user runs is shown whole, in a fenced block with the
`operator` marker (`rules/infra-code.md` → Commands the user runs);
everything the session runs goes through `bin/hostwarden-tofu`. A
version — OpenTofu's, a provider's, Terragrunt's — comes from a live
lookup (`rules/version-check.md`), and every resource and backend
argument from the provider's current documentation, never from
memory.

## Arguments

The first word is the stack, as `bin/hostwarden-tofu` takes it; the
second the step; the rest go to the wrapper as they stand.

- **A wrapper verb** — `check`, `plan`, `review`, `apply`, `drift`,
  `test`, `output`, `state list`, `state show` — runs that step of
  `rules/opentofu.md` → Check, plan, review, apply on that stack and
  nothing else, under that step's conditions:
  `/hostwarden-opentofu hosting plan` plans, shows the summary line
  and stops. An argument the wrapper refuses is refused here too,
  with the reason.
- **A setup way** — `adopt`, `new`, `state`, `credentials`,
  `pipeline` — starts there (below). Without a stack, `new` asks for
  its name first; `adopt` takes the path or the stack.
- **No arguments**: the question below.

## Which way in

Ask once, in the interview format of `rules/ssh-user.md`, unless the
request or the arguments already say:

1. **Adopt** — the user has a stack, in a repository of their own or
   to be copied into the workspace.
2. **New** — a stack from nothing, for a provider the user names.
3. **State** — move or set up the state of a stack that exists.
4. **Credentials** — set up or change where a stack's credentials
   come from, on this machine or for a team.
5. **Pipeline** — a pipeline for a stack that exists.

A new stack walks through all five in that order; the others start
where they are named.

## Adopt

1. **Where it lives.** In the workspace,
   `memory/infra/opentofu/<stack>/`, one root module per directory —
   the default, and where a team shares it. Or where it is: then
   the user names the absolute path of the root module, and the
   session writes the line into `memory/user.md` under
   `# Infrastructure code` (`rules/infra-code.md` → Trees). A
   repository with several root modules gets one line per module.
   Copying a tree into the workspace copies the code, never a
   `.terraform/` directory, a `terraform.tfstate` or a `.tfplan`
   (`templates/workspace/.gitignore`).
2. **Read it** as `rules/opentofu.md` → Before a change says, and
   tell the user what the stack owns, which provider it uses, where
   its state is as the `backend` block shows, and what the
   provisioners run, in a few lines. A local state in a tree that is
   going into the shared workspace is moved first (→ State), or the
   tree stays outside.
3. **Write `hostwarden.md`** with the user: `Deployment:` as they
   apply today, `State:` as the backend block shows, `Credentials:`
   as they come today (→ Credentials fixes what is loose), and
   `Pipeline:` where one exists.
4. **Check**: `bin/hostwarden-tofu <stack> check`. What it reports is
   named, not fixed: an adopted stack is changed only when the user
   asks, and a finding of tflint, Trivy or Checkov in code that works
   is a list for the user, with the one line each would take to
   suppress in the tree's own configuration where the user wants to
   keep it.
5. **The first plan has to show no changes.** Where it shows some,
   the stack and the real resources have drifted, or a variable
   differs from the one the user applies with: stop there, show the
   plan, and settle it with the user before anything else. Only a
   stack at rest is adopted.
6. **Record.** Every host the stack created gets its
   `Provisioned by: opentofu (<stack>)` line
   (`rules/opentofu.md` → Records); every credential the stack
   uses goes into `memory/infra/credentials.md`
   (`rules/infra-code.md` → Credentials); a journal line on each
   such host says the stack is now run through Hostwarden.

## New

1. **The questions**, together, in one message: the provider, what
   the stack is to hold at first (one server, a firewall, a DNS
   zone), where the state goes (an S3 bucket, → State), where the
   credentials come from (→ Credentials), how it is applied
   (`local` to begin with, unless the user already has a pipeline
   in mind), and — only when the user expects more than one stack
   sharing a backend and providers — whether to lay the tree out for
   Terragrunt (`rules/opentofu.md` → Terragrunt), one line on what
   it buys.
2. **The tree**, under `memory/infra/opentofu/<stack>/`:
   `versions.tf` with `required_version` and the providers pinned
   `~>` on the minor, `backend.tf` from → State, `variables.tf`,
   `main.tf` with the first resources, `outputs.tf` with every
   secret output marked `sensitive`, `.tflint.hcl` with the
   provider's ruleset, `hostwarden.md` with the four lines,
   `secrets.env` where → Credentials needs one, and a `README.md`
   that says in five lines what the stack owns and how it is
   applied. Every argument from the provider's documentation
   (`hostwarden-tofu <stack> check` finds the ones that are not).
3. **Check, plan, review** as `rules/opentofu.md` → Check, plan,
   review, apply says. A first plan adds only, so
   `hostwarden-tofu <stack> apply` is the usual way, asked; a
   `ci` tree waits for → Pipeline.
4. **Record** as Adopt step 6 says.

## State

The default is an S3-compatible bucket with native locking and
versioning; `references/state-backends.md` has the `backend` block
for AWS and for the S3-compatible storage of Hetzner, Scaleway,
OVHcloud, Cloudflare and MinIO, what the bucket needs, and the
`encryption` block.

- **The bucket exists first**, made by the user in the console or
  by a bootstrap stack of its own with a local state the user keeps
  outside the workspace — a state cannot hold the bucket it lives
  in. Versioning on, public access off, one bucket or one prefix
  per team; the key is `<stack>/terraform.tfstate`.
- **Moving a state** — from local to the bucket, or between buckets
  — is the user's command, shown whole after the `backend` block is
  in the tree (`references/state-backends.md` → Moving a state).
- **Encryption** of state and plan is proposed once, as a finding
  is (`rules/opentofu.md` → State), set up when the user says so,
  with the key in the vault the credentials come from.
- **`State:`** in `hostwarden.md` records the result.

## Credentials

`rules/infra-code.md` → Credentials sets the order: federated
first, a certificate second, a static token last.
`references/credentials.md` has, per provider and per forge, what to
create and the commands the user runs to create the trust, and the
`secrets.env` lines for the providers that take a token.

1. **The provider's side.** What the stack authenticates with on
   this machine: a login the user already has (`aws sso login`,
   `az login`, `gcloud auth login`) needs nothing stored; a static
   token is made by the user in the provider's console, scoped to
   the project and to read-write only where the stack writes, with
   an expiry.
2. **Where it lives.** For a team, the 1Password vault kept for
   Hostwarden, one item per credential, and the stack's
   `secrets.env` with the `op://` references; each machine stores
   the service account's token once
   (`bin/hostwarden-password token 1password`,
   `rules/ssh-passwords.md` → Passwords in a Manager). For one
   person on one machine, `~/hostwarden-keys/infra/opentofu/<stack>/env`,
   created empty and mode 600 first, filled in an editor. Never a
   value in the tree, never one in the conversation.
3. **The register.** Every credential becomes an entry in
   `memory/infra/credentials.md` (`rules/infra-code.md` →
   Credentials).
4. **`Credentials:`** in `hostwarden.md` records the source.

## Pipeline

`references/pipeline.md` says how a template from
`templates/pipelines/` becomes the tree's pipeline, what the forge
has to have before the first run, and how the OIDC trust is created
for each provider; `rules/infra-code.md` → Pipelines says what the
session does with a pipeline afterwards.

1. **The forge and the repository**: the workspace's own remote for
   a tree in it, the tree's repository otherwise. Without a remote
   there is no pipeline; say so, and leave the stack `local`.
2. **The stage** (`rules/infra-code.md` → Growing): first a pipeline
   that checks and plans on every request and applies nothing;
   then, when the user asks, the apply behind an environment with a
   reviewer. A `Deployment: ci` line is written only with the second.
3. **Credentials for the runner**: the trust at the provider,
   created by the user with the commands the reference gives, two
   of them: a plan role that reads, and an apply role that writes,
   each filled into the workflow as the role, identity or pool; a
   static token goes into the forge's environment secrets by the
   user's hand, and the register names where it lives.
4. **Fill in** the template, write it where the forge reads it,
   and show the user what the forge has to have set — a protected
   default branch, the required checks, the environment with its
   reviewers, and on GitHub the plan environment without them — as a
   list of settings, each with where to click or
   the `gh`/`glab` command that sets it, in a block of its own.
5. **The first run** is a request the user opens; the session reads
   it (`rules/infra-code.md` → Pipelines) and fixes what is red in
   the tree or the workflow. `Pipeline:` and `Deployment:` in
   `hostwarden.md` record the result; the workspace commit as
   `rules/changelog.md` says, a commit in an external repository
   only on the user's word.

## Never

- Never propose this skill: a stack is set up when the user asks
  (`rules/config-management.md` → Never push for one).
- Everything else the setup must not do is the rule's and the
  wrapper's: `rules/opentofu.md` → Before a change and → State,
  `rules/infra-code.md` → Credentials, `bin/hostwarden-tofu --help`.
