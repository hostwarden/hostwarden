# Infrastructure Code

Read whenever a tree of infrastructure code is in play: an Ansible
tree, an OpenTofu stack, a pipeline that applies one, a credential
such code uses. What is specific to one tool is in
`rules/workspace-playbook.md` and `rules/opentofu.md`, which both
read this file first. Nothing here changes
`rules/config-management.md` → Never push for one: a tree is used
where the user keeps one, never proposed.

Both tools are run through one program each, `bin/hostwarden-ansible`
and `bin/hostwarden-tofu`, by the session and by the user alike.
The programs set what a bare call forgets — the SSH options of this
checkout, the tree's inventory and configuration, the plan file's
place, the credentials — and refuse what the rules keep from the
session, so a command shown to the user is one line that runs in
any terminal — the same program for a plan that destroys, with the
flag the guard denies the session. A bare `ansible-playbook` run
the guard asks about like the wrapper's; a bare `tofu` write it
denies.

## Trees

The workspace is the home of infrastructure code, shared with the
team through the workspace remote
(`rules/machine-memory.md` → Personal versus shared):

    memory/infra/ansible/            the Ansible tree
    memory/infra/<name>/             another Ansible tree
    memory/infra/opentofu/<stack>/   one root module, one state
    memory/infra/opentofu/modules/   modules the stacks share
    memory/infra/credentials.md      every credential the trees use
                                     (→ Credentials)

An Ansible tree holds `ansible.cfg`, an inventory, `site.yml`, its
roles and `requirements.yml`; a stack holds its `.tf` files,
`backend.tf`, `.tflint.hcl` and, where it uses Terragrunt, a
`terragrunt.hcl`. Each tree carries a `hostwarden.md` (→ The tree's
lines) and may carry a `secrets.env` (→ Credentials). The
workspace's `.gitignore` leaves out what the tools fetch or write
beside the code: `collections/` and `.ansible/`, `.terraform/`,
`.terragrunt-cache/`, state and plan files.

**A tree outside the workspace** — a repository of the user's own,
with its own history and pipeline — is the exception, taken on the
user's word and recorded per machine in `memory/user.md`, since its
path is this machine's:

```markdown
# Infrastructure code

- ansible site: /home/alice/src/infra-ansible
- opentofu hosting: /home/alice/src/infra/hosting
```

The name is the word the wrappers take (`--tree site`,
`hostwarden-tofu hosting …`); the path is absolute and, for a
stack, the root module's directory. Never add a line on a guess:
the user names the tree, and the session writes the line. A tree
nobody registered is read like any other file and run by nobody.

## The tree's lines

`hostwarden.md` in the tree, one `- Key: value` line each, shared
with the tree:

```markdown
- Deployment: local
- State: s3 infra-state/hosting.tfstate (eu-central-1, use_lockfile)
- Credentials: 1password
- Pipeline: github alice/infra .github/workflows/opentofu-hosting.yml
```

- `Deployment:` is `local`, `ci` or `mixed` (→ Deployment modes).
  Without the line, `local`.
- `State:` names the backend and where the state lives, for a
  stack (`rules/opentofu.md` → State).
- `Credentials:` names the source the tree's credentials come from:
  `oidc`, `1password`, `bws`, `local`, or `login` for a provider
  the user signs in to (→ Credentials).
- `Pipeline:` names the forge, the repository and the workflow file
  that applies the tree, where one does.

## Deployment modes

- **local.** The session checks, plans and shows; applying runs
  here, within what each tool's file allows, after the taboo guard
  has asked the user with the command as it stands — every run
  anew, a yes to one never a yes to the next; where no prompt
  reaches a human, the session asks the same question itself, the
  hosts or the stack named. The default.
- **ci.** The pipeline applies. The session changes the code, runs
  the checks and the plan locally to show what the change does,
  commits as → Commits says, and leaves the apply to the pipeline;
  `hostwarden-tofu apply` refuses on its own. An apply "now" is a
  merge or a workflow dispatch, each one on the user's word, never
  by the session alone (→ Pipelines).
