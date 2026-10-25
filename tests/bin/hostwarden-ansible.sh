#!/bin/sh
# tests/bin/hostwarden-ansible.sh — fixture matrix for
# bin/hostwarden-ansible (rules/workspace-playbook.md). CI runs it
# through scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# Everything runs in an operations checkout of its own under TMP,
# with stand-ins for ansible-playbook, ansible, ansible-lint,
# ansible-galaxy, ansible-inventory and ansible-doc on PATH that
# record their arguments and environment.

cd "$(dirname "$0")/../.." || exit 2
REPO=$(pwd -P)
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp ansible
TMP=$(cd "$TMP" && pwd -P)

# shellcheck source=infra-fixture.sh
. "$REPO/tests/bin/infra-fixture.sh"
infra_fixture hostwarden-ansible
TREE=$OPS/memory/infra/ansible
mkdir -p "$TREE/roles" "$OPS/memory/infra/prod" "$TMP/ext/site"
: > "$OPS/memory/ssh_config"
printf '[defaults]\n' > "$TREE/ansible.cfg"
printf 'web1.example.com\n' > "$TREE/inventory"
: > "$TREE/site.yml"
: > "$TREE/nginx.yml"
: > "$OPS/memory/infra/prod/site.yml"
printf 'all:\n' > "$OPS/memory/infra/prod/hosts.yml"

# --- stand-ins ----------------------------------------------------
# ansible-playbook prints the recap $TMP/recap holds, with changed=0
# unless $TMP/changed says otherwise.
for t in ansible-playbook ansible ansible-lint ansible-galaxy \
    ansible-inventory ansible-doc; do
  cat > "$TMP/fake/$t" <<EOF
#!/bin/sh
echo "$t \$*" >> "$LOG"
env | grep -E '^(ANSIBLE_|SSH_ASKPASS|VAULT_)' | sort > "$TMP/env"
pwd > "$TMP/cwd"
echo "\$#" > "$TMP/argc-$t"
[ -f "$TMP/$t-rc" ] && exit "\$(cat "$TMP/$t-rc")"
if [ "$t" = ansible-playbook ]; then
  c=0; [ -f "$TMP/changed" ] && c=\$(cat "$TMP/changed")
  echo "PLAY RECAP *****"
  [ ! -f "$TMP/empty-recap" ] || exit 0
  echo "web1.example.com : ok=3 changed=\$c unreachable=0 failed=0 skipped=0 rescued=0 ignored=0"
  echo "web2.example.com : ok=3 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0"
