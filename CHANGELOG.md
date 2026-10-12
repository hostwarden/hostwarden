# Changelog

The notes of this release only. Earlier releases: the `CHANGELOG.md`
at their tag, or
[GitHub Releases](https://github.com/hostwarden/hostwarden/releases).

## 1.3.0 - 2026-10-12

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
- **The guard hooks run the jq mise installed.** `mise.toml` pins jq,
  and where `mise install` has run in the checkout the hooks use that
  one, so they read a tool call the same way on every workstation and
  in CI; a workstation with mise needs no other jq. Where `mise
  install` has not run, the hooks run the jq the PATH has, never
  through mise's shims, which fail until it has, and the doctor
  reports that jq as missing.
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

### Changed

- **The taboo guard holds `ansible-playbook` and `ansible-galaxy` to
  the workspace and limits ad-hoc `ansible` to `ping` and `setup`.**
  A playbook and its inventory are named by absolute path under
  `memory/`; `ansible-pull` stays denied, and so is a password,
  secret, token or `key=` in `-e`.
