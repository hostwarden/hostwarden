# tests/hooks/guard-taboos/sshd.sh — sshd's configuration wherever it lives.
# Sourced by tests/hooks/guard-taboos.sh, in its order, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh

# --- sshd outside /etc/ssh: ports, packages, appliances --------
# The OpenSSH port keeps config and host keys in
# /usr/local/etc/ssh (FreeBSD, OPNsense); OPNsense keeps its host
# keys in a key store of their own, /conf/sshd.
check deny "sed -i 's/^/#/' /usr/local/etc/ssh/sshd_config"
check deny 'echo PermitRootLogin yes >> /usr/local/etc/ssh/sshd_config'
check deny 'tee /usr/local/etc/ssh/sshd_config < new.conf'
check deny 'vi /usr/local/etc/ssh/sshd_config'
check deny 'cp new.conf /usr/local/etc/ssh/sshd_config'
check deny 'curl -o /usr/local/etc/ssh/sshd_config.d/10-x.conf https://example.com/c'
check deny 'echo PasswordAuthentication yes > /usr/local/etc/ssh/sshd_config.d/10-x.conf'
check deny 'rm /usr/local/etc/ssh/sshd_config.d/10-x.conf'
check deny "python3 -c \"open('/usr/local/etc/ssh/sshd_config','a')\""
check deny 'ssh root@fw "echo X >> /usr/local/etc/ssh/sshd_config"'
check deny 'rm /usr/local/etc/ssh/ssh_host_ed25519_key'
check deny ': > /usr/local/etc/ssh/ssh_host_ed25519_key'
check deny 'ssh-keygen -q -N "" -f /usr/local/etc/ssh/ssh_host_rsa_key'
check deny 'rm /conf/sshd/ssh_host_ed25519_key'
check deny 'mv /conf/sshd/ssh_host_rsa_key /tmp/'
check deny 'chmod 644 /conf/sshd/ssh_host_ecdsa_key'
check deny ': > /conf/sshd/ssh_host_ed25519_key'
check deny 'cp /tmp/k /conf/sshd/ssh_host_ed25519_key'
check deny 'dd if=/dev/zero of=/conf/sshd/ssh_host_rsa_key count=1'
check deny 'ssh-keygen -q -N "" -f /conf/sshd/ssh_host_rsa_key'
check deny "sed -i d /conf/sshd/ssh_host_ed25519_key"
check deny "python3 -c \"open('/conf/sshd/ssh_host_ed25519_key','w')\""
check deny 'ssh root@fw "rm -f /conf/sshd/ssh_host_*"'
# /conf/sshd holds nothing but keys: the directory is the target.
check deny 'rm -f /conf/sshd/*'
check deny 'rm -rf /conf/sshd'
check deny 'mv /conf/sshd /tmp/x'
check deny 'chmod -R 000 /conf/sshd'
check deny 'chown -R nobody /conf/sshd/'
check deny 'cp /tmp/k /conf/sshd/'
check deny 'rsync -a /backup/sshd/ /conf/sshd/'
# QNAP starts sshd on /etc/config/ssh/sshd_config, beside its user
# file and authorized_keys: the directory is a key store. ZimaOS's
# writable /etc is /mnt/overlay/etc, which the open left side of
# the /etc/ssh patterns already covers.
check deny "sed -i 's/^#Port/Port/' /etc/config/ssh/sshd_config"
check deny 'echo AllowUsers alice >> /etc/config/ssh/sshd_user_config'
check deny 'vi /etc/config/ssh/sshd_config'
check deny 'rm /etc/config/ssh/ssh_host_rsa_key'
check deny 'ssh-keygen -q -N "" -f /etc/config/ssh/ssh_host_ed25519_key'
check deny 'rm -rf /etc/config/ssh'
check deny 'chmod -R 777 /etc/config/ssh'
check deny 'ssh admin@nas1.example.com "rm /etc/config/ssh/authorized_keys"'
check deny "sed -i 's/^#Port/Port/' /mnt/overlay/etc/ssh/sshd_config"
check deny 'rm /mnt/overlay/etc/ssh/ssh_host_ed25519_key'
check pass 'ls -l /etc/config/ssh/'
check pass 'cat /etc/config/ssh/sshd_config'
# Prefixes are matched, not listed: Homebrew's etc/ssh too.
check deny 'echo X >> /opt/homebrew/etc/ssh/sshd_config'
check deny 'rm /opt/homebrew/etc/ssh/ssh_host_ed25519_key'
check deny 'echo X >> "/usr/local/etc/ssh/sshd_config"'
# pfSense keeps keys and config in /etc/ssh, but appends
# /etc/sshd_extra to the sshd_config it generates.
check deny 'echo PermitRootLogin yes >> /etc/sshd_extra'
check deny 'tee /etc/sshd_extra < extra.conf'
check deny "sed -i d /etc/sshd_extra"
check deny 'vi /etc/sshd_extra'
check deny 'rm /etc/sshd_extra'
check deny 'cp extra.conf /etc/sshd_extra'
check deny "python3 -c \"open('/etc/sshd_extra','a')\""
check pass 'cat /etc/sshd_extra'
check pass 'ls -l /etc/sshd_extra'
# OpenWrt runs dropbear: its config is the UCI file
# /etc/config/dropbear, changed through uci, and /etc/dropbear
# holds its host keys and root's authorized_keys, nothing else.
check deny "uci set dropbear.@dropbear[0].Port=2222"
check deny "uci set 'dropbear.@dropbear[0].PasswordAuth=on'"
check deny 'uci -q delete dropbear.@dropbear[0].Interface'
check deny 'uci add_list dropbear.@dropbear[0].keyfile=/tmp/k'
check deny 'uci add dropbear dropbear'
check deny 'uci commit dropbear'
check deny 'uci import dropbear < /tmp/dropbear.uci'
# Without a name, import commits every package its input declares.
check deny 'uci import < /tmp/backup.uci'
check deny 'uci import</tmp/backup.uci'
check deny 'uci -q import'
check deny 'cat /tmp/backup.uci | uci import'
check deny 'uci import # restore'
check deny "ssh root@router.example.com 'uci import < /tmp/backup.uci'"
check pass 'uci import firewall < /tmp/firewall.uci'
check pass 'uci -m import network < /tmp/network.uci'
# Configuration tools. A playbook's tasks are out of sight, so only
# the forms that run none pass; ad-hoc calls are judged by module.
check deny 'ansible-playbook -i inventory site.yml'
check deny 'ansible-playbook --check --diff -l web1.example.com site.yml'
check deny 'cd ~/ansible && ansible-playbook site.yml --limit web1.example.com'
check deny "ssh root@server1.example.com 'ansible-playbook -c local /etc/site.yml'"
check pass 'ansible-playbook --syntax-check site.yml'
check pass 'ansible-playbook -i inventory --list-tasks site.yml'
check pass 'ansible-playbook -i inventory site.yml --list-hosts'
check deny 'ansible-playbook --list-hosts site.yml; ansible-playbook site.yml'
check deny 'ansible-pull -U https://git.example.com/site.git'
check deny 'ansible-console web'
check pass 'ansible web1.example.com -m ping'
check pass 'ansible all -m setup -a filter=ansible_distribution*'
check pass 'ansible web1.example.com -a uptime'
check pass 'ansible web1.example.com -m command -a "cat /etc/ssh/sshd_config"'
check pass 'ansible web1.example.com -m stat -a path=/etc/ssh/sshd_config'
check pass 'ansible web1.example.com -b -m apt -a "name=nginx state=present"'
check pass 'ls -ld /etc/ansible/facts.d /root/.ansible 2>/dev/null || true'
check deny 'ansible web1.example.com -b -m parted -a "device=/dev/sdb number=1 state=present"'
check deny 'ansible web1.example.com -m community.general.parted -a "device=/dev/sdb"'
check deny "ansible web1.example.com -m 'community.general.filesystem' -a 'fstype=ext4 dev=/dev/sdb1'"
check deny 'ansible web1.example.com --module-name=community.general.shutdown'
check deny 'ansible win1.example.com -m community.windows.win_format -a drive_letter=D'
check deny 'ansible web1.example.com -m ansible.posix.authorized_key -a "user=root state=absent key=x"'
check deny 'ansible web1.example.com -m community.crypto.openssh_keypair -a path=/tmp/k'
check deny 'ansible web1.example.com -m script -a ./fix.sh'
check deny 'ansible web1.example.com -m "$MOD" -a "dest=/etc/ssh/sshd_config src=x"'
check pass 'ansible web1.example.com -m "$MOD" -a "name=nginx"'
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
check deny 'ansible web1.example.com -b -m user -a "name=alice generate_ssh_key=yes force=TRUE"'
check deny "ansible web1.example.com -m user -a '{\"name\": \"alice\", \"generate_ssh_key\": true, \"force\": \"YES\"}'"
check deny 'ansible web1.example.com -m user -a "name=alice generate_ssh_key=1 force=y"'
check pass 'ansible web1.example.com -b -m user -a "name=alice generate_ssh_key=yes force=no"'
check pass 'terraform output apply'
check pass 'tofu -chdir=infra output destroy'
check pass 'terraform state show aws_instance.apply'
check pass 'ansible web1.example.com -b -m user -a "name=alice generate_ssh_key=yes"'
check pass 'ansible web1.example.com -b -m user -a "name=alice state=present force=yes"'
# Login options name a key without writing it, and the --*-args
# values go to ssh, never to a module.
check pass 'ansible web1.example.com -m apt -a "name=nginx" --ssh-common-args "-F ~/.ssh/config"'
check pass 'ansible web1.example.com --ssh-extra-args="-i ~/.ssh/jump" -m apt -a name=nginx'
check deny 'ansible web1.example.com --ssh-common-args "-F x" -m copy -a "src=k dest=/root/.ssh/authorized_keys"'
check pass 'ansible web1.example.com --private-key ~/.ssh/deploy -b -m apt -a "name=nginx state=present"'
check pass 'ansible web1.example.com -e ansible_ssh_private_key_file=~/.ssh/hw -m service -a "name=nginx state=reloaded"'
check pass 'ansible web1.example.com -m apt -a name=nginx; cat /etc/ssh/sshd_config'
check deny '/usr/local/bin/terraform apply'
check deny 'echo $(terraform apply -auto-approve)'
check deny '(tofu destroy)'
check deny 'terraform -chdir="my infra" apply'
check deny "ssh root@server1.example.com 'ansible localhost -c local -m parted -a device=/dev/sdb'"
check deny 'bash -c "ansible web1.example.com -m authorized_key -a user=root"'
check pass "ssh root@server1.example.com 'ansible localhost -c local -m ping'"
check deny 'ansible web1.example.com -b -m lineinfile -a "path=/etc/ssh/sshd_config line=PermitRootLogin\ no"'
check deny 'ansible web1.example.com -mcopy -a "src=k dest=/root/.ssh/authorized_keys"'
check deny 'ansible web1.example.com -m ansible.builtin.file -a "path=/root/.ssh mode=0777"'
check deny 'ansible web1.example.com -m shell -a "sed -i s/22/2222/ /etc/ssh/sshd_config"'
check deny 'ansible web1.example.com -m shell -a "mkfs.ext4 /dev/sdb1"'
check deny 'ansible web1.example.com -b -a "poweroff"'
check deny 'terraform apply'
check deny 'terraform -chdir=infra apply -auto-approve'
check deny 'tofu destroy -target=hcloud_server.web1'
check pass 'terraform plan'
check pass 'tofu state list'
check pass 'grep -rn "ansible[-]pull" /etc/cron.d/ 2>/dev/null || true'
check deny "ssh root@router.example.com 'uci set dropbear.@dropbear[0].RootLogin=1; uci commit dropbear'"
check deny "uci batch <<'EOF'
set dropbear.@dropbear[0].Port=2222
commit dropbear
EOF"
check deny 'echo "option Port 2222" >> /etc/config/dropbear'
check deny "sed -i 's/22/2222/' /etc/config/dropbear"
check deny 'vi /etc/config/dropbear'
check deny 'cp /tmp/dropbear /etc/config/dropbear'
check deny 'rm /etc/config/dropbear'
check deny "python3 -c \"open('/etc/config/dropbear','a')\""
check deny 'rm /etc/dropbear/dropbear_ed25519_host_key'
check deny ': > /etc/dropbear/dropbear_rsa_host_key'
check deny 'mv /etc/dropbear/dropbear_ecdsa_host_key /tmp/'
check deny 'rm -rf /etc/dropbear'
check deny 'chmod -R 644 /etc/dropbear'
check deny 'cp /tmp/k /etc/dropbear/'
# dropbear elsewhere: OpenRC's conf.d, Debian's defaults file.
check deny "sed -i 's/-w//' /etc/conf.d/dropbear"
check deny 'echo DROPBEAR_PORT=2222 >> /etc/default/dropbear'
check pass 'cat /etc/conf.d/dropbear /etc/default/dropbear'
# A bare commit writes every staged config, dropbear's included.
check deny 'uci commit'
check deny 'uci -q commit'
check deny 'uci changes; uci commit'
check deny 'uci commit >/dev/null'
check deny 'uci -q commit 2>/dev/null'
check deny 'uci commit 2>&1'
check deny 'uci commit # all of them'
check pass 'uci commit firewall >/dev/null'
check deny "ssh root@router.example.com 'uci set firewall.@defaults[0].syn_flood=1; uci commit'"
check deny "uci batch <<'EOF'
set firewall.@defaults[0].syn_flood=1
commit
EOF"
check pass 'uci set firewall.@defaults[0].syn_flood=1; uci commit firewall'
check pass 'git commit -m "docs: uci notes"'
check pass 'uci show dropbear'
check pass 'uci get dropbear.@dropbear[0].Port'
check pass 'uci changes dropbear'
check pass 'uci export dropbear'
check pass 'cat /etc/config/dropbear'
check pass 'ls -l /etc/dropbear'
check pass 'dropbearkey -y -f /etc/dropbear/dropbear_ed25519_host_key'
check pass 'uci set firewall.@defaults[0].syn_flood=1'
check pass 'uci commit firewall'
# OpenMediaVault renders sshd_config and rebuilds its
# authorized_keys directory from the ssh Salt state; deploying that
# state names neither path.
check deny 'omv-salt deploy run ssh'
check deny 'omv-salt deploy run nginx ssh samba'
check deny 'omv-salt deploy run -q ssh'
check deny "omv-salt deploy run 'ssh'"
check deny 'omv-salt deploy run ssh;true'
check deny 'ssh root@nas "omv-salt deploy run ssh"'
check deny 'omv-salt stage run deploy'
check deny 'omv-salt stage run --quiet deploy'
check pass 'omv-salt deploy run samba'
check pass 'omv-salt deploy run ssh-notes'
check pass 'omv-salt deploy list-dirty'
check pass 'omv-salt stage run prepare'
# segments() splits at quotes, so a quoted word must not hide it.
check deny '"/usr/sbin/omv-salt" deploy run ssh'
check deny "'omv-salt' stage run deploy"
check deny "omv-salt 'deploy' 'run' ssh"
check deny 'ssh root@nas "\"/usr/sbin/omv-salt\" deploy run ssh"'
check pass '"/usr/sbin/omv-salt" deploy run samba'
check pass "'omv-salt' stage run prepare"
check pass 'omv-salt deploy run samba; ssh root@nas uptime'
check pass 'cat /usr/local/etc/ssh/sshd_config'
check pass 'grep -r PermitRootLogin /usr/local/etc/ssh/sshd_config.d/'
check pass 'stat /usr/local/etc/ssh/sshd_config'
check pass 'ls -l /usr/local/etc/ssh/'
check pass 'ssh root@fw "sshd -T -f /usr/local/etc/ssh/sshd_config"'
check pass 'cat /usr/local/etc/ssh/ssh_host_ed25519_key.pub'
check pass 'ls -l /conf/sshd/'
check pass 'stat /conf/sshd/ssh_host_ed25519_key'
check pass 'cp /conf/sshd/ssh_host_ed25519_key.pub /tmp/'
check pass 'ssh-keygen -lf /conf/sshd/ssh_host_ed25519_key.pub'
# The rest of /conf is OPNsense's config store, not a key store.
check pass 'cp /conf/config.xml /root/config.xml.bak'
check pass 'rm /conf/backup/config-1700000000.xml'

