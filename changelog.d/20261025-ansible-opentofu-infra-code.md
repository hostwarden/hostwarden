### Added

- **Runs your OpenTofu stacks.** A stack under
  `memory/infra/opentofu/<stack>/`, or one you register from a
  repository of your own, is checked, planned and reviewed through
  `bin/hostwarden-tofu`; a plan that adds and changes only is
  applied after the guard has asked you, every time, and a plan that
  destroys or replaces anything is handed to you as a complete
  command of the same program, which the guard denies the session. Terragrunt
  runs where a stack carries a `terragrunt.hcl`.
- **Checks before every plan.** `hostwarden-tofu check` runs `fmt`,
  `validate`, tflint, Trivy and Checkov, and `hostwarden-ansible
  check` runs `--syntax-check` and `ansible-lint`, so a mistake in
  the code falls out in seconds, before a plan or a diff reaches a
  cloud or a host. `mise install` brings OpenTofu, Terragrunt,
  tflint, Trivy and Checkov at pinned versions.
- **Credentials from a vault your team shares.** A tree's
  `secrets.env` names `op://` references, resolved through the
  1Password service account each workstation stores once; a personal
  file under `~/hostwarden-keys/infra/` serves one machine.
  `memory/infra/credentials.md` lists every credential with its
  expiry, and housekeeping warns ahead of it.
- **Pipelines for GitHub Actions and GitLab CI.** Templates under
  `templates/pipelines/` check and plan on every request and apply
  behind an environment with reviewers, with federated credentials
  first (AWS, Entra, Google Cloud) and a static token only where a
  provider offers nothing else. Each tree records how it is applied:
  `Deployment: local`, `ci` or `mixed`.
- **Two skills.** `hostwarden-opentofu` and `hostwarden-ansible` take
  over a tree you have or start one from nothing, with its state,
  its credentials and its pipeline; with a verb as argument —
  `/hostwarden-opentofu hosting plan`, `/hostwarden-ansible diff
  site.yml` — each runs that one step and reports.

### Changed

- **Your Ansible tree runs through one command.**
  `bin/hostwarden-ansible` sets this checkout's SSH options, the
  tree's inventory and configuration and the vault's password file,
  and refuses a secret in `-e`; `verify` runs the play again and
  fails unless nothing changed. Applying a playbook is asked by the
  guard before every run, for the wrapper and for a bare
  `ansible-playbook` alike.
- **Commands you are to run arrive whole.** A command Hostwarden
  hands you stands complete in a block of its own, absolute paths
  and options filled in, ready to run in any terminal.
- **`tofu` and `terraform` are no longer denied as a whole.** `plan`,
  `validate`, `show` and `output` pass; `apply`, `destroy`, `import`,
  `taint`, `force-unlock`, a state or workspace write, `run-all`,
  `-auto-approve`, `-lock=false`, `-show-sensitive` and the forms
  that print a state's values are denied, for `terragrunt` as well.
