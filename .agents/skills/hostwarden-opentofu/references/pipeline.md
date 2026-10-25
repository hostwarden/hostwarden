# A pipeline for a stack

How a template from `templates/pipelines/` becomes the tree's
pipeline. What the session does with a pipeline once it exists —
reading runs, starting one on the user's word, the credential order
— is in `rules/infra-code.md` → Pipelines.

## The templates

- `templates/pipelines/github/opentofu.yml` — GitHub Actions, one
  stack.
- `templates/pipelines/github/ansible.yml` — GitHub Actions, an
  Ansible tree.
- `templates/pipelines/gitlab/opentofu.gitlab-ci.yml` — GitLab CI,
  one stack.
- `templates/pipelines/gitlab/ansible.gitlab-ci.yml` — GitLab CI, an
  Ansible tree.

Each template's header lists what to fill in, marked `<...>`, and
what the forge has to have before the first run. The session
copies the template, fills the marks, and writes it where the forge
reads it: a tree in the workspace gets it under
`memory/.github/workflows/<tool>-<tree>.yml` or as an `include` of
`memory/.gitlab-ci.yml`; a tree in its own repository gets it there.
One workflow per stack, named after it, so two stacks never share a
concurrency group or an environment; on GitLab every job and hidden
job carries the name too, since included files merge entries of the
same name.

## What the pipeline does

- **On a pull or merge request:** `tofu fmt -check`, `tofu init
  -backend=false`, `tofu validate`, tflint, Trivy and Checkov — the
  same chain `bin/hostwarden-tofu check` runs — then `tofu plan
  -out`, with the plan's text as a comment on a GitHub pull request
  or the counts as GitLab's summary on a merge request. The plan
  runs under a read-only plan role, in an environment without
  reviewers on GitHub: a plan never waits for one. Nothing is
  applied. The comment holds every value the plan shows, so the
  repository is private and a secret reaches the code as a sensitive
  variable.
- **On the default branch**, in the second stage only: a plan
  again, into the run's summary, then the apply job, which waits in
  an environment that requires a reviewer and applies that run's
  plan artifact, so what the reviewer read in the summary is what
  runs. A plan whose state has moved since is refused by OpenTofu,
  and the job fails rather than applying something else.
- A `concurrency` group per stack keeps two runs from applying at
  once, on top of the state's own lock.

The Ansible templates lint, syntax-check and, where a runner reaches
the hosts, `--check --diff`; what an apply from a pipeline needs is
in `rules/infra-code.md` → Pipelines.

## What the forge has to have

Listed to the user, each with where it is set or the command that
sets it, before the first run:

- **GitHub:** the default branch protected by a ruleset that
  requires the plan workflow's check and a review; two environments:
  one without required reviewers (`production-plan`), which holds the
  plan role, and one with them (`production`), which holds the apply
  role, each with the provider's identifiers and any static token as
  environment secrets under the same names; Actions allowed to run;
  for the OIDC trust, each environment's subject in its role's
  condition (`references/credentials.md` → Per forge).
- **GitLab:** a protected default branch; a protected environment
  with approvers; two CI/CD variables for the roles, `AWS_ROLE_ARN_PLAN`
  not protected and `AWS_ROLE_ARN` protected; masked, protected
  variables for any static token; the `id_tokens:` audience the
  provider expects.
- **The plan role** reads the resources and the state and writes the
  state's lock object, nothing else; **the apply role** is the only
  one that writes.

A list, one setting per line, with the `gh api` or `glab` command
where one exists, in a block of its own, and the console path
otherwise. Hostwarden sets none of them: the branch protection and
the environment are the gate, and the gate is set by the person who
holds it.

## Versions in the templates

Every action in a template is pinned to a major version tag at the
time of writing (`opentofu/setup-opentofu@v2`,
`aws-actions/configure-aws-credentials@v6`, `azure/login@v3`,
`google-github-actions/auth@v3`), and every tool and image to the
version `mise.toml` pins. Before writing a pipeline, confirm
each against its repository's current release, as
`rules/version-check.md` → Version Check Procedure says, and pin the
OpenTofu version to the one `mise.toml` pins, so the pipeline and
the workstation plan with the same binary.
