#!/bin/sh
# tests/bin/hostwarden-tofu.sh — fixture matrix for bin/hostwarden-tofu
# and lib/infra.sh (rules/opentofu.md, rules/infra-code.md). CI runs
# it through scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# Everything runs in an operations checkout of its own under TMP,
# with stand-ins for tofu, terragrunt, tflint, trivy, checkov and op
# on PATH that record their arguments and answer from fixtures. jq is
# the real one.

cd "$(dirname "$0")/../.." || exit 2
REPO=$(pwd -P)
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp tofu
TMP=$(cd "$TMP" && pwd -P)

JQ=$(command -v jq) || { echo "tofu: no jq"; exit 2; }
# shellcheck source=infra-fixture.sh
. "$REPO/tests/bin/infra-fixture.sh"
infra_fixture hostwarden-tofu
OPS_TREE=$OPS/memory/infra/opentofu/web
mkdir -p "$OPS_TREE" "$TMP/ext/hosting"
ln -s "$JQ" "$TMP/fake/jq"
# The plan lives under this checkout's cache directory.
# shellcheck source=../../lib/mode.sh
. "$REPO/lib/mode.sh"
hostwarden_cache_dir "$OPS"
PLAN=$HOSTWARDEN_CACHE/tofu/workspace-web.tfplan

# shellcheck source=hostwarden-tofu/stand-ins.sh
. "$REPO/tests/bin/hostwarden-tofu/stand-ins.sh"


# --- usage and resolution -----------------------------------------
expect_rc 0 "--help" hw --help
has_out "hostwarden-tofu <stack> check" "--help"
expect_rc 2 "no verb" hw web
expect_rc 2 "unknown verb" hw web frobnicate
expect_rc 1 "no such stack" hw nothere plan
has_out "no opentofu tree nothere" "no such stack"
expect_rc 1 "a path is no name" hw ../etc plan

# An external tree, named in memory/user.md.
: > "$TMP/ext/hosting/main.tf"
printf '# Infrastructure code\n\n- opentofu hosting: %s\n' "$TMP/ext/hosting" \
  > "$OPS/memory/user.md"
expect_rc 0 "external tree plans" hw hosting plan
has_log "tofu plan -input=false -lock-timeout=60s -detailed-exitcode -out=$HOSTWARDEN_CACHE/tofu/external-hosting.tfplan" "external plan"
printf '# Infrastructure code\n\n- opentofu hosting: ext/hosting\n' > "$OPS/memory/user.md"
expect_rc 1 "a relative external path" hw hosting plan
has_out "not absolute" "relative external path"
rm -f "$OPS/memory/user.md"

# --- check ----------------------------------------------------------
: > "$LOG"
expect_rc 0 "check" hw web check
has_log "tofu fmt -check -diff -recursive" "check fmt"
has_log "tofu init -backend=false -input=false" "check init"
has_log "tofu validate" "check validate"
has_log "tflint --recursive" "check tflint"
has_log "trivy config --exit-code 1 ." "check trivy"
has_log "checkov -d . --framework terraform --quiet --compact" "check checkov"
has_out "check passed" "check"
# A failing step ends the run there: nothing after it runs.
echo 1 > "$TMP/fmt-rc"
: > "$LOG"
expect_rc 1 "check stops at fmt" hw web check
has_out "tofu fmt -check failed" "check stops"
no_log "tofu validate" "check stops before validate"
rm -f "$TMP/fmt-rc"
echo 1 > "$TMP/trivy-rc"
expect_rc 1 "check stops at trivy" hw web check
has_out "trivy config failed" "trivy fails"
rm -f "$TMP/trivy-rc"
# A checker that is not installed is named as skipped.
mv "$TMP/fake/checkov" "$TMP/checkov.away"
expect_rc 0 "check without checkov" hw web check
has_out "checkov: skipped, checkov is not installed" "checkov skipped"
mv "$TMP/checkov.away" "$TMP/fake/checkov"
# .tflint.hcl brings tflint --init first.
: > "$OPS_TREE/.tflint.hcl"
: > "$LOG"
expect_rc 0 "check with .tflint.hcl" hw web check
has_log "tflint --init" "tflint init"
rm -f "$OPS_TREE/.tflint.hcl"

