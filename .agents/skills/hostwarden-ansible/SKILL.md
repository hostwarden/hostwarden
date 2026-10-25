---
name: hostwarden-ansible
argument-hint: "[--tree <name>] <step> [playbook] [args]"
description: Set up an Ansible tree Hostwarden runs — take over the
  playbooks and roles the user already has, or start a tree from
  nothing — with its inventory, its vault and where the vault's
  password lives (a personal file, or a 1Password vault a team
  shares), the lint profile and the checks that run before every
  diff, and a GitHub Actions or GitLab CI pipeline that lints and
  checks on every request. Use when the user asks to "set up
  Ansible", "take over my playbooks", "adopt my Ansible repo", "start
  an Ansible tree for the web servers", "where does the vault
  password go", "set up the Ansible pipeline", "Ansible einrichten",
  "übernimm meine Playbooks", "leg ein Ansible-Verzeichnis für die
  Webserver an", "Vault-Passwort hinterlegen", "die Ansible-Pipeline
  einrichten". With one of the wrapper's verbs as arguments —
  "/hostwarden-ansible check", "/hostwarden-ansible diff site.yml
  --limit web1.example.com", "/hostwarden-ansible verify site.yml" —
  it runs that one step of `rules/workspace-playbook.md` and
  reports. Also for turning what a host runs today, set up by hand or
  by Hostwarden, into a role that describes it, for example "put the web
  server's configuration into Ansible", "hand web1 over to Ansible",
  "write a role from what runs on db1", "die Konfiguration von web1
  in Ansible überführen", "aus dem laufenden Server eine Rolle
  machen". Not for OpenTofu (`hostwarden-opentofu`).
---

# hostwarden-ansible

**Overrides.** Load them before anything else, key
`hostwarden-ansible`, per `rules/overrides.md`.

Read `rules/infra-code.md` and `rules/workspace-playbook.md` first:
the trees, the modes, the credentials, the eight steps and what the
session never runs are there, and nothing here repeats them. This
skill is the setup — a tree that exists afterwards is worked on
through the rule alone.

Everything the user runs is shown whole, in a fenced block with the
`operator` marker (`rules/infra-code.md` → Commands the user runs);
everything the session runs goes through `bin/hostwarden-ansible`.
A version — ansible-core's, a collection's — comes from a live
lookup (`rules/version-check.md`), and every module's arguments from
`hostwarden-ansible doc <fqcn>`, never from memory.

## Arguments

An optional `--tree <name>` first, as `bin/hostwarden-ansible` takes
it; then the step; the rest — the playbook, `--limit`, `--tags` — go
to the wrapper as they stand.

- **A wrapper verb** — `check`, `diff`, `apply`, `verify`,
  `matches`, `inventory`, `lint`, `galaxy`, `ping`, `facts` — runs that step of
  `rules/workspace-playbook.md` on that tree and nothing else, under
  that step's conditions: `/hostwarden-ansible diff site.yml --limit
  web1.example.com` shows the diff per host and the tasks check mode
  cannot show, then stops. An argument the wrapper refuses is
  refused here too, with the reason.
- **A setup way** — `adopt`, `new`, `codify`, `credentials`,
  `pipeline` — starts there (below). `adopt` takes the path or the tree's name.
- **No arguments**: the question below.

## Which way in

Ask once, in the interview format of `rules/ssh-user.md`, unless the
request or the arguments already say:

1. **Adopt** — the user has playbooks, in a repository of their own
   or to be copied into the workspace.
2. **New** — a tree from nothing, for hosts Hostwarden knows.
3. **Credentials** — the vault's password and the variables a play
   takes from the environment, on this machine or for a team.
4. **Pipeline** — a pipeline for a tree that exists.
5. **Codify** — what a host runs today, set up by hand or by
   Hostwarden, written as a role of a tree that exists.

A new tree walks through all four in that order; the others start
where they are named.

## Adopt

1. **Where it lives.** In the workspace, `memory/infra/ansible/`
   for the one tree most users have, `memory/infra/<name>/` for a
   second — the default, and where a team shares it. Or where it
   is: then the user names the absolute path, and the session writes
   the line into `memory/user.md` under `# Infrastructure code`
   (`rules/infra-code.md` → Trees). Copying a tree into the
   workspace copies the code, never `collections/`, `.ansible/` or a
   vault password file (`templates/workspace/.gitignore`).
2. **Read it** as `rules/workspace-playbook.md` step 1 says, and tell
   the user in a few lines what the tree manages, which hosts its
   inventory names, which collections it needs, and which tasks
   reach a taboo or a firewall. A task that writes `sshd_config`, an
   SSH key or a partition is named now: the tree is adopted, but
   that play is the user's to run until the task is gone.
3. **The hosts.** Every host the inventory names and Hostwarden does
   not know goes through `hostwarden-onboard` first, or the user
   says which hosts the tree is for and `--limit` stays on those.
   Where a host's memory has no `Config management:` line, the
   user says what the tree owns on it, and the line is written
   (`rules/config-management-leads.md` → Ask once, record).
