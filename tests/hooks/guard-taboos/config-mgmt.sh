# tests/hooks/guard-taboos/config-mgmt.sh — configuration
# management tools (guard-taboos.d/config-mgmt.sh). Sourced by
# tests/hooks/guard-taboos.sh, in its order, into the one shell every
# part shares; never run on its own.
# shellcheck shell=sh

# --- a playbook from the workspace -------------------------------
# The guard reads where a playbook comes from: memory/ of the
# checkout it sits in, which for this matrix is the operations copy.
# A playbook and an inventory there pass, with or without --check;
# anything elsewhere, relative, through a variable or with a ..
# segment is denied, and so is a run without an inventory.
WSD=$GUARD_TREES/ops/memory/infra/web
check pass "ansible-playbook -i $WSD/inventory --check --diff --limit web1.example.com $WSD/site.yml"
check pass "ANSIBLE_CONFIG=$WSD/ansible.cfg ANSIBLE_SSH_ARGS='-F /srv/hostwarden/memory/ssh_config' ansible-playbook -i $WSD/inventory $WSD/site.yml --check --diff -l web1.example.com"
check pass "ansible-playbook --inventory=$WSD/hosts.yml $WSD/site.yml --limit web1.example.com"
check pass "ansible-playbook -i$WSD/inventory $WSD/site.yml -e @$WSD/group_vars/all.yml"
check pass "ansible-playbook -i $WSD/inventory -e 'nginx_workers=4' $WSD/site.yml"
check pass "ansible-playbook -i $WSD/inventory $WSD/site.yml $WSD/nginx.yaml"
check pass "cd $WSD && ansible-playbook -i $WSD/inventory $WSD/site.yml"
check pass "ssh web1.example.com uptime; ansible-playbook -i $WSD/inventory $WSD/site.yml"
check deny 'ansible-playbook -i inventory site.yml'
check deny 'ansible-playbook --check --diff -l web1.example.com site.yml'
check deny 'cd ~/ansible && ansible-playbook site.yml --limit web1.example.com'
check deny "ssh root@server1.example.com 'ansible-playbook -c local /etc/site.yml'"
check deny "ansible-playbook -i $WSD/inventory /etc/ansible/site.yml --check"
check deny "ansible-playbook -i /etc/ansible/hosts $WSD/site.yml --check"
check deny "ansible-playbook -i $WSD/inventory ~/hostwarden/memory/infra/web/site.yml"
check deny "ansible-playbook -i $WSD/inventory $WSD/../../../../etc/site.yml"
check deny "ansible-playbook -i $WSD/inventory \$WS/infra/web/site.yml"
check deny "ansible-playbook -i web1.example.com, $WSD/site.yml"
check deny "ansible-playbook $WSD/site.yml"
check deny "ansible-playbook -i $WSD/inventory"
check pass "ansible-playbook -i $WSD/inventory $WSD/site"
check pass "ansible-playbook -i $WSD/inventory $WSD/site.yml -l web1.example.com -t nginx -u alice --vault-password-file /etc/ansible/vault.yml"
check pass "ansible-playbook -i $WSD/inventory --become-user root -f 5 -c ssh $WSD/site.yml"
# Every positional word is a playbook, whatever its name.
check deny "ansible-playbook -i $WSD/inventory $WSD/site.yml /etc/evil"
check deny "ansible-playbook -i $WSD/inventory $WSD/site.yml /tmp/x.txt --check"
check deny "ansible-playbook -i $WSD/inventory $WSD/site.yml --unknown-option /etc/x"
check deny "ansible-playbook -i $WSD/inventory $WSD/site.yml; ansible-playbook site.yml"
check pass 'ansible-playbook --syntax-check site.yml'
check pass 'ansible-playbook -i inventory --list-tasks site.yml'
check pass 'ansible-playbook -i inventory site.yml --list-hosts'
check pass "ansible-playbook -i $WSD/inventory --list-tags $WSD/site.yml"
check deny 'ansible-playbook --list-hosts site.yml; ansible-playbook site.yml'
check deny 'ansible-pull -U https://git.example.com/site.git'
check deny "ansible-pull -U https://git.example.com/site.git -d $WSD"
check deny 'ansible-console web'
# A secret in -e or --extra-vars goes into argv.
check deny "ansible-playbook -i $WSD/inventory -e db_password=hunter2 $WSD/site.yml"
check deny "ansible-playbook -i $WSD/inventory --extra-vars 'ansible_become_pass=hunter2' $WSD/site.yml"
check deny "ansible-playbook -i $WSD/inventory --extra-vars=\"api_token=abc def\" $WSD/site.yml"
check deny "ansible-playbook -i $WSD/inventory -e '{\"vault_secret\": \"x\"}' $WSD/site.yml"
check deny "ansible-playbook -i $WSD/inventory -e 'deploy_key=AAAA' $WSD/site.yml"
check deny 'ansible web1.example.com -m ping -e ansible_password=hunter2'
check deny 'ansible web1.example.com -m setup -e "ansible_ssh_pass=hunter2"'
check pass "ansible-playbook -i $WSD/inventory -e 'rotate_keys=yes' $WSD/site.yml"
check pass "ansible-playbook -i $WSD/inventory -e keyfile=/etc/x $WSD/site.yml"
check deny "ansible-playbook -i $WSD/inventory -e 'a=1 db_password=x' $WSD/site.yml"
# A quoted -e value with spaces is cut at them: the second word
# reads as a playbook outside the workspace. Known and accepted;
# one -e per variable passes.
check deny "ansible-playbook -i $WSD/inventory -e 'a=1 b=2' $WSD/site.yml"
check pass "ansible-playbook -i $WSD/inventory -e a=1 -e b=2 $WSD/site.yml"
# A -e outside an ansible invocation is another tool's.
check pass "grep -e 'token=' /var/log/ansible.log"
check pass 'rg -e "api_key=" docs/ansible.md'
check pass "sed -e 's/password=.*/password=<set>/' $WSD/README.md"