# --- plan, review, apply --------------------------------------------
: > "$LOG"
expect_rc 0 "plan" hw web plan
has_log "tofu init -input=false" "plan inits a fresh tree"
: > "$LOG"
hw web plan >/dev/null 2>&1
has_log "tofu init -input=false" "plan inits again after a check left .terraform"
has_log "tofu plan -input=false -lock-timeout=60s -detailed-exitcode -out=$PLAN" "plan"
has_out "plan: 1 to add, 1 to change, 0 to destroy, 0 to replace" "plan summary"
has_out "plan saved" "plan saved"
[ -f "$PLAN" ] && ok || bad "plan file missing"
# shellcheck disable=SC2034 # INFRA_PROG: read by infra_die
(INFRA_PROG=t; . "$OPS/lib/infra.sh"; infra_mode600 "$PLAN") >/dev/null 2>&1 && ok || bad "plan file is not mode 600"
grep -q '^TF_IN_AUTOMATION=1$' "$TMP/env" && ok || bad "TF_IN_AUTOMATION unset"
grep -q '^TF_INPUT=0$' "$TMP/env" && ok || bad "TF_INPUT unset"
# A plan without changes leaves no file.
echo 0 > "$TMP/plan-rc"
expect_rc 0 "plan without changes" hw web plan
has_out "plan: no changes" "no changes"
[ -f "$PLAN" ] && bad "a plan file after no changes" || ok
# A failed plan is a failure.
echo 1 > "$TMP/plan-rc"
expect_rc 1 "plan failure" hw web plan
rm -f "$TMP/plan-rc"
# Arguments the rule keeps from the session.
for a in -auto-approve -auto-approve=true -lock=false -lock=0 -lock=f \
    -show-sensitive -show-sensitive=1 -destroy -destroy=true -destroy=T \
    -target=x; do
  expect_rc 3 "plan $a" hw web plan "$a"
done
expect_rc 0 "plan -lock=true" hw web plan -lock=true
expect_rc 0 "plan -destroy=false" hw web plan -destroy=false
for a in -migrate-state -force-copy -reconfigure -migrate-state=true --force-copy=true --reconfigure=1; do
  expect_rc 3 "init $a" hw web init "$a"