4. **Write `hostwarden.md`** with the user: `Deployment:` as they
   apply today (`local` for a tree run from a workstation),
   `Credentials:` as the vault's password comes today
   (→ Credentials fixes what is loose), and `Pipeline:` where one
   exists. A tree without `ansible.cfg` gets one, naming the
   inventory and `collections_path = ./collections`; one without
   `.ansible-lint` keeps lint at the profile the user picks, `basic`
   where they do not, since a tree that works is not rewritten to
   pass `production`.
5. **Check**: `bin/hostwarden-ansible check`, then
   `bin/hostwarden-ansible galaxy` where `requirements.yml` is
   pinned, and where it is not, the pins the user wants, one exact
   version per entry. What lint reports is named, not fixed: an
   adopted tree is changed only when the user asks.
6. **The first diff shows what the user expects.** `bin/hostwarden-ansible
   diff site.yml --limit <one host>`: a diff that changes what the
   user did not expect is drift between the tree and the host, or
   a variable that differs from the one they apply with. Stop there
   and settle it with the user; only a tree whose diff the user
   recognises is adopted.
7. **Record.** Each host's `Config management: ansible (scope: …)`
   line, each credential in `memory/infra/credentials.md`, a journal
   line on each host that the tree is now run through Hostwarden.

## Codify

The user names the host and the concern: the web server, the
firewall, the users, the scheduled jobs. Follow
`rules/infra-migration.md` → A host into Ansible, from reading the
host to the scope line, and → Handing over from Hostwarden where
the files are ones Hostwarden deployed. The proof is
`bin/hostwarden-ansible matches site.yml --limit <host>` ending with
`changed=0`; a difference is a question for the user, not a reason
to apply. A scope the user gives back follows
`rules/infra-migration.md` → Handing back.

## New

1. **The questions**, together, in one message: the hosts, by the
   names Hostwarden knows them under; what the tree is to manage at
   first (a package list, a service, a set of files); where the
   vault's password lives (→ Credentials); how it is applied
   (`local` to begin with).
2. **The tree**, under `memory/infra/ansible/` or
   `memory/infra/<name>/`: `ansible.cfg` with the inventory,
   `collections_path = ./collections`, `interpreter_python = auto_silent`
   and `callback_result_format = yaml`; `inventory/hosts.yml` with the
   hosts under the groups the user names, every host by the name
   `memory/ssh_hosts` resolves, so this checkout's SSH options
   apply; `group_vars/` and `host_vars/` with the facts the plays
   need, secrets in a vault file; `site.yml` and one role per thing
   the tree manages, written as `rules/workspace-playbook.md` →
   Writing a tree says; `requirements.yml` pinned; `.ansible-lint`
   with `profile: production`; `hostwarden.md`; a `README.md` of
   five lines.
3. **Check, diff, apply, verify** as `rules/workspace-playbook.md`
   says, on one host first.
4. **Record** as Adopt step 7 says.

## Credentials

`rules/infra-code.md` → Credentials sets the sources. For an Ansible
tree they are two:

- **The vault's password**, in
  `~/hostwarden-keys/infra/ansible/<tree>/vault-password`, mode 600,
  created empty and filled by the user; the wrapper names the file
  on every run. A team keeps the password in the 1Password vault
  kept for Hostwarden, and each person copies it into that file
  once — the vault is not read on every run, since `ansible-vault`
  takes a file, not an environment variable.

  ```bash operator
  mkdir -p -m 700 ~/hostwarden-keys/infra/ansible/ansible
  install -m 600 /dev/null ~/hostwarden-keys/infra/ansible/ansible/vault-password
  ```

- **Variables a play takes from the environment** — an API token a
  module needs, `HCLOUD_TOKEN` for the `hetzner.hcloud` collection
  say — in the tree's `secrets.env` as `op://` references, or in the
  personal `~/hostwarden-keys/infra/ansible/<tree>/env`, the same
  way an OpenTofu stack has them
  (`.agents/skills/hostwarden-opentofu/references/credentials.md`).

Every credential goes into `memory/infra/credentials.md`
(`rules/infra-code.md` → Credentials); the vault password has no
expiry and says so. `Credentials:` in
`hostwarden.md` records the source.

## Pipeline

`.agents/skills/hostwarden-opentofu/references/pipeline.md` says how
a template from `templates/pipelines/` becomes a pipeline and what
the forge has to have; the Ansible templates lint and syntax-check
on every request and, where a runner reaches the hosts, run
`--check --diff`, and apply nothing (`rules/infra-code.md` →
Pipelines says what an apply from a pipeline would need).
`Deployment:` stays `local` or becomes `mixed` accordingly;
`Pipeline:` names the workflow.

## Never

- Never propose this skill: a tree is set up when the user asks
  (`rules/config-management.md` → Never push for one).
- Everything else the setup must not do is the rule's and the
  wrapper's: `rules/workspace-playbook.md` step 1 and → Writing a
  tree, `rules/infra-code.md` → Credentials,
  `bin/hostwarden-ansible --help`.
