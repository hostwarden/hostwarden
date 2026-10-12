### Added

- **A session runs an Ansible playbook kept under
  `memory/infra/<name>/`.** It reads the tree first, runs
  `--check --diff` for the hosts you name, applies after you say so,
  and shows a second run with nothing changed
  (`rules/workspace-playbook.md`). A task that reaches a taboo stops
  it before any run. Collections install beside the playbook, from
  a `requirements.yml` whose every entry pins one exact version,
  never into your home.
- **`bin/hostwarden-doctor` reports Ansible as a workstation tool.**
  `ansible-playbook`, `ansible-galaxy` and `ansible-lint` show as not
  available where they are missing, with the install command.

### Changed

- **The taboo guard holds `ansible-playbook` and `ansible-galaxy` to
  the workspace and limits ad-hoc `ansible` to `ping` and `setup`.**
  A playbook and its inventory are named by absolute path under
  `memory/`; `ansible-pull` stays denied, and so is a password,
  secret, token or `key=` in `-e`.