# --- ad-hoc calls: ping and setup read, the rest is a playbook ---
check pass 'ansible web1.example.com -m ping'
check pass 'ansible all -m setup -a filter=ansible_distribution*'
check pass 'ansible web1.example.com -m ansible.builtin.ping'
check pass "ansible -i $WSD/inventory web1.example.com -m setup"
check pass "ssh root@server1.example.com 'ansible localhost -c local -m ping'"
check deny 'ansible web1.example.com -a uptime'
check deny 'ansible web1.example.com -m command -a "cat /etc/ssh/sshd_config"'
check deny 'ansible web1.example.com -m shell -a "systemctl restart nginx"'
check deny 'ansible web1.example.com -m raw -a uptime'
check deny 'ansible web1.example.com -m stat -a path=/etc/ssh/sshd_config'
check deny 'ansible web1.example.com -b -m apt -a "name=nginx state=present"'
check deny 'ansible web1.example.com -m "$MOD" -a "name=nginx"'
check deny 'ansible web1.example.com -m ping -m apt -a name=nginx'
check pass 'ls -ld /etc/ansible/facts.d /root/.ansible 2>/dev/null || true'
# Without -m and -a nothing runs: the word is prose, a man page, a
# path or a lookup. --help and --version run nothing either.
check pass 'ansible --version'
check pass 'ansible --help'
check pass 'ansible-playbook --help'
check pass 'ansible-galaxy collection install --help'
check pass 'man ansible'
check pass 'command -v ansible'
check pass 'ls -l /etc/ansible'
check pass 'brew install ansible'
check pass 'ansible web1.example.com'
check pass 'logger -t hostwarden "applied the ansible playbook web"'
check pass "ssh web1.example.com 'logger -t hostwarden \"ansible playbook web applied\"'"
check deny 'ansible web1.example.com -a "systemctl restart nginx"'
check deny 'ansible web1.example.com -ba uptime'
check deny 'ansible web1.example.com --args uptime'
check pass 'command -v ansible-playbook'
check pass 'man ansible-playbook'
check pass 'ls -l /opt/homebrew/bin/ansible-playbook'
check pass 'which ansible-galaxy'
# A -h inside -a belongs to the command there, not to ansible.
check deny 'ansible all -b -m shell -a "free -h"'
check deny 'ansible all -b -m apt -a "name=htop" -e "x=-h"'
check deny 'ansible all -a "df -h"'
# A redirection is the shell's, not a playbook.
check pass "ansible-playbook -i $WSD/inventory --check --diff $WSD/site.yml 2>&1 | tail -n 100"
check pass "ansible-playbook -i $WSD/inventory $WSD/site.yml > /tmp/run.log"
check pass "ansible-playbook -i $WSD/inventory $WSD/site.yml 2>/dev/null </dev/null"
check deny "ansible-playbook -i $WSD/inventory $WSD/site.yml > /tmp/run.log /etc/evil"
check pass 'grep -rn "ansible[-]pull" /etc/cron.d/ 2>/dev/null || true'
# The modules that reach a taboo.
check deny 'ansible web1.example.com -b -m parted -a "device=/dev/sdb number=1 state=present"'
check deny 'ansible web1.example.com -m community.general.parted -a "device=/dev/sdb"'
check deny "ansible web1.example.com -m 'community.general.filesystem' -a 'fstype=ext4 dev=/dev/sdb1'"
check deny 'ansible web1.example.com --module-name=community.general.shutdown'
check deny 'ansible win1.example.com -m community.windows.win_format -a drive_letter=D'
check deny 'ansible web1.example.com -m ansible.posix.authorized_key -a "user=root state=absent key=x"'
check deny 'ansible web1.example.com -m community.crypto.openssh_keypair -a path=/tmp/k'
check deny 'ansible web1.example.com -m script -a ./fix.sh'
check deny 'ansible web1.example.com -m "$MOD" -a "dest=/etc/ssh/sshd_config src=x"'
# By path or in backticks, with the flags run together, and with an
# -m inside -a: every word that can name a module counts.
check deny '/usr/bin/ansible web1.example.com -m parted -a device=/dev/sdb'
check deny '/opt/homebrew/bin/ansible web1.example.com -m authorized_key -a user=root'
check deny 'echo `ansible web1.example.com -m parted -a device=/dev/sdb`'
check deny 'ansible web1.example.com -bm parted -a device=/dev/sdb'
check deny 'ansible web1.example.com --module-na parted -a device=/dev/sdb'
check deny 'ansible web1.example.com -m script -a "./setup.sh -m 700"'
check deny 'ansible web1.example.com -b -m parted -a "device=/dev/sdb" --ssh-extra-args "-m hmac-sha2-512"'
check deny 'ansible web1.example.com -m include_role -a name=disks'
check deny 'ansible web1.example.com -m ansible.builtin.include_tasks -a file=wipe.yml'
check deny 'ansible web1.example.com -b -m user -a "name=alice generate_ssh_key=yes force=yes"'
check deny 'ansible web1.example.com -m ansible.builtin.user -a "name=alice force=true generate_ssh_key=true"'
check deny "ansible web1.example.com -m user -a '{\"name\": \"alice\", \"generate_ssh_key\": true, \"force\": \"YES\"}'"
# Login options name a key without writing it, and the --*-args
# values go to ssh, never to a module.
check pass 'ansible web1.example.com -m ping --ssh-common-args "-F ~/.ssh/config"'
check pass 'ansible web1.example.com --ssh-extra-args="-i ~/.ssh/jump" -m setup'
check pass 'ansible web1.example.com --private-key ~/.ssh/deploy -m ping'
check pass 'ansible web1.example.com -e ansible_ssh_private_key_file=~/.ssh/hw -m ping'
check pass 'ansible web1.example.com -m ping; cat /etc/ssh/sshd_config'
check deny "ssh root@server1.example.com 'ansible localhost -c local -m parted -a device=/dev/sdb'"
check deny 'bash -c "ansible web1.example.com -m authorized_key -a user=root"'
check deny 'ansible web1.example.com -b -m lineinfile -a "path=/etc/ssh/sshd_config line=PermitRootLogin\ no"'
check deny 'ansible web1.example.com -mcopy -a "src=k dest=/root/.ssh/authorized_keys"'
check deny 'ansible web1.example.com -m shell -a "mkfs.ext4 /dev/sdb1"'
check deny 'ansible web1.example.com -b -a "poweroff"'

