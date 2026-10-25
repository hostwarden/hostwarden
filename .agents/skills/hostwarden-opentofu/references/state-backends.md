# State backends

The `backend` block for the storage a stack's state lives in, what
the bucket needs, and the `encryption` block. The rule is in
`rules/opentofu.md` → State: remote, locked, versioned, never
printed, never written by hand. Every argument below is the name
OpenTofu's S3 backend documentation gives at the time of writing;
confirm against the current page before writing a block, and take
a provider's endpoint and region from that provider's documentation.

## AWS

```hcl
terraform {
  backend "s3" {
    bucket       = "example-infra-state"
    key          = "hosting/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}
```

Credentials come from the environment, never from the block:
`AWS_PROFILE` after `aws sso login` on the workstation; in a
pipeline the role the forge's token assumes
(`AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE`, or the
`assume_role_with_web_identity` block). `access_key` and
`secret_key` in the block are never written.

The bucket: versioning on, public access blocked, server-side
encryption on, a lifecycle rule that keeps old versions for as long
as the team wants to be able to go back. `use_lockfile` writes a
`.tflock` object beside the state with a conditional put; a
`dynamodb_table` lock still works and is not deprecated, so a stack
that has one keeps it until the user says otherwise.

## S3-compatible storage

Hetzner Object Storage, Scaleway Object Storage, OVHcloud Object
Storage, Cloudflare R2, MinIO and the like take the same block with
the endpoint named and the AWS-only checks switched off:

```hcl
terraform {
  backend "s3" {
    bucket = "example-infra-state"
    key    = "hosting/terraform.tfstate"
    region = "<the provider's region name>"
    endpoints = {
      s3 = "https://<the provider's S3 endpoint>"
    }
    use_lockfile                = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
```

Which of the `skip_*` flags a provider needs, whether its endpoint
takes `use_path_style` or a bucket-in-hostname address, whether its
region is a real name or a placeholder, and whether its conditional
writes support `use_lockfile` — some providers do not, and the lock
then silently does nothing — come from that provider's documentation
on using it with Terraform or OpenTofu, read at setup, never from
memory. Where the provider offers no conditional writes, say so: the
lock is then the session register and the team's discipline, and a
`Deployment: mixed` tree is not safe there.

The access key and secret key of the storage go into the stack's
credentials like any other (`references/credentials.md`): as
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in `secrets.env` or
the personal `env` file, since that is what the S3 backend reads.
They are scoped to the state bucket alone, read and write, and they
are a second credential in the register beside the provider's own.

## Encryption

```hcl
terraform {
  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }
    state {
      method   = method.aes_gcm.state
      enforced = true
    }
    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}
```

The passphrase comes from the environment through `TF_VAR_state_passphrase`
in `secrets.env` or the personal file, never from a `.tfvars` in the
tree, and it is one more entry in the register: losing it loses the
state. A KMS or OpenBao key provider takes its place where the team
has one; the block's shape is in OpenTofu's encryption
documentation. Turning encryption on for a state that exists is a
migration: the `fallback` block reads the unencrypted state once,
the next write encrypts it, and `enforced` is set only after that
write.

## Moving a state

```bash operator
cd /srv/hostwarden/memory/infra/opentofu/hosting && tofu init -migrate-state
```

The user runs it after the new `backend` block is in the tree, with
a copy of the old state outside the workspace; OpenTofu asks before
it copies. Then `bin/hostwarden-tofu hosting plan` shows no changes,
and the user deletes `terraform.tfstate` and
`terraform.tfstate.backup` from the tree.
