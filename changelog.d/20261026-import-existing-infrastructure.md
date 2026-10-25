### Added

- **Brings what exists under OpenTofu or Ansible.** Resources at a
  provider are imported into a stack with `import` blocks, and
  `hostwarden-tofu <stack> generate` drafts their code; a host set
  up by hand, or by Hostwarden, becomes an Ansible role per concern.
  The plan or diff has to show nothing but the takeover before
  anything is applied, and a difference between code and host is
  your question to answer, never fixed by an apply on its own.
- **`hostwarden-ansible matches` proves a role describes a host.** It
  runs the play in check mode and fails unless nothing would change,
  and `hostwarden-tofu review` counts the imports a plan holds.
  `/hostwarden-opentofu` and `/hostwarden-ansible` take the ways
  `import` and `codify`.

### Fixed

- **A vaulted tree passes `check` and a dynamic inventory resolves.**
  `ansible-lint` now reads the tree's vault password, an
  `ansible.cfg` that lists several inventory sources keeps them all,
  and `inventory` loads the tree's credentials.
- **Two GitLab pipeline files of the same name stay apart.** The jobs
  of an Ansible tree begin with `ansible-`, so a tree and a stack of
  one name no longer merge.