# --- the read-only tools, and collections ------------------------
check pass "ansible-inventory -i $WSD/inventory --list"
check pass "ansible-inventory -i $WSD/inventory --graph"
check pass 'ansible-doc ansible.builtin.lineinfile'
check pass 'ansible-doc -l'
check pass "ansible-lint $WSD/site.yml"
check pass "cd $WSD && ansible-lint"
check pass 'ansible-galaxy collection list'
check pass "ansible-galaxy collection list -p $WSD/collections"
check pass 'ansible-galaxy --version'
check pass "ansible-galaxy collection install -r $WSD/requirements.yml -p $WSD/collections"
check pass "ansible-galaxy collection install -p $WSD/collections -r $WSD/requirements.yml"
check pass "ansible-galaxy collection install --requirements-file=$WSD/requirements.yml --collections-path=$WSD/collections"
check pass "cd $WSD && ansible-galaxy collection install -r $WSD/requirements.yml -p$WSD/collections"
check pass "ansible-galaxy collection install -r $WSD/requirements.yml -p $WSD/collections 2>&1 | tail -n 20"
check deny 'ansible-galaxy collection install community.general'
check deny "ansible-galaxy collection install community.general -p $WSD/collections"
check deny "ansible-galaxy collection install -r $WSD/requirements.yml"
check deny "ansible-galaxy collection install -r $WSD/requirements.yml -p ~/.ansible/collections"
check deny "ansible-galaxy collection install -r $WSD/requirements.yml -p /usr/share/ansible/collections"
check deny "ansible-galaxy collection install -r requirements.yml -p ./collections"
check deny "ansible-galaxy collection install -r /etc/ansible/requirements.yml -p $WSD/collections"
check deny "ansible-galaxy collection install -r $WSD/requirements.yml -p $WSD/../db/collections"
check deny "ansible-galaxy collection install -r $WSD/requirements.yml -p ${WSD%/web}/db/collections"
check deny "ansible-galaxy collection install -r $WSD/requirements.yml -p $WSD/collections community.general"
check deny "ansible-galaxy role install -r $WSD/requirements.yml -p $WSD/roles"
check deny 'ansible-galaxy role install geerlingguy.nginx'
check deny 'ansible-galaxy install geerlingguy.nginx'

# --- terraform and tofu ------------------------------------------
check pass 'terraform output apply'
check pass 'tofu -chdir=infra output destroy'
check pass 'terraform state show aws_instance.apply'
check deny '/usr/local/bin/terraform apply'
check deny 'echo $(terraform apply -auto-approve)'
check deny '(tofu destroy)'
check deny 'terraform -chdir="my infra" apply'
check deny 'terraform apply'
check deny 'terraform -chdir=infra apply -auto-approve'
check deny 'tofu destroy -target=hcloud_server.web1'
check pass 'terraform plan'
check pass 'tofu state list'
