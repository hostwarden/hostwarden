# Moving What Exists Under Code

Read when the user wants infrastructure that exists today — resources
at a provider, a host set up by hand, files and services Hostwarden
deployed itself — brought under OpenTofu or Ansible, or wants a host
or a part of it handed from Hostwarden to code, or back.
`rules/infra-code.md` comes first: the trees, the modes, the
credentials and the commands shown to the user are there; the steps
that run the tools are in `rules/opentofu.md` and
`rules/workspace-playbook.md`. Nothing here is proposed on
Hostwarden's own: `rules/config-management.md` → Never push for one
holds.

## The rules that make it safe

- **The code describes what is there before it changes anything.**
  Nothing is written to a host or a provider until a plan or a diff
  has shown the user what the code would do, and the first one shows
  nothing but the takeover: imports only for OpenTofu, `changed=0`
  for Ansible. A difference is not fixed by applying; it is a
  question.
- **The user decides which side is wrong.** Where the code and the
  real thing differ, either the code is corrected to match what runs,
  which is the default, or the real thing is changed to match the
  code, which is an apply like any other and asked as one. The
  session never decides that by itself, and never applies to make a
  generated draft true.
- **One slice at a time.** A service, a firewall, a DNS zone, one
  project at a provider: the user names it. A whole estate in one
  pass is a draft nobody can read.
- **The state first.** An import writes every attribute of the object
  into the state, secrets among them. The stack's state is remote
  and locked before the first import
  (`rules/opentofu.md` → State); the wrapper refuses to generate
  into a workspace stack without a `State:` line that says so.
- **Secrets stay out of the code.** A generated draft carries a
  sensitive attribute as `null` with a comment, and a role copied from
  a host's files carries none: a password, token or key in a file is
  a variable from the vault or `secrets.env`
  (`rules/infra-code.md` → Credentials), and the file's master keeps
  the placeholder.
- **The taboos stay.** A task or resource that writes `sshd_config`,
  a key, a partition table or the boot configuration is code the user
  runs, never code Hostwarden applies
  (`AGENTS.md` → Critical Safety Rules); the draft says so beside it.
- **Read-only until the user says apply.** Listing what exists, reading
  a host, generating a draft and the plan or diff that checks it
  change nothing.

## Existing resources into OpenTofu

1. **What exists, read-only.** The provider's own listing, with a
   read-only token where the provider has one; for a guest of a
   hypervisor Hostwarden administers, `memory/machines/<hypervisor>/guests.md`
   already holds the IDs; for DNS, `memory/dns.md`. The user names the
   slice, and the session writes down what it found, one line per
   resource, before anything is generated.
2. **The stack and its state** exist first: a tree under
   `memory/infra/opentofu/<stack>/` with its provider pinned, its
   backend remote and its credentials entered
   (the ways New, State and Credentials of `hostwarden-opentofu`).
3. **`import` blocks, never `tofu import`.** One `import` block per
   resource in `imports.tf`, with `to` the address the code will
   give it and `id` — or `identity`, where the resource type has one
   — as the provider's current documentation spells it, never from
   memory. An import block goes through a plan the user reads; the
   `tofu import` command writes the state at once, and stays the
   user's.
4. **A draft of the resources:**
   `hostwarden-tofu <stack> generate [file]` runs
   `plan -generate-config-out` into a new `.tf` file in the tree. The
   feature is experimental, and the draft is best-guess HCL: it can
   fail on a provider with conflicting arguments, writes the file all
   the same, and generates nothing for an `import` block that uses
   `for_each`. Write one block per resource for the generation; fold
   them into a `for_each` afterwards if the user wants.
5. **Clean the draft** into code someone wants to keep: remove
   attributes the provider computes or rejects, split the file by
   concern, replace literal IDs of other resources by references,
   replace a `null` secret by a variable, and keep a comment where a
   value is a decision (a size, a region). `hostwarden-tofu <stack>
   check` after every round.
6. **Plan until it shows imports only.** `hostwarden-tofu <stack> plan`
   then `review`: the summary says `N to import` and nothing to add,
   change, destroy or replace. A line `import/update` is a resource
   whose code differs from the real one; the `note:` under the list
   counts them. Correct the code, not the resource, until none is left,
   unless the user says the resource is what has to change.
7. **Apply the imports.** A plan of imports only deletes and replaces
   nothing, so it is the plan `hostwarden-tofu <stack> apply` takes,
   asked as `rules/infra-code.md` → Deployment modes says. Afterwards
   `plan` shows no changes. The `import` blocks stay until the commit
   that merges the work, then go: a tracked object makes them inert.
