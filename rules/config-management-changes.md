# Configuration Management Changes

Read before changing anything on a host whose memory has a
`Config management:` or `Provisioned by:` line
(`rules/config-management-leads.md` → Ask once, record), or a file
whose header says a tool manages it.

## What it changes

- **Reading is unchanged.** Housekeeping, audits and questions work
  as on any other host.
- **A change outside the tool's scope** is made by hand, as on any
  other host. Hosts mix freely: a request that spans several is
  split by their lines, and the report says, per host, which way
  the change went. A host that runs two tools is split the same
  way, by their scopes.
- **A change inside it** — a file in a named area or carrying a
  marker, or a package or service the tool manages there — belongs
  in the tool's code, or the tool undoes it. Say so, name the file
  and the change, and let the user decide:
  - **In the tool's code.** For Ansible, Hostwarden can edit the
    user's playbooks and roles on this machine when asked; applying
    them is the user's step. For the other tools the user makes the
    change.
  - **By hand anyway**, only on the user's explicit request, after
    saying when the tool will undo it: at its next run for Ansible
    and for any tool a cron job runs, within the agent's run
    interval for Puppet and Chef (30 minutes by default) and for
    CFEngine and Rudder (minutes rather than hours), at the next
    state run the Salt master starts.
    Record it in the host's memory until it is in the code, and
    name it in the changelog entry:

    ```markdown
    - Not yet in ansible: /etc/nginx/nginx.conf worker_connections 4096 (2026-09-22)
    ```

- **Unsure whether the target is in scope:** ask; never guess it is
  not.
- **Provisioned by Terraform or OpenTofu:** what that code owns —
  a cloud firewall, a DNS record, the instance size — is changed in
  that code, never in the provider's console or command line tool.
  Hostwarden never runs `terraform` or `tofu`; `apply` can replace,
  and so destroy, a server.

## Why only detection for the others

Puppet, OpenVox and Chef agents pull their configuration on their own
schedule, a Salt master pushes it to every minion at once, and
CFEngine and Rudder run an agent against a policy server the same
way, so a change made in their code reaches every host without the
per-host pipeline (`rules/first-connection.md`) ever running.
Terraform and OpenTofu provision infrastructure through cloud APIs
rather than administer a host, and their state holds secrets in
plain text (`rules/secrets.md`).
