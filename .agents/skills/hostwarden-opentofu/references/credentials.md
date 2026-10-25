# Credentials for a stack

What a stack authenticates with, on the workstation and in a
pipeline, per provider and per forge. The order and the sources
are in `rules/infra-code.md` → Credentials; this file has the
shape of each. Every command the user runs is shown whole, in a
block of its own; every `az`, `aws`, `gcloud` or `hcloud` command
here is the user's, since it creates or changes an identity.

## A team's vault

One 1Password vault, kept for Hostwarden, holds the SSH passwords
and every credential the trees use; a service account reads that
vault and no other, and every workstation stores its token once:

```bash operator
/srv/hostwarden/bin/hostwarden-password token 1password
```

An item per credential, a field per value; the stack's
`secrets.env` names them, and `op run` resolves them for the tool
alone:

```
HCLOUD_TOKEN=op://Hostwarden/hcloud-hosting/token
CLOUDFLARE_API_TOKEN=op://Hostwarden/cloudflare-example-com/token
```

The references name the vault the token sees; a reference to
another vault stops the run. Bitwarden Secrets Manager takes a
project instead: `bws-project: <project id>` as the only line, the
secrets' names the variable names, the token stored with
`bin/hostwarden-password token bws`.

## One person, one machine

```bash operator
mkdir -p -m 700 ~/hostwarden-keys/infra/opentofu/hosting
install -m 600 /dev/null ~/hostwarden-keys/infra/opentofu/hosting/env
```

The user then writes `VAR=value` lines into the file in an editor.
The wrapper refuses the file at any other mode or owner, and
exports its lines to the tool alone.

## Per provider

- **AWS.** Workstation: `aws sso login` with a profile, or a
  profile in `~/.aws/`; the backend and the provider read
  `AWS_PROFILE`, so the `env` file or `secrets.env` holds that one
  line. Pipeline: an IAM role whose trust policy names the forge's
  OIDC provider and the repository, branch or environment in its
  `sub` condition — `repo:<owner>/<repo>:environment:production` for
  GitHub, `project_path:<group>/<project>:ref_type:branch:ref:main`
  for GitLab — created by the user as the AWS documentation
  shows, and filled into the workflow as `role-to-assume`.
- **Azure, Entra.** Workstation: `az login`; the provider reads the
  CLI's token. Pipeline: a user-assigned managed identity with a
  federated identity credential for the repository and branch or
  environment, created by the user:

  ```bash operator
  az identity create --name infra-pipeline --resource-group rg-infra
  az identity federated-credential create --name github-main --identity-name infra-pipeline --resource-group rg-infra --issuer https://token.actions.githubusercontent.com --subject repo:alice/infra:environment:production --audiences api://AzureADTokenExchange
  ```

  The identity gets the role the stack needs on the subscription or
  the resource group, nothing wider; its client, tenant and
  subscription IDs go into the workflow (`azure/login` reads
  `client-id`, `tenant-id`, `subscription-id`), and `ARM_USE_OIDC`
  into the provider's environment. An app registration with a
  federated credential does the same where the identity cannot be
  used; one with a client secret is the last resort, with the
  secret's expiry in the register.
- **Google Cloud.** Workstation: `gcloud auth login` and
  `gcloud auth application-default login`. Pipeline: a workload
  identity pool and provider for the forge, created by the user as
  the Google documentation shows, and the provider's resource name
  filled into the workflow (`google-github-actions/auth` reads
  `workload_identity_provider`; a service account to impersonate
  only where the stack needs one).
- **Hetzner Cloud.** A static token per project from the console,
  read and write, as `HCLOUD_TOKEN`: in the vault for the
  workstation, in the forge's environment secrets for the pipeline.
  Hetzner offers no federation; the register carries the token's
  expiry, which the user sets when making it.
- **Scaleway.** An IAM application with a policy scoped to the
  project, its API key as `SCW_ACCESS_KEY` and `SCW_SECRET_KEY`,
  with `SCW_DEFAULT_PROJECT_ID` beside them; expiry set at creation.
- **OVHcloud.** An application key, application secret and consumer
  key, the consumer key restricted to the API paths the stack uses
  and given a validity at creation, as `OVH_APPLICATION_KEY`,
  `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY` and `OVH_ENDPOINT`.
- **Cloudflare.** An API token scoped to the zones and the
  permissions the stack uses, as `CLOUDFLARE_API_TOKEN`, with a TTL
  where the account allows one.

The variable each provider reads, and the claims each forge puts
into its token, come from the provider's and the forge's current
documentation at the time of setup; the names above are the ones
in use at the time of writing, to be confirmed, not copied.

## Per forge

- **GitHub Actions** issues a token when the job has
  `permissions: id-token: write`; the subject is
  `repo:<owner>/<repo>:environment:<name>` for a job in an
  environment, `repo:<owner>/<repo>:ref:refs/heads/<branch>`
  otherwise. Two roles, two environments: the plan role trusts the
  environment without reviewers, the apply role the environment that
  holds the approval, so a pull request's plan job cannot assume the
  apply role.
- **GitLab CI** issues one per `id_tokens:` entry, with the `aud`
  the job sets; the subject is
  `project_path:<group>/<project>:ref_type:branch:ref:<branch>`, and
  `ref_protected` says whether the branch is protected. For AWS the
  token goes into a file the job names in
  `AWS_WEB_IDENTITY_TOKEN_FILE`, with `AWS_ROLE_ARN` beside it.
- **Forgejo and Gitea Actions** issue no token a cloud trusts: a
  pipeline there takes static secrets, each in the register, or
  plans only.

## The register

Every credential above is an entry in `memory/infra/credentials.md`,
as `rules/infra-code.md` → Credentials shows; a federated identity
has no expiry and nothing to rotate.