fi
exit 0
EOF
done
chmod 755 "$TMP"/fake/*

# --- usage ----------------------------------------------------------
expect_rc 0 "--help" hw --help
has_out "hostwarden-ansible [--tree <name>] check" "--help"
expect_rc 2 "no verb" hw
expect_rc 2 "unknown verb" hw frobnicate
expect_rc 1 "no such tree" hw --tree nothere check
has_out "no ansible tree nothere" "no such tree"

# --- check, diff, apply: the environment and the inventory ---------
: > "$LOG"
expect_rc 0 "check" hw check
has_log "ansible-playbook -i $TREE/inventory --syntax-check $TREE/site.yml" "syntax check"
has_log "ansible-lint --offline" "lint"
has_out "check passed" "check"
has_env "ANSIBLE_CONFIG=$TREE/ansible.cfg" "ANSIBLE_CONFIG"
has_env "ANSIBLE_SSH_ARGS=-F '$OPS/memory/ssh_config'" "ANSIBLE_SSH_ARGS"
has_env "SSH_ASKPASS=$OPS/bin/hostwarden-askpass" "SSH_ASKPASS"
has_env "SSH_ASKPASS_REQUIRE=force" "SSH_ASKPASS_REQUIRE"
has_env "ANSIBLE_NOCOLOR=1" "no colour without a terminal"
[ "$(cat "$TMP/cwd")" = "$TREE" ] && ok || bad "cwd $(cat "$TMP/cwd")"
expect_rc 0 "check of two playbooks" hw check site.yml nginx.yml
: > "$TREE/my site.yml"
expect_rc 0 "check of a playbook with a space in its name" hw check "my site.yml"
has_log "--syntax-check $TREE/my site.yml" "space kept"
[ "$(cat "$TMP/argc-ansible-playbook")" = 4 ] && ok || bad "a path with a space split: $(cat "$TMP/argc-ansible-playbook") arguments"
rm -f "$TREE/my site.yml"
has_log "--syntax-check $TREE/site.yml $TREE/nginx.yml" "two playbooks"
echo 1 > "$TMP/ansible-lint-rc"
expect_rc 1 "check with lint findings" hw check
rm -f "$TMP/ansible-lint-rc"
mv "$TMP/fake/ansible-lint" "$TMP/lint.away"
expect_rc 0 "check without ansible-lint" hw check
has_out "ansible-lint: skipped" "lint skipped"
mv "$TMP/lint.away" "$TMP/fake/ansible-lint"
: > "$LOG"
expect_rc 0 "diff" hw diff site.yml --limit web1.example.com
has_log "ansible-playbook -i $TREE/inventory --check --diff $TREE/site.yml --limit web1.example.com" "diff"
expect_rc 0 "diff with its own inventory" hw diff site.yml -i "$TREE/other"
has_log "ansible-playbook --check --diff $TREE/site.yml -i $TREE/other" "own inventory"
expect_rc 0 "apply" hw apply site.yml
has_log "ansible-playbook -i $TREE/inventory $TREE/site.yml" "apply"
expect_rc 1 "a playbook outside the tree" hw apply ../prod/site.yml
has_out "outside the tree" "outside"
expect_rc 1 "a playbook that is not there" hw apply nothere.yml
# ansible.cfg's inventory wins over the file in the tree.
printf '[defaults]\ninventory = hosts/\n' > "$TREE/ansible.cfg"
expect_rc 0 "ansible.cfg inventory" hw diff site.yml
has_log "ansible-playbook -i hosts/ --check --diff" "cfg inventory"
printf '[defaults]\n' > "$TREE/ansible.cfg"

# --- verify ---------------------------------------------------------
expect_rc 0 "verify with changed=0" hw verify site.yml
has_out "verified: changed=0 on every host" "verify"
echo 2 > "$TMP/changed"
expect_rc 1 "verify with a change" hw verify site.yml
has_out "not idempotent" "verify finds a change"
has_out "web1.example.com" "verify names the host"
rm -f "$TMP/changed"
# A second run that fails, or ends without a recap, verifies nothing.
echo 2 > "$TMP/ansible-playbook-rc"
expect_rc 1 "verify with a failed run" hw verify site.yml
has_out "the second run failed" "failed run named"
rm -f "$TMP/ansible-playbook-rc"
expect_rc 3 "verify with a refused -e" hw verify site.yml -e db_password=x
case "$OUT" in *verified*) bad "a refused run read as verified" ;; *) ok ;; esac

# A recap without a host verifies nothing.
: > "$TMP/empty-recap"
expect_rc 1 "verify with an empty recap" hw verify site.yml --limit nothere
has_out "reached no host" "empty recap named"
case "$OUT" in *"verified: "*) bad "an empty recap read as verified" ;; *) ok ;; esac
rm -f "$TMP/empty-recap"

# --- secrets in -e, the vault, the trees ---------------------------
expect_rc 3 "a secret in -e" hw diff site.yml -e db_password=x
expect_rc 3 "a secret in --extra-vars=" hw apply site.yml --extra-vars=api_token=x
expect_rc 0 "a plain -e" hw diff site.yml -e nginx_workers=4
mkdir -p "$HOME/hostwarden-keys/infra/ansible/ansible"
VP=$HOME/hostwarden-keys/infra/ansible/ansible/vault-password
: > "$VP"
chmod 600 "$VP"
expect_rc 0 "with a vault password file" hw diff site.yml
has_log "--vault-password-file $VP" "vault named"
chmod 644 "$VP"
expect_rc 1 "a readable vault password file" hw diff site.yml
rm -f "$VP"
expect_rc 0 "another workspace tree" hw --tree prod diff site.yml
has_log "ansible-playbook -i $OPS/memory/infra/prod/hosts.yml --check --diff $OPS/memory/infra/prod/site.yml" "prod tree"
: > "$TMP/ext/site/site.yml"
printf 'web1\n' > "$TMP/ext/site/hosts"
printf '# Infrastructure code\n\n- ansible site: %s\n' "$TMP/ext/site" > "$OPS/memory/user.md"
expect_rc 0 "an external tree" hw --tree=site diff site.yml
has_log "-i $TMP/ext/site/hosts --check --diff $TMP/ext/site/site.yml" "external tree"
rm -f "$OPS/memory/user.md"

# --- the read verbs and galaxy --------------------------------------
: > "$LOG"
expect_rc 0 "inventory" hw inventory
has_log "ansible-inventory -i $TREE/inventory --graph" "inventory --graph"
expect_rc 0 "doc" hw doc ansible.builtin.apt
has_log "ansible-doc ansible.builtin.apt" "doc"
expect_rc 0 "ping" hw ping all
has_log "ansible -i $TREE/inventory all -m ping" "ping"
expect_rc 0 "facts" hw facts web1.example.com 'ansible_distribution*'
has_log "ansible -i $TREE/inventory web1.example.com -m setup -a filter=ansible_distribution*" "facts"
expect_rc 0 "playbook --list-tasks" hw playbook --list-tasks site.yml
has_log "ansible-playbook -i $TREE/inventory --list-tasks site.yml" "list-tasks"
expect_rc 3 "playbook with a secret in -e" hw playbook site.yml -e vault_pass=x
expect_rc 1 "playbook outside the tree" hw playbook --check /tmp/other.yml
has_out "outside the tree" "playbook confined"
expect_rc 1 "playbook with an inventory outside the tree" hw playbook --check -i /etc/ansible/hosts site.yml
expect_rc 0 "playbook with a pattern" hw playbook --check site.yml --limit web1.example.com
mkdir -p "$TREE/group_vars"
: > "$TREE/group_vars/all.yml"
expect_rc 0 "playbook with a vars file" hw playbook --check site.yml -e @group_vars/all.yml -e nginx_workers=4 -e 'url=https://example.com/x'
expect_rc 1 "playbook with a vars file outside the tree" hw playbook --check site.yml -e @/etc/vars.yml
expect_rc 1 "playbook with --inventory= outside the tree" hw playbook --check --inventory=/etc/ansible/hosts site.yml
expect_rc 1 "playbook with -i attached outside the tree" hw playbook --check -i/etc/ansible/hosts site.yml
expect_rc 1 "playbook with --extra-vars=@ outside the tree" hw playbook --check --extra-vars=@/etc/vars.yml site.yml
expect_rc 1 "diff with a second playbook outside the tree" hw diff site.yml /etc/other.yml
expect_rc 1 "apply with an inventory outside the tree" hw apply site.yml -i /etc/ansible/hosts
expect_rc 0 "diff with an inventory inside the tree" hw diff site.yml -i "$TREE/inventory"
expect_rc 1 "a host list as inventory" hw playbook --check -i web1.example.com, site.yml
has_out "host list" "host list refused"
expect_rc 1 "a host list as attached -i" hw playbook --check -iweb1.example.com, site.yml
expect_rc 1 "a host list on diff" hw diff site.yml --inventory=web1.example.com,
expect_rc 0 "a --limit list with commas" hw playbook --check site.yml --limit web1.example.com,web2.example.com
expect_rc 1 "galaxy without requirements" hw galaxy
cat > "$TREE/requirements.yml" <<'EOF'
collections:
  - name: community.general
    version: 9.5.0
  - name: ansible.posix
    version: ">=1.5.0"
  - name: hetzner.hcloud
EOF
expect_rc 3 "galaxy with loose pins" hw galaxy
has_out "ansible.posix: >=1.5.0" "loose range named"
has_out "hetzner.hcloud: no version" "missing version named"
no_log "ansible-galaxy" "galaxy did not install"
cat > "$TREE/requirements.yml" <<'EOF'
collections:
  - community.crypto
  - src: https://git.example.com/x.git
    type: git
    version: main
  - {name: ansible.utils, version: ">=2.0"}
  - name: community.general
    version: 9.5.0 # pinned
roles:
  - name: geerlingguy.nginx
EOF
expect_rc 3 "galaxy with plain, git-branch and inline entries" hw galaxy
has_out "community.crypto: no version" "plain name named"
has_out "https://git.example.com/x.git: main" "git branch named"
has_out "ansible.utils: >=2.0" "inline range named"
case "$OUT" in *community.general*) bad "a pinned entry named" ;; *) ok ;; esac
case "$OUT" in *geerlingguy*) bad "a role named" ;; *) ok ;; esac
# A pinned entry from another Galaxy server, with a nested list, is
# pinned.
cat > "$TREE/requirements.yml" <<'EOF'
collections:
  - name: community.general
    source: https://galaxy.example.com
    version: 9.5.0
    signatures:
      - file:///keys/a.asc
      - https://keys.example.com/b.asc
  - name: https://git.example.com/y.git
    type: git
    version: 0123456789abcdef0123456789abcdef01234567
EOF
expect_rc 0 "galaxy with a server and signatures" hw galaxy
cat > "$TREE/requirements.yml" <<'EOF'
collections:
  - src: git@git.example.com:x/y.git
    version: abcdef1
  - name: git@git.example.com:x/z.git
    version: main
EOF
expect_rc 3 "galaxy with an scp-style git source" hw galaxy
has_out "git@git.example.com:x/z.git: main" "scp-style branch named"
case "$OUT" in *x/y.git*) bad "a pinned scp-style source named" ;; *) ok ;; esac
printf 'collections: [community.general]\n' > "$TREE/requirements.yml"
expect_rc 3 "galaxy with a flow sequence" hw galaxy
has_out "flow sequence" "flow sequence named"
printf 'collections: []\n' > "$TREE/requirements.yml"
expect_rc 0 "galaxy with an empty flow sequence" hw galaxy
cat > "$TREE/requirements.yml" <<'EOF'
collections:
  - name: community.general
    version: "9.5.0"
  - name: https://git.example.com/x/collection.git
    type: git
    version: 0123456789abcdef0123456789abcdef01234567
EOF
expect_rc 0 "galaxy with exact pins" hw galaxy
has_log "ansible-galaxy collection install -r $TREE/requirements.yml -p $TREE/collections" "galaxy"

# --- a development checkout runs nothing -------------------------
rm -f "$OPS/memory/.hostwarden-workspace"
expect_rc 1 "development checkout" hw check
has_out "only an operations checkout" "development refused"
: > "$OPS/memory/.hostwarden-workspace"

finish ansible
