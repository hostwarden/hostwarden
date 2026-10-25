---
sidebar_position: 2
description: Works alongside Ansible, Puppet, Chef, and similar
  tools instead of replacing them, and runs the Ansible tree you
  keep.
---

# Configuration management

Hostwarden needs no Ansible, Puppet or Chef and never suggests
one. Where you keep an Ansible tree, it runs it for you, through
one command that sets everything a bare `ansible-playbook` call
forgets ([Infrastructure code](infrastructure-code.md)).

## Recognizing a tool already in use

When a host carries signs of one — Ansible runs in the journal,
`Ansible managed` headers, a Puppet or OpenVox, Chef or Cinc,
Salt, CFEngine or Rudder agent, a cron job that runs one of them —
Hostwarden asks once whether it manages the host, wholly or in
some areas, and remembers the answer in the host's memory:

```markdown
- Config management: ansible (scope: base, nginx)
```

Hosts can be mixed freely, and so can a host: a cloud firewall an
OpenTofu stack owns, packages an Ansible role owns, and a config
file set by hand, each recorded, each changed where it belongs.

## Working inside and outside the scope

Outside that scope Hostwarden works by hand as usual; inside it,
the tool's ownership changes what happens.

- **Inside the scope, it warns first.** It tells you the tool would
  undo a hand change; for Ansible it offers to make the change in
  your tree instead, and for the other tools the change in their
  code is yours.
- **A hand change is noted, not hidden.** It happens only when you
  insist, and stays noted in the host's memory until it is carried
  into the code.
- **Ansible activity is visible.** Ansible runs by anyone show up
  in the recent-activity summary on connect.

## Your Ansible tree, run by Hostwarden

Keep the tree under `memory/infra/ansible/` in the workspace —
`site.yml`, the inventory, `ansible.cfg`, `requirements.yml`, the
roles — and a session runs it through `bin/hostwarden-ansible`, the
same command you can run yourself:

```bash
/srv/hostwarden/bin/hostwarden-ansible diff site.yml --limit web1.example.com
```

It reads the tree first, and a task that reaches a taboo — writing
`sshd_config` or an SSH key, partitioning or formatting a disk, a
halt or reboot — stops it there, until you take the task out or run
the playbook yourself; a task that can cut SSH, such as a firewall
or network one, gets the same safety net as a change by hand
([What it asks first](../../safety/approvals.md#firewall-and-network-changes)).
Then, in this order:

1. **`check`** — `--syntax-check` and `ansible-lint`, after every
   edit, before anything reaches a host.
2. **`inventory`** — which hosts the pattern you named reaches.
3. **`diff`** — `--check --diff` on those hosts, and a word about
   the tasks check mode cannot show.
4. **`apply`** — asked before it runs, every time, with the command
   as it stands
   ([What it asks first](../../safety/approvals.md#applying-infrastructure-code)).
5. **`verify`** — the run again, which has to change nothing.

Each host's memory then records what the tree owns, and the
changelog entry names the tree and the commit it ran from. A tree
you keep in a repository of your own works the same way once you
register its path on your machine; Hostwarden edits there and
commits only when you tell it to, that one time.

- **Writing a tree is supported the same way.** A session also
  writes or changes a tree, under the same rules, and lints it
  before every run. The tools come from
  [mise](../../getting-started/install.md#prerequisites).
- **Collections stay with the tree.** They install only from a
  `requirements.yml` whose every entry pins one exact version, not
  a range or a branch, into the tree's own `collections/` directory,
  never into your home.
- **The vault's password lives outside the workspace**, in
  `~/hostwarden-keys/infra/ansible/<tree>/vault-password`, and the
  command names it; a token a module needs comes from your 1Password
  vault or a personal file the same way
  ([Infrastructure code](infrastructure-code.md#credentials)).
- **Taking over a tree you have** and starting a new one is the
  `hostwarden-ansible` skill: "take over my playbooks", "übernimm
  meine Playbooks".

## When the question comes back

Agent directories and services are looked at on every connect, so
an agent installed later — or a host Hostwarden knew before the
check existed — still gets the question, as does one whose
recorded answer no longer covers what is there. Cron jobs and
rendered files are looked at on the first connect, and again when
something new points to a tool.

## Terraform and OpenTofu

A host an OpenTofu or Terraform stack built is noted when you say
so, or when a stack Hostwarden runs created it:

```markdown
- Provisioned by: opentofu (hosting)
```

Hostwarden then leaves what that code owns — a cloud firewall, a
DNS record, the instance size — to the code: it plans the change
in your stack, shows you the plan, and applies only a plan that
deletes and replaces nothing, asked every time
([Infrastructure code](infrastructure-code.md)).
