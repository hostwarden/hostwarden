# OpenTofu

Read when the user names an OpenTofu or Terraform stack, a host's
memory has a `Provisioned by:` line and a change touches what that
code owns, a change belongs in such code, or a pipeline that
applies one failed. `rules/infra-code.md` comes first: the trees,
the modes, the credentials and the commands shown to the user are
there. Everything here runs through `bin/hostwarden-tofu`, with the
stack's name as its first word; its `--help` says what each verb
runs and what it refuses. OpenTofu is the tool; a tree the user runs with
Terraform is read and changed the same way, and planned and applied by the user.

## What the code owns

A stack owns infrastructure: the instance and its size, the volume,
the cloud firewall, the network, the DNS record, the bucket, the
load balancer, the project's users and tokens. What runs inside the
machine — packages, services, their configuration — belongs to
Ansible or to a change by hand (`rules/config-management-changes.md`).
A change to something the code owns is made in the code, never in
the provider's console or CLI: the next apply would undo it, or
plan to. Where it is not clear which side owns a thing — a firewall
rule that both a cloud firewall and `ufw` could hold — ask.

## Before a change

The guard cannot read a resource, so the reading is what keeps the
taboos (`AGENTS.md` → Critical Safety Rules):

- Every `.tf` file the root module and its local modules hold, the
  `backend` block, the `required_providers`, every `lifecycle`
  block. A `prevent_destroy = true` is the user's decision and is
  never removed to make a plan go through.
- Every `provisioner`: `local-exec` runs a command on this
  workstation, `remote-exec` one on the server, `file` writes one
  there. A stack whose provisioner writes `sshd_config` or its
  drop-ins, an SSH key, `authorized_keys`, partitions or formats a
  disk, or halts the machine is never applied by Hostwarden, in
  check or for real: name it, and the user takes it out or applies
  the stack themselves. One that reaches the firewall or the
  network of a host Hostwarden administers is applied only as
  `rules/ssh-safety-net.md` says. The first-boot configuration a
  stack hands a new guest — `user_data`, cloud-init — is the one
  place sshd's options and keys may be set
  (`hostwarden-new-guest`).
- A `null_resource` or `terraform_data` with a provisioner is a
  script with a resource's name: read what it runs.
- A data source that reads a secret (`data "aws_secretsmanager_secret_version"`,
  a Vault or OpenBao data source) puts the value into the state
  (→ State).

Write with the module's documentation open, never from memory: the
provider's registry page for every resource and argument
(`AGENTS.md` → Verify Before Running), and the provider's version
pinned in `required_providers` with `~>` on the minor, the
`.terraform.lock.hcl` committed with the tree.

## Check, plan, review, apply

Every change goes through the four, in order, and stops at the
first that fails. The commands are the wrapper's; show the user
what each prints, not what it ran.

1. **Check** — `hostwarden-tofu <stack> check`: the static checks,
   with tflint, Trivy and Checkov where the workstation has them
   (`bin/hostwarden-doctor` names the missing ones). It needs no
   credentials and no state, so it runs after every edit the
   session makes, before anything else:
   a reference to a resource that does not exist, a wrong argument
   name, an open security group fall out here in seconds, not in a
   plan against the cloud. What it reports is fixed in the tree, or
   named to the user, before step 2. A checker's finding the user
   wants to keep is suppressed in the tree's own configuration
   (`.tflint.hcl`, `.trivyignore`, `.checkov.yml`), with the reason
   in a comment, never by skipping the checker.
2. **Plan** — `hostwarden-tofu <stack> plan`: init where the stack
   has none yet, then a plan saved under `~/.cache/hostwarden/`,
   outside the workspace, since a plan carries values in the clear.
   The wrapper prints one line: what the plan adds, changes,
   destroys and replaces. A plan that needs a variable takes it
   from a `.tfvars` file in the tree or `-var-file=`, never a
   secret in `-var` (`rules/secrets.md` → Never Pass Secrets on the
   Command Line).