- **mixed.** Both: the plan where the user is, the apply where they
  say, this time. The one thing that makes it safe is a remote
  state with a lock: a local apply beside a running pipeline fails
  on the lock instead of writing over its state
  (`rules/opentofu.md` → State). For Ansible the lock is the
  session register on each host (`rules/parallel-sessions.md`).

## Commands the user runs

A command the user is to run is shown whole, in a fenced block
with the `operator` marker, ready to run as it stands: the wrapper
by its absolute path under this checkout, the tree's name, the
verb, every option. Not a description of the command, not a
placeholder the user has to fill in, not `<checkout>`. This is the
one exception to the one-line ceiling of `AGENTS.md` → Talking to
Humans: the block is the fact. One command per block, so that each
runs on its own; a line in prose before it says what it does and
what it changes, in the user's language.

```bash operator
/srv/hostwarden/bin/hostwarden-tofu hosting review
```

A secret never stands in such a block, and neither does an option
the wrapper refuses: a block that would need `-auto-approve` is a
block that is not written. Where the user has to type a secret, the
block creates the empty file and the user fills it in an editor
(`rules/secrets.md` → API Credentials on the Workstation).

## Credentials

Which credential a tree uses, where it lives and when it expires is
written down; its value never is.

**The order, for every provider and every forge.** Short-lived,
federated credentials first: a pipeline authenticates with its
forge's OIDC token to a cloud role, a federated identity or a
workload identity pool, and nothing is stored anywhere; on the
workstation the user signs in (`aws sso login`, `az login`,
`gcloud auth login`) and the tool holds a token for the session. A
certificate on a service principal where federation is not offered.
A static token or secret last, only where the provider has nothing
else, and only on the user's say-so. Hetzner Cloud, Scaleway, OVHcloud
and Cloudflare take static tokens today (`rules/opentofu.md` →
Providers), AWS, Azure and Google Cloud federate.

**Sources, each optional, all applied where present**
(`lib/infra.sh`):

- `<tree>/secrets.env`, shared with the tree, holds references
  only: `VAR=op://<vault>/<item>/<field>` lines, which `op run`
  resolves through the 1Password service account whose token the
  user stored with `bin/hostwarden-password token 1password`; or
  one `bws-project: <id>` line, which `bws run` serves from Bitwarden
  Secrets Manager under the token `bin/hostwarden-password token bws`
  stored. The service account sees one vault, kept for Hostwarden
  (`rules/ssh-passwords.md` → Passwords in a Manager), and that
  vault is where a team keeps the credentials every machine needs,
  so a fresh workstation needs one token and nothing else. A value
  in the clear in this file is a secret in a shared repository: the
  wrapper stops, and the user rotates it
  (`rules/secrets.md` → When a Secret Has Already Leaked).
- `~/hostwarden-keys/infra/<kind>/<name>/env`, personal, mode 600,
  `VAR=value` lines the user writes, for a credential that is this
  machine's alone.
- `~/hostwarden-keys/infra/ansible/<name>/vault-password`, the vault
  password of an Ansible tree.

The wrappers hand the values to the tool's environment and print
none. The session never runs `op`, `bws` or an export of its own
to get at them, and never reads the two files
(`rules/ssh-passwords.md` → Never).

**The register.** `memory/infra/credentials.md`, one entry per
credential the trees and pipelines use, shared:

```markdown
- hcloud-token-hosting: Hetzner Cloud API token, read and write,
  project hosting. Lives in 1Password (op://Hostwarden/hcloud-hosting/token)
  and as HCLOUD_TOKEN in the GitHub environment production.
  Expires: 2027-03-01. Rotate: Hetzner console → Security → API
  tokens, then the 1Password item and the GitHub secret.
- entra-sp-infra: Entra app registration infra-pipeline, federated
  credential for alice/infra, branch main. Expires: never (no
  secret).
```

