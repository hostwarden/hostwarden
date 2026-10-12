### Added

- **`mise install` in the checkout brings the tools a session runs,
  at pinned versions.** `mise.toml` pins Ansible, `ansible-lint`,
  `yamllint` and ShellCheck; without mise the workstation's own
  copies serve. The session-start hook puts the installed tools on
  the PATH, and `bin/hostwarden-doctor` names `mise install` for what
  is missing.
- **Writing a playbook tree has its own rules.**
  `rules/workspace-playbook.md` → Writing a tree: module
  documentation first, fully qualified names, check mode and diff on
  every task, `ansible-lint --offline` before every run, secrets in a
  vault outside the workspace.