done
expect_rc 3 "init with a secret in -backend-config" hw web init -backend-config=password=x
expect_rc 3 "init with a secret key in -backend-config" hw web init -backend-config secret_key=x
expect_rc 0 "init with the state key in -backend-config" hw web init -backend-config=key=prod/web.tfstate
expect_rc 3 "init with access_key in -backend-config" hw web init -backend-config=access_key=x
expect_rc 3 "init with sse_customer_key in -backend-config" hw web init -backend-config sse_customer_key=x
expect_rc 0 "init -upgrade" hw web init -upgrade
expect_rc 3 "a secret in -var" hw web plan -var db_password=x
expect_rc 3 "a secret in -var=" hw web plan -var=api_token=x
expect_rc 0 "a plain -var" hw web plan -var region=fsn1
# Review and a non-destructive apply.
expect_rc 0 "review" hw web review
has_log "tofu show $PLAN" "review shows the plan"
has_out "create	hcloud_server.web2" "review lists creates"
has_out "update	hcloud_firewall.web" "review lists updates"
case "$OUT" in *no-op*) bad "review lists no-ops" ;; *) ok ;; esac
: > "$LOG"
expect_rc 0 "apply" hw web apply
has_log "tofu apply -input=false -lock-timeout=60s $PLAN" "apply"
has_out "applied" "apply"
[ -f "$PLAN" ] && bad "plan file kept after apply" || ok
expect_rc 1 "apply without a plan" hw web apply
has_out "no saved plan" "apply without plan"
# A plan that cannot be read is not applied.
hw web plan >/dev/null 2>&1
echo 1 > "$TMP/show-rc"
: > "$LOG"
expect_rc 1 "apply of an unreadable plan" hw web apply
has_out "could not be read" "unreadable plan refused"
no_log "tofu apply" "unreadable plan not applied"
rm -f "$TMP/show-rc"
hw web apply >/dev/null 2>&1
# The plan JSON is read with the credentials.
mkdir -p "$HOME/hostwarden-keys/infra/opentofu/web"
printf 'TF_VAR_state_passphrase=pp\n' > "$HOME/hostwarden-keys/infra/opentofu/web/env"
chmod 600 "$HOME/hostwarden-keys/infra/opentofu/web/env"
hw web plan >/dev/null 2>&1
expect_rc 0 "review with credentials" hw web review
grep -q '^TF_VAR_state_passphrase=pp$' "$TMP/env" && ok || bad "show -json ran without the credentials"
rm -f "$HOME/hostwarden-keys/infra/opentofu/web/env"
# A destructive plan is the user's, through the same program.
hw web plan >/dev/null 2>&1
echo plan-replace.json > "$TMP/plan-file"
: > "$LOG"
expect_rc 3 "apply of a replace" hw web apply
has_out "deletes or replaces" "destructive apply refused"
has_out "bin/hostwarden-tofu web apply --destroys" "destructive apply names the command"
no_log "tofu apply" "destructive apply did not run"
[ -f "$PLAN" ] && ok || bad "plan file removed on refusal"
: > "$LOG"
expect_rc 0 "apply --destroys" hw web apply --destroys
has_log "tofu apply -input=false -lock-timeout=60s $PLAN" "destroys applied"
echo plan.json > "$TMP/plan-file"
hw web plan >/dev/null 2>&1
# Deployment: ci hands the apply to the pipeline.
printf -- '- Deployment: ci github hostwarden/infra opentofu.yml\n' \
  > "$OPS_TREE/hostwarden.md"
expect_rc 3 "apply under Deployment: ci" hw web apply
has_out "the pipeline applies" "ci apply"
printf -- '- Deployment: CI\n' > "$OPS_TREE/hostwarden.md"
expect_rc 3 "apply under Deployment: CI" hw web apply
printf -- '- Deployment: banana\n' > "$OPS_TREE/hostwarden.md"
expect_rc 1 "apply under an unknown Deployment" hw web apply
has_out "none of local, ci, mixed" "unknown Deployment named"
printf -- '- Deployment: mixed\n' > "$OPS_TREE/hostwarden.md"
expect_rc 0 "apply under Deployment: mixed" hw web apply
rm -f "$OPS_TREE/hostwarden.md"