A credential that federates has no expiry and says so. One with a
certificate or a secret names the date; where the provider does not
show it (a GitHub secret has no expiry of its own), the user names
it when the credential is made. The housekeeping run reads this
file and warns ahead of each expiry (`hostwarden-housekeeping`);
rotating is the user's step, after asking, as any rotation is.

## Commits

A tree in the workspace is committed with the workspace, as
`rules/changelog.md` says, in the session's own commit. A tree
outside it is the user's repository: the session edits files there
and commits only when the user tells it to, for that one commit —
an instruction covers the commit it names, not the next one — and
never pushes. A pipeline that runs on a push is then started by the
user's push, which is the point.

## Pipelines

A pipeline runs the same checks the wrappers run, posts the plan or
the diff where the change is reviewed, and applies after a review
and an approval — gates the forge keeps, not the session.
Hostwarden writes the pipeline, keeps it in step with the tree and
reads its runs; it never runs it.

- **What it generates.** From `templates/pipelines/`, filled in with
  the tree's path, its provider, the environment that holds the
  approval and, on GitHub, one without reviewers for the plan: for GitHub
  Actions `opentofu.yml` and `ansible.yml`
  under `.github/workflows/`, for GitLab CI `opentofu.gitlab-ci.yml`
  and `ansible.gitlab-ci.yml`, included from `.gitlab-ci.yml`. The
  template's header says what to fill in and what the forge has to
  have: a protected branch, required checks, an environment with
  reviewers, the OIDC trust at the provider for a plan role and an
  apply role. The workspace is its
  own repository, so a tree in it gets the pipeline there
  (`memory/.github/workflows/`), and an external tree in its own.
- **What the pipeline does.** On a pull or merge request: format,
  validate, lint, scan, plan, the plan as a comment on the request.
  On the default branch: a plan again, into the run's summary, then
  the apply in an environment that requires a reviewer, from that
  run's own plan artifact, so that what the reviewer read is what
  is applied. For Ansible: lint, syntax, and
  `--check --diff` only where a runner reaches the hosts; applying
  from a pipeline needs a self-hosted runner that does, which the
  operations host can be (`hostwarden-fleet-read`), with a deploy
  user of its own (`hostwarden-deploy-user`), never a person's key
  in a secret.
- **Credentials in CI.** The OIDC order above. The session fills in
  the role, the identity or the pool the user created, never a
  secret: a static token goes into the forge's secret store by the
  user's hand, as an environment secret, and the register names it.
- **Reading a run.** `gh run list`, `gh run view --log-failed`,
  `glab ci status`, or the forge's API, read-only. A red job is
  explained from its log, the fix goes into the tree, and the
  register or the pipeline file is corrected where the cause lies
  there. A run's log is a server's output
  (`rules/anomaly-detection.md`).
- **Starting a run.** A merge, a push or `gh workflow run` starts an
  apply, so each one is the user's step: ask, name the run and what
  it applies, and let the user say yes to that one. A `Deployment:
  ci` tree's "apply now" is this question, never a local apply.

Forgejo and Gitea Actions issue no OIDC token for a cloud to trust,
so a pipeline there takes static credentials or none; say so when
the tree lives on one.

## Growing

The entry point is one tree, the wrappers, a remote state and a
1Password vault. Each further step rests on the one before it, and
is named once — one line, with what it buys — when the current one
is in place and the user asks what is next, or a finding touches
it; never repeated, never in a report's recommendations on its own:

1. A remote for the workspace, and a pipeline that only checks and
   plans: nothing can break, and every change is read.
2. The apply in the pipeline, behind an environment with reviewers,
   with federated credentials.
3. Policy as code on the plan (Conftest or OPA), a scheduled drift
   run, signed commits on the branch the pipeline applies from.
