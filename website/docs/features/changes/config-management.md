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
- **Hostwarden never applies your code.** It runs no playbook to
  apply a change; applying your Ansible code is your step.

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