# --- drift, test, the read verbs, the refused ones ------------------
: > "$LOG"
: > "$LOG"
expect_rc 4 "drift with changes" hw web drift
has_log "tofu init -input=false" "drift initialises the backend"
has_log "tofu plan -input=false -lock-timeout=60s -refresh-only -detailed-exitcode" "drift"
has_out "drift:" "drift"
echo 0 > "$TMP/plan-rc"
expect_rc 0 "no drift" hw web drift
rm -f "$TMP/plan-rc"
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
run "creates" {
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 3 "an apply test" hw web test
has_out "apply.tftest.hcl" "apply test named"
has_out "bin/hostwarden-tofu web test --applies" "apply test names the command"
: > "$LOG"
expect_rc 0 "test --applies" hw web test --applies
has_log "tofu test" "applies test runs"
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
run "plans" {
  command = plan
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 0 "a plan test" hw web test
has_log "tofu test" "plan test runs"
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
mock_provider "hcloud" {}
run "mocked" {
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 3 "a mocked test of a tree that names no provider" hw web test
cat > "$OPS_TREE/versions.tf" <<'EOF'
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}
EOF
: > "$LOG"
expect_rc 0 "a mocked test" hw web test
has_log "tofu init -input=false -backend=false" "test initialises the providers only"
printf 'resource "terraform_data" "x" {}\n' > "$OPS_TREE/main.tf"
expect_rc 0 "a mocked test of a tree with a built-in resource" hw web test
rm -f "$OPS_TREE/main.tf"
cat > "$OPS_TREE/versions.tf" <<'EOF'
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}
EOF
expect_rc 3 "a test that mocks one of two providers" hw web test
has_out "apply.tftest.hcl" "half-mocked test named"
cat > "$OPS_TREE/versions.tf" <<'EOF'
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}
EOF
printf 'resource "aws_instance" "x" {}\n' > "$OPS_TREE/main.tf"
expect_rc 3 "a test that mocks the declared provider but not one in use" hw web test
# An aliased mock leaves the default configuration real; a provider
# block or a providers mapping selects configurations by name.
rm -f "$OPS_TREE/main.tf"
cat > "$OPS_TREE/versions.tf" <<'EOF'
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}
EOF
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
mock_provider "hcloud" {
  alias = "mocked"
}
run "creates" {
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 3 "a test that mocks an alias only" hw web test
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
mock_provider "hcloud" { alias = "mocked" }
run "creates" {
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 3 "a test that mocks an alias on one line" hw web test
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
mock_provider "hcloud" {
  mock_resource "hcloud_server" {
    defaults = {
      id = "1"
    }
  }
  alias = "mocked"
}
run "creates" {
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 3 "a test whose alias follows a nested block" hw web test
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
mock_provider "hcloud" {
  mock_resource "hcloud_server" {
    defaults = {
      id = "1"
    }
  }
}
run "creates" {
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 0 "a default mock with a nested block" hw web test
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
mock_provider "hcloud" {}
provider "hcloud" {
  alias = "real"
}
run "creates" {
  providers = {
    hcloud = hcloud.real
  }
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 3 "a test with a provider mapping" hw web test
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
mock_provider "hcloud" {}
run "creates" {
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 0 "a test that mocks the default provider" hw web test
# A provisioner runs for real under any mock.
cat > "$OPS_TREE/versions.tf" <<'EOF'
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}
EOF
cat > "$OPS_TREE/main.tf" <<'EOF'
resource "terraform_data" "x" {
  provisioner "local-exec" {
    command = "true"
  }
}
EOF
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
mock_provider "hcloud" {}
run "creates" {
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 3 "a mocked test of a tree with a provisioner" hw web test
cat > "$OPS_TREE/apply.tftest.hcl" <<'EOF'
run "plans" {
  command = plan
  assert { condition = true; error_message = "x" }
}
EOF
expect_rc 0 "a plan-only test of a tree with a provisioner" hw web test
rm -f "$OPS_TREE/apply.tftest.hcl" "$OPS_TREE/versions.tf" "$OPS_TREE/main.tf"
expect_rc 3 "test -test-directory" hw web test -test-directory=tests/unit
: > "$LOG"
expect_rc 0 "output" hw web output
has_log "tofu init -input=false" "output initialises the backend"
expect_rc 3 "output -json" hw web output -json
expect_rc 3 "output -json=true" hw web output -json=true
expect_rc 3 "output -raw" hw web output -raw x
expect_rc 3 "output -raw=1" hw web output -raw=1 x
: > "$LOG"
expect_rc 0 "state list" hw web state list
has_log "tofu init -input=false" "state initialises the backend"
expect_rc 3 "state rm" hw web state rm x
expect_rc 3 "state pull" hw web state pull
expect_rc 0 "workspace list" hw web workspace list
expect_rc 3 "workspace delete" hw web workspace delete old
for v in destroy import taint untaint force-unlock refresh console; do
  expect_rc 3 "$v refused" hw web "$v"
done
no_log "tofu destroy" "destroy never ran"
expect_rc 3 "workspace select -or-create" hw web workspace select -or-create prod
expect_rc 3 "workspace select -or-create=true" hw web workspace select -or-create=true prod
expect_rc 0 "workspace select" hw web workspace select prod
expect_rc 3 "providers mirror" hw web providers mirror /tmp/mirror
expect_rc 0 "providers lock" hw web providers lock
: > "$LOG"
expect_rc 0 "fmt" hw web fmt
has_log "tofu fmt" "fmt formats the tree"
expect_rc 0 "fmt -check -diff" hw web fmt -check -diff
expect_rc 1 "fmt outside the tree" hw web fmt /etc/x.tf

# shellcheck source=hostwarden-tofu/imports.sh
. "$REPO/tests/bin/hostwarden-tofu/imports.sh"

# --- terragrunt -----------------------------------------------------
: > "$OPS_TREE/terragrunt.hcl"
: > "$LOG"
expect_rc 0 "terragrunt plan" hw web plan
has_log "terragrunt plan -input=false" "terragrunt plans"
grep -q "^TG_TF_PATH=$TMP/fake/tofu$" "$TMP/env" && ok || bad "TG_TF_PATH: $(cat "$TMP/env")"
grep -q '^TG_NON_INTERACTIVE=true$' "$TMP/env" && ok || bad "TG_NON_INTERACTIVE unset"
: > "$LOG"
expect_rc 0 "terragrunt check" hw web check
has_log "terragrunt hcl fmt --check" "terragrunt fmt"
has_log "terragrunt validate" "terragrunt validate"
no_log "tofu init" "terragrunt check does not init with tofu"
rm -f "$OPS_TREE/terragrunt.hcl"

# --- credentials ----------------------------------------------------
# A personal env file, mode 600, reaches the tool and nothing else.
mkdir -p "$HOME/hostwarden-keys/infra/opentofu/web"
ENVF=$HOME/hostwarden-keys/infra/opentofu/web/env
printf 'HCLOUD_TOKEN=t0ken\nAWS_ACCESS_KEY_ID=AKIA\n' > "$ENVF"
chmod 600 "$ENVF"
expect_rc 0 "plan with a local env" hw web plan
grep -q '^HCLOUD_TOKEN=t0ken$' "$TMP/env" && ok || bad "env not passed"
grep -q '^AWS_ACCESS_KEY_ID=AKIA$' "$TMP/env" && ok || bad "second var not passed"
case "$OUT" in *t0ken*) bad "the token in the output" ;; *) ok ;; esac
chmod 644 "$ENVF"
expect_rc 1 "a readable env file" hw web plan
has_out "mode 600" "readable env file refused"
chmod 600 "$ENVF"
printf 'rm -rf /\n' > "$ENVF"
expect_rc 1 "an env line that is not VAR=value" hw web plan
rm -f "$ENVF"
# secrets.env with references: through op run, under the stored
# token; a value in the clear stops the run.
SE=$OPS_TREE/secrets.env
printf 'HCLOUD_TOKEN=op://V/hcloud/token\n' > "$SE"
expect_rc 1 "references without a token" hw web plan
has_out "stores its token" "no token"
(
  # shellcheck disable=SC2034 # read by lib/passwords.sh
  PW_ROOT=$OPS
  # shellcheck source=../../lib/passwords.sh
  . "$OPS/lib/passwords.sh"
  printf 'ops-token' | pw_local_put file token 1password
) || bad "storing the token"
: > "$LOG"
expect_rc 0 "references through op run" hw web plan
has_log "op run --env-file=$SE -- tofu plan" "op run"
has_log "op vault list" "the token's vaults checked"
[ "$(cat "$TMP/op-token")" = ops-token ] && ok || bad "the token did not reach op"
[ -f "$TMP/op-ran" ] && ok || bad "tofu did not run under op"
printf 'HCLOUD_TOKEN=op://Other/hcloud/token\n' > "$SE"
expect_rc 1 "a reference to another vault" hw web plan
printf 'HCLOUD_TOKEN=t0ken\n' > "$SE"
expect_rc 1 "a value in the clear" hw web plan
has_out "value in the clear" "clear value refused"
rm -f "$SE"

# --- a development checkout runs nothing -------------------------
rm -f "$OPS/memory/.hostwarden-workspace"
expect_rc 1 "development checkout" hw web plan
has_out "only an operations checkout" "development refused"
: > "$OPS/memory/.hostwarden-workspace"

finish tofu