3. **Review** — `hostwarden-tofu <stack> review`: the plan as OpenTofu
   prints it, then every change by action, deletes and replaces
   first. Read it as `rules/verify-before-reporting.md` reads a
   finding: a replace of a server is a new server with new host
   keys and an empty disk, however small the attribute that caused
   it; a change to a firewall or a network reaches SSH
   (`rules/ssh-safety-net.md`); a plan that destroys what the user
   did not ask to change points at drift or at an error in the code,
   and is not applied until that is understood. Tell the user what
   the plan does in their terms, with the replaces and destroys
   named, before anything is applied.
4. **Apply.** Two ways, by what the plan holds and by the tree's
   `Deployment:` line (`rules/infra-code.md` → Deployment modes):
   - **A plan that adds and changes only**, on a `local` or `mixed`
     tree: `hostwarden-tofu <stack> apply` applies the saved plan
     and nothing else, so what the user read is what runs, asked as
     `rules/infra-code.md` → Deployment modes says.
   - **A plan that destroys or replaces anything**: the user
     applies, through the same program with the flag the guard
     denies the session, shown whole (`rules/infra-code.md` →
     Commands the user runs):

     ```bash operator
     /srv/hostwarden/bin/hostwarden-tofu hosting apply --destroys
     ```

     On a `ci` tree, the merge or dispatch that starts the pipeline
     (`rules/infra-code.md` → Pipelines). A saved plan is good until
     the state moves; one applied after another run has changed the
     state is refused by OpenTofu itself, and the plan is made
     again.

   After an apply, `hostwarden-tofu <stack> plan` once more shows no
   changes, or the stack is not at rest: a resource a provider
   rewrites on every run is named to the user as such, not applied
   again. Then the records (→ Records).

A host Hostwarden administers that the plan replaces or deletes is
a host whose session register is read first
(`rules/parallel-sessions.md` → The register) and whose blast radius
is announced (`rules/coordination.md` → Announce, wait, go); after a
replace, its host key is new (`rules/host-keys.md` → A Changed Key),
and its memory says what happened.

## Drift

`hostwarden-tofu <stack> drift` exits 4 when the real resources
differ from the state, by a change made in a console or by another
tool. Run it when a host's facts
disagree with its stack, before a change to a stack nobody applied
for a while, and in the housekeeping of a host whose memory has a
`Provisioned by:` line. Drift is reported, never applied over: the
user decides whether the code or the resource is right, and a
`plan` shows what either way would change.

## Tests

`tofu test` applies by default — it creates the resources a test
needs and destroys them after — so `hostwarden-tofu <stack> test`
runs only a test whose every `run` block has `command = plan`, or
whose file mocks (`mock_provider`) every provider the tree
requires or uses, each without an alias, with no `provider` block
and no `providers` mapping in the file, in a tree with no
`provisioner`, which runs its command for real under any mock, and
refuses any other, a test directory of its own included, with the
file named. An apply test is the
user's to run, on a
stack and an account meant for it: `hostwarden-tofu <stack> test
--applies`, which the guard denies the session.

## State

The state holds every attribute of every resource, secrets in the
clear among them (`rules/secrets.md` → What Counts as a Secret). So:

- **Remote, locked, versioned.** The default for a stack Hostwarden
  sets up is an S3-compatible bucket with OpenTofu's native lock
  (`use_lockfile`, OpenTofu 1.10 or newer) and versioning as the
  undo; the `backend` blocks for AWS and for S3-compatible storage
  are in the `hostwarden-opentofu` skill's
  `references/state-backends.md`, every flag from the provider's
  documentation. A local state is for a stack one person runs on
  one machine, and never for a tree in a shared workspace: the
  state file would land in the repository. A `Deployment: mixed` or
  `ci` tree has a remote state with a lock, or it has no such line.
