# A Playbook From the Workspace

Read when the user asks to check or apply an Ansible playbook that
lives in the workspace, under `memory/infra/<name>/`. That tree is
the one place a session runs `ansible-playbook` itself: the code is
the user's own, in the repository the session already commits to.
The taboo guard holds the run to the workspace, `memory/`
(`AGENTS.md` → Critical Safety Rules); this rule narrows it to
`infra/<name>/`. A playbook anywhere else — a checkout of its
own, a path the user names — is applied by the user; the session
prepares the change in its code
(`rules/config-management-changes.md`). `rules/config-management.md`
→ Never push for one holds unchanged: a workspace playbook is used
where the user put one, never proposed.

A tree holds `site.yml`, an inventory, the task and role files the
play reaches, `ansible.cfg` with `collections_path = ./collections`,
and `requirements.yml` where it needs collections. What
`collections/` and `.ansible/` hold is fetched or cached, not
written, and the workspace commit takes everything:
`/infra/*/collections/` and `/infra/*/.ansible/` stand in the
workspace's `.gitignore` (`templates/workspace/.gitignore`), and
step 1 puts them there first where a workspace from before those
lines lacks them.

1. **Read the tree first.** Add `/infra/*/collections/` and
   `/infra/*/.ansible/` to `memory/.gitignore` where they are
   missing. Then `site.yml`, the inventory, every task
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
   network or a login shell (`ufw`, `firewalld`, `iptables`,
   `nftables`, `nmcli`, `user` with `shell`, …) is run only as
   `rules/firewall-changes.md` and `rules/ssh-safety-net.md` say:
   every port sshd listens on stays open, and the timed revert is
   in place before step 4 applies. Then name every task that runs in check
   mode too — one with `check_mode: false` — what it executes, and
   why it is read-only or not; such a task that writes is a reason
   to stop and ask, not to run `--check`. Run
   `ansible-lint --offline` on the tree where the workstation has
   it (`rules/session-start.md` → Workstation tools); without
   `--offline` it installs every `requirements.yml` it finds. What
   it reports is fixed in the tree, or named to the user, before
   the run.
2. **Every host the play reaches** has gone through
   `rules/first-connection.md` in this session, and the run uses
   the session's SSH configuration (`AGENTS.md` → SSH Options),
   set in the call rather than in the tree:

       ANSIBLE_CONFIG=<checkout>/memory/infra/<name>/ansible.cfg \
       ANSIBLE_SSH_ARGS='-F <checkout>/memory/ssh_config' \
       ansible-playbook -i <checkout>/memory/infra/<name>/inventory \
         --limit <hosts> --check --diff \
         <checkout>/memory/infra/<name>/site.yml

   The playbook and the inventory are absolute paths under
   `memory/`, written out, not `~`, a variable or a path relative
   to a `cd`: that is what the guard reads. `ANSIBLE_CONFIG` names
   the tree's `ansible.cfg`, which Ansible otherwise reads only
   from the current directory, and from a world-writable one not
   at all. `ANSIBLE_SSH_ARGS` replaces Ansible's default
   `-C -o ControlMaster=auto -o ControlPersist=60s`; the shared
   connection comes from the file instead. A value the play needs
   comes from a vars file in the tree, never from `-e`.
3. **Run `--check --diff`**, with `--limit` to the hosts the user
   named, and show the diff per host and the recap line. A task
   whose module reports nothing in check mode is named as such;
   it is not a task that changes nothing.
4. **Applying is a change.** Register on each host
   (`rules/parallel-sessions.md`), announce where a task restarts a
   service or touches the network (`rules/coordination.md` →
   Announce, wait, go), set the safety net where step 1 found a
   firewall or network task (`rules/ssh-safety-net.md`), then ask
   once, the hosts listed, and run the same call without
   `--check`. A second run afterwards has to
   report `changed=0` for every host; show it, and treat anything
   else as a task that is not idempotent, named to the user.
5. **Log it.** A journal line per host (`rules/changelog.md`), a
   changelog entry whose `Source:` names the workspace commit of
   the playbook tree, and the host's `Config management: ansible
   (scope: …)` line written or extended with what the play owns
   (`rules/config-management-leads.md` → Ask once, record). A path
   the playbook owns from now on loses its Hostwarden master: its
   `deployed.md` entry goes, as `rules/deployed-files.md` → What
   gets a master says.
6. **Collections** install into the tree, never into the user's
   home, and only from a pinned list: every entry of
   `requirements.yml` carries a `version:` that names one exact
   version — `1.2.3` or `==1.2.3`, for a `git` source a commit —
   not a range, `*` or a branch, which install whatever is newest
   that day. Where one does not, say which and stop. Then:

       ansible-galaxy collection install \
         -r <checkout>/memory/infra/<name>/requirements.yml \
         -p <checkout>/memory/infra/<name>/collections

   Both paths absolute under `memory/`, `-p` under the directory
   that holds the requirements file; the guard takes nothing else.

The read-only commands need none of this: `ansible-inventory
--list` and `--graph`, `ansible-doc`, `ansible-lint`,
`ansible-galaxy collection list`, `ansible-playbook --syntax-check`,
`--list-tasks`, `--list-hosts` and `--list-tags`, and an ad-hoc
`ansible <pattern> -m ping` or `-m setup`. `setup` runs with
`-a filter=<pattern>` naming the facts asked for: unfiltered, it
prints `ansible_env`, the login user's whole environment, which can
carry a token (`rules/secrets.md` → Commands That Leak). Every other
ad-hoc module is a change outside the tree the user can read, and
goes into the playbook instead.
