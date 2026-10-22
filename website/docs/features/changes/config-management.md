---
sidebar_position: 2
description: Works alongside Ansible, Puppet, Chef, and similar
  tools instead of replacing them.
---

# Configuration management

Hostwarden needs no Ansible, Puppet or Chef and never suggests
one.

## Recognizing a tool already in use

When a host carries signs of one — Ansible runs in the journal,
`Ansible managed` headers, a Puppet or OpenVox, Chef or Cinc,
Salt, CFEngine or Rudder agent, a cron job that runs one of them —
Hostwarden asks once whether it manages the host, wholly or in
some areas, and remembers the answer in the host's memory:

```markdown
- Config management: ansible (scope: base, nginx)
```

Hosts can be mixed freely.

## Working inside and outside the scope

Outside that scope Hostwarden works by hand as usual; inside it,
the tool's ownership changes what happens.

- **Inside the scope, it warns first.** It tells you the tool would
  undo a hand change; for Ansible it offers to make the change in
  your playbooks instead, and for the other tools the change in
  their code is yours.
- **A hand change is noted, not hidden.** It happens only when you
  insist, and stays noted in the host's memory until it is carried
  into the code.
- **Ansible activity is visible.** Ansible runs by anyone show up
  in the recent-activity summary on connect.
- **A playbook in the workspace, Hostwarden runs for you.** Keep a
  playbook tree under `memory/infra/<name>/` — `site.yml`, the
  inventory, `ansible.cfg`, `requirements.yml` — and a session reads
  it first. A task that reaches a taboo — writing `sshd_config` or
  an SSH key, partitioning or formatting a disk, a halt or reboot —
  stops it there, until you take the task out or run the playbook
  yourself; a task that can cut SSH, such as a firewall or network
  one, gets the same safety net as a change by hand
  ([What it asks first](../../safety/approvals.md#firewall-and-network-changes)).
  Then it names every task that runs even in check mode,
  runs `ansible-lint --offline` where your machine has it, then
  `--check --diff` for the hosts you name and shows you the diff per
  host. Applying
  is a change like any other: it asks once with the hosts listed,
  runs, and shows a second run with nothing changed. Each host's
  memory then records what the play owns, and the changelog entry
  names the workspace commit it came from.
- **Writing a tree is supported the same way.** A session also
  writes or changes a tree, under the same rules, and lints it
  before every run. The tools come from
  [mise](../../getting-started/install.md#prerequisites).
- **Collections stay with the playbook.** They install only from a
  `requirements.yml` whose every entry pins one exact version, not
  a range or a branch, into the tree's own `collections/` directory,
  never into your home.
- **A playbook kept anywhere else you apply yourself.** The taboo
  guard holds `ansible-playbook` to the workspace
  ([Hard guardrails](../../safety/guardrails.md)); the session
  prepares the change in your code and leaves the run to you.

## When the question comes back

Agent directories and services are looked at on every connect, so
an agent installed later — or a host Hostwarden knew before the
check existed — still gets the question, as does one whose
recorded answer no longer covers what is there. Cron jobs and
rendered files are looked at on the first connect, and again when
something new points to a tool.

## Terraform and OpenTofu

Hosts built with Terraform or OpenTofu are noted when you say so;
Hostwarden then leaves what that code owns, such as a cloud
firewall or DNS record, to the code, and never runs `terraform` or
`tofu` to apply or destroy it.