- **Encrypted.** OpenTofu encrypts state and plan at rest with an
  `encryption` block — a key from PBKDF2, a KMS or OpenBao, AES-GCM
  as the method. A stack without one is a finding, reported once
  with what it buys, like a missing firewall
  (`rules/baseline.md`), and set up only when the user asks: the
  key then lives outside the tree, in the vault the credentials come
  from, and losing it loses the state.
- **Never printed.** `state pull`, `show -json`, `output -json` and
  `output -raw` print values unredacted; the wrapper reads the plan's
  JSON only into `jq` for its summary, and the guard denies the
  rest. `output`, with or without a name, redacts what the code
  marks `sensitive`; mark every secret output so. Redaction covers
  what the provider's schema and the code mark: a secret in an
  unmarked attribute, a `user_data` string say, shows in `review`, in
  `state show` and in a pipeline's plan comment. A secret reaches the
  code as a sensitive variable.
- **Never written by hand.** `state rm`, `state mv`, `import`,
  `taint`, `force-unlock`, `workspace delete`, a migration between
  backends (`init -migrate-state`): the user's commands, at a
  terminal, shown whole. A `moved` or `import` block in the code is
  the way to rename or adopt a resource through a plan the user
  reads; write that instead.

## Providers

Each provider's credential follows `rules/infra-code.md` →
Credentials: federated where the provider offers it, static where
it does not, and the register names every one.

What each provider federates with, and which environment variable
a static token goes into, is in the `hostwarden-opentofu` skill's
`references/credentials.md`; AWS, Azure and Google Cloud federate,
Hetzner Cloud, Scaleway, OVHcloud and Cloudflare take static tokens
today. A static token is scoped to one project or zone, read and
write only where the stack writes, and has an expiry in the
register. A variable's name and a provider's S3 flags come from the
provider's current documentation at the time of writing the stack,
as `rules/version-check.md` → Version Check Procedure finds a
version.

## Terragrunt

A stack with a `terragrunt.hcl` runs through Terragrunt, the
wrapper sees to it, and the four steps stay the same. Terragrunt
is proposed once, in one line, when the user starts a new tree
from nothing and will have more than one stack sharing a backend
and providers; it is never required, never added to a tree the user
brought, and `run --all`, `run-all` and `stack run` over every
stack at once stay the user's (the guard denies them).

## Adopting a stack

A stack the user already has — in a repository of their own, or
one they copy into `memory/infra/opentofu/<stack>/` — is read as
→ Before a change says, its `hostwarden.md` written with the user
(the deployment mode, the state as the `backend` block shows it,
where its credentials come from), its credentials entered in the
register, and `check` run once. Nothing in it is changed to fit
Hostwarden: a stack that works is adopted as it is, and the first
`plan` has to show no changes before anything else is done. The
`hostwarden-opentofu` skill walks through this and through a new
stack.

## Existing resources

Resources that exist at a provider and are not in code yet are
brought in by `import` blocks and `hostwarden-tofu <stack> generate`,
one slice at a time: `rules/infra-migration.md`.

## Records

- Every host the plan changed, replaced or created gets a journal
  line and its memory updated (`rules/changelog.md`,
  `rules/machine-memory.md`): a `Provisioned by: opentofu (<stack>)`
  line naming the stack, as `rules/config-management-leads.md` →
  Ask once, record spells it; what the stack owns on it; after a
  replace, that the host is new.
- The changelog entry's `Source:` names the stack and the
  workspace commit of its tree, or the external repository's
  commit, and the plan's summary line:

  ```markdown
  [2026-10-25 14:02] hosting: resized web1.example.com to cx32
    — load above 80 % for two weeks
    Source: infra/opentofu/hosting @ 3f9c2d1e (plan: 0 to add, 1 to
    change, 0 to destroy, 0 to replace)
  ```

- A credential the stack started using goes into the register
  (`rules/infra-code.md` → Credentials).
- The workspace commit as `rules/changelog.md` → The Workspace
  says; a commit in an external repository only as
  `rules/infra-code.md` → Commits allows.