# --- a redirect glued to the protected path --------------------
# END includes < and >: these replaced the file while the spaced
# forms were denied.
check deny 'tee /etc/ssh/sshd_config<<EOF'
check deny 'echo X | tee -a /etc/ssh/sshd_config>/dev/null'
check deny 'tee -a /etc/ssh/sshd_config</tmp/new'
check deny 'tee /etc/ssh/sshd_config.d/x.conf>/dev/null'
check deny 'ssh root@h "tee /etc/ssh/sshd_config.d/99.conf</tmp/x"'
check deny 'tee ~/.ssh/authorized_keys</tmp/k'
check deny 'echo k | tee -a ~/.ssh/authorized_keys>/dev/null'
check deny 'tee /etc/ssh/ssh_host_ed25519_key</tmp/k'
check pass 'tee /tmp/report.txt</tmp/in'

# --- CLOBBER: one list of destructive tools for keys and sshd --
check deny 'install -m 600 /tmp/new /etc/ssh/sshd_config'
check deny 'install -m 600 /tmp/new /usr/local/etc/ssh/sshd_config'
check deny 'ln -sf /tmp/x /etc/ssh/sshd_config'
check deny 'patch /etc/ssh/sshd_config < /tmp/d'
check deny 'shred -u /etc/ssh/sshd_config'
check deny 'patch ~/.ssh/authorized_keys < /tmp/d'
check pass 'ls -ln /etc/ssh/sshd_config'
