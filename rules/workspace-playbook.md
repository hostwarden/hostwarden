# A Playbook From the Workspace

Read when the user asks to check, apply, write or change an Ansible
tree Hostwarden runs: `memory/infra/ansible/` or another tree under
`memory/infra/<name>/`, or one `memory/user.md` registers outside
the workspace (`rules/infra-code.md` → Trees, which comes first).
Everything here runs through `bin/hostwarden-ansible`, whose
`--help` says what each verb sets and runs.
`rules/config-management.md` → Never push for one holds unchanged:
a tree is used where the user put one, never proposed.

A tree holds `site.yml`, an inventory, the task and role files the
play reaches, `ansible.cfg` with `collections_path = ./collections`,
`requirements.yml` where it needs collections, `.ansible-lint`, and
`hostwarden.md` (`rules/infra-code.md` → The tree's lines). What
`collections/` and `.ansible/` hold is fetched or cached, not
written, and the workspace's `.gitignore` leaves them out
(`templates/workspace/.gitignore`); a workspace from before those
lines gets them added to its `.gitignore` before the first run.

1. **Read the tree first.** `site.yml`, the inventory, every task
   file the play reaches — its roles and the collections under
   `collections/` included — as text. The guard cannot read a
   task, so this step is what keeps the taboos
   (`AGENTS.md` → Critical Safety Rules): a task that writes
   `sshd_config` or its drop-ins, an SSH key, `authorized_keys` or
   `RevokedKeys` by any module (`template`, `copy`, `lineinfile`,
   `blockinfile`, `file`, `authorized_key`, `openssh_keypair`,
   `user` with `generate_ssh_key`), one that partitions, formats
   or repairs storage (`parted`, `filesystem`, `lvol`, `zfs`, …),
   and one that halts or reboots (`reboot`, `shutdown`, a `command`
   that does) is never run, in check mode or for real. Name it to
   the user; the play runs once the user has taken it out, or the
   user runs the playbook. A task that changes the firewall, the
   network, a VPN, PAM, a network sysctl or a login shell (`ufw`,
   `firewalld`, `iptables`, `nftables`, `nmcli`, `pamd`, `sysctl`,
   `user` with `shell`, …) is run only as
   `rules/firewall-changes.md` and `rules/ssh-safety-net.md` say:
   every port sshd listens on stays open, and the timed revert is
   in place before step 5 applies. Then name every task that runs
   in check mode too — one with `check_mode: false` — what it
   executes, and why it is read-only or not; such a task that
   writes is a reason to stop and ask, not to run `diff`.
2. **Check** — `hostwarden-ansible check` (`--tree <name>` for another
   tree, the playbooks as arguments where it is not `site.yml`):
   the syntax check and ansible-lint with the tree's profile. It
   reaches no host, so it runs after every edit the session makes,
   before anything else: a wrong module name, an argument the
   module does not take, a missing `name:` fall out here in
   seconds. What it reports is fixed in the tree, or named to the
   user, before step 4.
3. **Every host the play reaches** has gone through
   `rules/first-connection.md` in this session, and
   `hostwarden-ansible playbook --list-hosts site.yml --limit <hosts>`
   shows which those are, with the `--limit` the user named: a
   pattern that reaches more hosts than meant is caught here, not in
   the recap. A value the play needs
   comes from a vars file in the tree or the vault, never from
   `-e`: the wrapper and the guard refuse a secret there.
4. **Diff** — `hostwarden-ansible diff site.yml --limit <hosts>`:
   `--check --diff` on the hosts the user named, one host at a time
   where the diff is long. Show the diff per host and the recap
   line. Check mode has limits the user has to hear: a `command` or
   `shell` task without `creates:` or `removes:` is skipped and
   reports nothing, a task whose `when:` reads a registered result
   of a skipped task does not run, and a module that does not
   support check mode reports no change. Such a task is named as
   not shown by the diff; it is not a task that changes nothing.
5. **Apply** — `hostwarden-ansible apply site.yml --limit <hosts>`,
   the same arguments as the diff. Applying is a change: register
   on each host (`rules/parallel-sessions.md`), announce where a
   task restarts a service or touches the network
   (`rules/coordination.md` → Announce, wait, go), set the safety
   net where step 1 found a task that can cut SSH
   (`rules/ssh-safety-net.md`, whose step 5 covers a play run from
   the workstation), then run, asked as `rules/infra-code.md` →
   Deployment modes says; on a `Deployment: ci` tree the apply is
   the pipeline's. For a task that can
   cut SSH the run is `--limit` to one host, armed in a call of its
   own first, then that host's fresh login and the cancel before
   the next host starts.
6. **Verify** — `hostwarden-ansible verify site.yml --limit <hosts>`:
   the run again, which has to end with `changed=0` for every host;
   the wrapper fails otherwise and names the hosts. For a task that
   can cut SSH it is a change again, so each host is armed once more
   first, in a call of its own, and the cancel follows its result.
   A second run that still changes is a task that is not
   idempotent, named to the user, not run a third time.
   `hostwarden-ansible matches site.yml --limit <hosts>` is the same
   proof before any apply: a check run that has to end with
   `changed=0`, for a tree written to describe a host that exists
   (`rules/infra-migration.md`).
7. **Log it.** A journal line per host (`rules/changelog.md`), a
   changelog entry whose `Source:` names the tree and the workspace
   commit of it, and the host's `Config management: ansible
   (scope: …)` line written or extended with what the play owns
   (`rules/config-management-leads.md` → Ask once, record). A path
   the playbook owns from now on loses its Hostwarden master: its
   `deployed.md` entry goes, as `rules/deployed-files.md` → What
   gets a master says.
8. **Collections** — `hostwarden-ansible galaxy` installs the tree's
   `requirements.yml` into its `collections/`, never into the user's
   home, and only when every entry carries a `version:` that names
   one exact version — `1.2.3` or `==1.2.3`, for a `git` source a
   commit — not a range, `*` or a branch, which install whatever is
   newest that day. The wrapper names the entries that do not and
   installs nothing.

## Writing a tree

The tools come from `mise.toml` in the checkout
(`rules/session-start.md` → Workstation tools).

- **Read the module before using it.** `hostwarden-ansible doc <fqcn>`
  is the `--help` of `AGENTS.md` → Verify Before Running: the
  argument names, their defaults and whether the module supports
  check mode and diff come from there, never from memory.
- **Fully qualified names.** Every module and plugin by its
  collection: `ansible.builtin.apt`, `ansible.posix.firewalld`,
  `community.general.ufw`. Every collection outside
  `ansible.builtin` is an entry of `requirements.yml`, pinned as
  step 8 says.
- **Every task reports in check mode, and a second run reports
  `changed=0`** (step 6): `creates:`, `removes:` or `changed_when:`
  on `command`, `shell` and `raw`, `check_mode: false` with a
  comment where one only reads, and a file written through
  `template`, `copy` or `lineinfile`, so `--diff` shows it.
- **A task that renders a secret, from the vault or from
  `secrets.env`, carries `no_log: true` and `diff: false`.** `diff` and
  `matches` print the before and after
  of every file, and the session reads that output.
- **Handlers for restarts, reloads where the service takes one**
  (`rules/service-reload.md`), never a restart in a task.
- **Lint with the tree's profile.** The tree carries a
  `.ansible-lint` naming it — `production` for a tree the session
  starts, the one it has for a tree the user brought — and step 2
  runs before every run and every commit; where the workstation
  lacks ansible-lint, the wrapper says so, as a feature the doctor
  lists as not available.
- **Secrets** live in a vault, `ansible-vault` with the password in
  `~/hostwarden-keys/infra/ansible/<tree>/vault-password`, which
  the wrapper names (`rules/infra-code.md` → Credentials); never in
  `-e`, never in a vars file in the clear, never in the session's
  output. A value a lookup takes from the environment comes from the
  tree's `secrets.env` the same way.
- **The host's memory stays the truth** for what the play owns:
  step 7 records the scope, and a file the tree now renders is no
  longer deployed by hand (`rules/deployed-files.md` → What gets a
  master).

The read-only verbs need none of the steps: `hostwarden-ansible
inventory`, `doc`, `lint`, `ping <pattern>`, `facts <pattern>
<filter>` and `playbook --list-tasks`, `--list-hosts`,
`--list-tags`. `facts` always filters, since an unfiltered `setup`
prints `ansible_env`, the login user's whole environment, which can
carry a token (`rules/secrets.md` → Commands That Leak). Every other
ad-hoc module is a change outside the tree the user can read, and
goes into the playbook instead.

A tree the user already has, in the workspace or in a repository of
their own, is adopted as it is: read as step 1 says, its
`hostwarden.md` written with the user, `check` run once, and the
first `diff` has to show what the user expects before anything is
changed. The `hostwarden-ansible` skill walks through this and
through a new tree.