8. **Records.** `rules/opentofu.md` → Records: `Provisioned by:
   opentofu (<stack>)` on each host the stack now owns, the credentials
   register, the journal line, the changelog entry whose `Source:`
   names the commit.

A resource the user wants out of OpenTofu's hands again is a `removed`
block with `lifecycle { destroy = false }` in the code, planned like
any change; `tofu state rm` is the user's command, shown whole. After
that plan is applied, and where the stack holds nothing else on the
host, the host's `Provisioned by:` line is removed.

## A host into Ansible

A host that was set up by hand, or whose files Hostwarden deployed.
The unit is a concern, not the host: one role for the web server, one
for the firewall, one for the users, one for the scheduled jobs.

1. **What is there, read-only.** The host's memory (`memory.md`:
   services, packages, ports; `deployed.md`: every path Hostwarden
   wrote, with its master in the workspace), then the host itself
   through the first-connection pipeline: the package list, the
   service's unit, the configuration files, the cron entries — read
   as `rules/secrets.md` says, a secret file by metadata and never by
   content.
2. **A role that states today's value.** Fully qualified modules
   (`rules/workspace-playbook.md` → Writing a tree), each task naming
   what the host has, not what would be nicer; a task that renders a
   secret carries `no_log: true` and `diff: false`. A file Hostwarden
   deployed becomes the role's `files/` or `templates/` entry, the
   master moved into the role with its bytes unchanged: the hash in
   `deployed.md` proves it. A package list is the packages the host
   has for the concern, not every package.
3. **Check, then match.** `hostwarden-ansible check`, then
   `hostwarden-ansible matches site.yml --limit <host>`: a dry run that
   must end with `changed=0`. It is the proof that the code describes
   the host.
4. **A difference is a question** (the rules above). Show the diff per
   host and say which side each line would change. The default is to
   correct the role; applying the role to the host is the user's call.
5. **Say what the dry run cannot show.** A `command` or `shell` task
   without `creates:` or `removes:` is skipped, a module without check
   mode reports nothing, a task that reads a registered result of a
   skipped one does not run
   (`rules/workspace-playbook.md`, step 4). `matches` is silent
   about those; the report names each, and the role avoids them where
   a module exists.
6. **Hand over the scope.** When `matches` holds and the user says
   the role now owns the concern: the host's `Config management:
   ansible (scope: <concern>)` line is written or extended
   (`rules/config-management-leads.md` → Ask once, record), the
   `deployed.md` entries for the paths the role now renders go
   (`rules/deployed-files.md` → What gets a master), and from then on
   a change to that concern is a change to the role
   (`rules/config-management-changes.md`). Hostwarden deploys none of
   those paths by hand again.
7. **What stays out of the role.** sshd's configuration and keys,
   `authorized_keys`, partition tables, the boot configuration and a
   halt or reboot stay out of anything Hostwarden applies. A role may
   describe them for the user to run; the draft names each beside the
   task.

`hostwarden-ansible verify` after the first real apply of a role: the
second run reports `changed=0`.

## Handing over from Hostwarden

What Hostwarden itself manages on a host moves to code concern by
concern, by the two flows above:

- **Files it deployed** — `deployed.md` and the masters under
  `machines/<host>/files/` — become a role's files and templates.
  The master moves with `git mv`, so its history goes along.
- **Baseline settings it set up** — the automatic updates, a firewall
  rule set, a login notice, time sync — are read from the host as in
  step 1, because the baseline records what is wanted, not what was
  written.
- **Guests it created** (`hostwarden-new-guest`) become `import`
  blocks of an OpenTofu stack for their hypervisor, the IDs from
  `guests.md`. The guest's own configuration, once running, stays in
  the host's Ansible scope.

What stays Hostwarden's: the SSH access and host keys, machine
memory and the journal, housekeeping and audits, and whatever the
user's scope lines leave to it. A host in both worlds is split by its
lines, and the report says per host which way a change went
(`rules/config-management-changes.md`).

## Handing back

The user takes a scope out of a tool. First the tool stops acting on
it: for Ansible, the concern's tasks or the host leave the play, the
inventory group and any scheduled or pipeline run of the tree; for
OpenTofu, the `removed` block above. Only then is the `Config
management:` line changed or removed, nothing on the host is touched,
and from then on Hostwarden changes the files by hand again, with the
master back in the workspace if the user wants one. A line changed
while the tree still reaches the host leaves the next run to undo
every manual change.

## Records

The slice's journal line on each host and a changelog entry whose
`Source:` names the commit of the tree
(`rules/changelog.md`, `rules/opentofu.md` → Records), saying which
concern or resources moved and that the first plan or diff showed
nothing but the takeover.
