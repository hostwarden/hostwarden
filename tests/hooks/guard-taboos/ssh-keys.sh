# tests/hooks/guard-taboos/ssh-keys.sh — SSH keys destroyed, written
# into, or reached through their directory or an interpreter.
# Sourced by tests/hooks/guard-taboos.sh, in its order, into the one
# shell every part shares; never run on its own.
# shellcheck shell=sh

# --- SSH keys destroyed without rm/shred/unlink ----------------
check deny 'echo "" > /root/.ssh/authorized_keys'
check deny ': > /etc/ssh/ssh_host_ed25519_key'
check deny 'truncate -s 0 /root/.ssh/authorized_keys'
check deny 'mv /root/.ssh/authorized_keys /tmp/'
check deny 'chmod 000 /root/.ssh/authorized_keys'
check deny 'chown nobody /etc/ssh/ssh_host_rsa_key'
check deny 'ssh-keygen -q -N "" -f /etc/ssh/ssh_host_rsa_key'

# --- writes INTO a protected path (writes_to) ------------------
# A copy is judged by its destination: a key, ~/.ssh or a disk as
# the SOURCE is a read.
check deny 'echo x | tee /root/.ssh/authorized_keys'
check deny 'tee -a /home/alice/.ssh/authorized_keys < new.pub'
check deny 'cp /tmp/new /root/.ssh/authorized_keys'
check deny 'cp /tmp/new /root/.ssh/authorized_keys 2>/dev/null'
check deny 'cp /tmp/new /root/.ssh/authorized_keys 2>&1 | tee cp.log'
check deny 'cp -v /tmp/new "/root/.ssh/authorized_keys"'
check deny 'tee /tmp/copy /root/.ssh/authorized_keys < new.pub'
check deny 'rsync -e "ssh -i ~/.ssh/id_ed25519" keys h:/root/.ssh/authorized_keys'
check deny 'cp -f /tmp/id_ed25519 /root/.ssh/'
check deny 'cp -t /root/.ssh authorized_keys'
check deny 'rsync -a /backup/ssh/ /root/.ssh/'
check deny 'rsync --delete /tmp/empty/ /root/.ssh'
check deny 'scp keys root@h:/root/.ssh/authorized_keys'
check deny 'ssh root@h "cp /tmp/new /root/.ssh/authorized_keys && echo ok"'
check deny 'dd if=/dev/zero of=/etc/ssh/ssh_host_ed25519_key count=1'
check deny 'curl -fsS https://example.com/u.keys -o /root/.ssh/authorized_keys'
check deny 'wget -O ~/.ssh/authorized_keys https://example.com/u.keys'
check deny "sed -i '/old/d' /root/.ssh/authorized_keys"
check deny "sed -ni '1p' /root/.ssh/authorized_keys"
check deny 'vi /root/.ssh/authorized_keys'
check deny 'sort -u keys | sponge /root/.ssh/authorized_keys'
check deny 'setfacl -m u:bob:rw /root/.ssh/authorized_keys'
check deny 'find /home/alice/.ssh -name "id_*" -delete'
check deny '(cp /tmp/new /root/.ssh/authorized_keys)'
check deny 'echo $(cp /tmp/new /root/.ssh/authorized_keys)'
check deny 'cp /tmp/new /root/.ssh/authorized_keys # new key'
check deny 'cp -rt ~/.ssh keys'
check deny 'rsync --remove-source-files ~/.ssh/id_ed25519 /backup/'
check deny 'cp image.iso /dev/sdb'
check deny 'curl -fsS -o /dev/sdb https://example.com/img'
check deny 'tee /tmp/copy /dev/sdb < img'
check deny 'dd if=new.conf of=/etc/ssh/sshd_config'
check deny 'sort -u new.conf | sponge /etc/ssh/sshd_config'
check deny 'curl -o /etc/ssh/sshd_config.d/10-x.conf https://example.com/c'
check deny 'rsync new.conf h:/etc/ssh/sshd_config'
# Accepted false positive; see the list in the guard header.
check deny 'rsync -a site/ h:/var/www/ -e "ssh -i ~/.ssh/id_ed25519"'
check pass 'cp /root/.ssh/authorized_keys /root/backup/'
check pass 'cp /root/.ssh/id_ed25519 /root/.ssh/id_ed25519.bak'
check pass 'cp /tmp/new /tmp/x; cat /root/.ssh/authorized_keys'
check pass 'ssh -o BatchMode=yes root@h "cat /root/.ssh/authorized_keys"'
check pass 'cp /tmp/config /home/alice/.ssh/config'
check pass 'cp -a /root/.ssh /backup/root-ssh'
check pass 'scp -i ~/.ssh/id_ed25519 report.txt root@h:/tmp/'
check pass 'rsync -e "ssh -i ~/.ssh/id_ed25519" -a site/ h:/var/www/'
check pass 'ssh -o IdentityFile=~/.ssh/id_ed25519 root@h uptime'
check pass 'dd if=/root/.ssh/id_ed25519 of=/tmp/copy bs=1'
check pass 'ssh-keyscan h | tee -a ~/.ssh/known_hosts'
check pass 'curl -o /tmp/u.keys https://example.com/u.keys; wc -l /root/.ssh/authorized_keys'
check pass 'grep -i ed25519 /root/.ssh/authorized_keys | sed "s/ .*//"'
check pass 'ssh -i ~/.ssh/id_ed25519 root@h "sed -i s/a/b/ /etc/app.conf"'
check pass 'ssh -i ~/.ssh/id_ed25519 root@h "vim --version"'
check pass 'rsync -a --delete /root/.ssh/ /backup/root-ssh/'
check pass 'cp /dev/sda /root/disk.img'
check pass 'curl -o /tmp/sshd_config.new https://example.com/c'

# --- SSH keys reached through their directory (issue #7) -------
# The protected paths were key FILENAMES, so any operation on the
# enclosing .ssh directory reached every key in it without naming
# one. chmod 600 ~/.ssh/authorized_keys was denied while the
# recursive chown that does strictly more was not.
check deny 'chown -R alice:alice /home/alice/.ssh'
check deny 'chmod -R 700 /root/.ssh'
check deny 'chmod 000 /root/.ssh'
check deny 'rm -rf /home/alice/.ssh'
check deny 'mv /root/.ssh /root/.ssh.bak'
check deny 'install -d -m 700 -o alice -g alice /home/alice/.ssh'
check deny 'ssh -o BatchMode=yes root@h "chown -R alice:alice /home/alice/.ssh"'
# The exact shape that exposed this: the spelled-out chmod is
# denied, so the recursive form must not be the way around it.
check deny 'chown -R alice:alice /home/alice/.ssh && chmod 700 /home/alice/.ssh'
# Same reach through an interpreter, which names no key either.
check deny "python3 -c \"import shutil; shutil.rmtree('/root/.ssh')\""
check deny "node -e \"require('fs').chmodSync('/home/alice/.ssh', 0)\""

# --- same effect through an interpreter (issue #6) -------------
# The path rules recognized a write by the way it was spelled
# (redirect, tee, sed -i, an editor, rm/mv/chmod). An interpreter
# spells none of those and writes through plain file I/O.
check deny "python3 -c \"open('/etc/ssh/sshd_config','a').write('PermitRootLogin yes')\""
check deny "python3.11 -c \"open('/etc/ssh/sshd_config','w')\""
check deny "node -e \"require('fs').appendFileSync('/etc/ssh/sshd_config','X')\""
check deny "perl -e 'open(F,\">\",\"/etc/ssh/sshd_config\")'"
check deny "ruby -e \"File.write('/etc/ssh/sshd_config','')\""
check deny "awk 'BEGIN{printf \"\" > f}' f=/etc/ssh/sshd_config"
check deny "python3 -c \"import os; os.remove('/root/.ssh/authorized_keys')\""
check deny "node -e \"require('fs').unlinkSync('/root/.ssh/authorized_keys')\""
check deny "python3 -c \"open('/etc/ssh/ssh_host_ed25519_key','w').write('')\""
check deny "ruby -e \"File.unlink('/root/.ssh/id_ed25519')\""
check deny "ssh -o BatchMode=yes root@h \"python3 -c \\\"open('/etc/ssh/sshd_config','a')\\\"\""
# Raw devices are the same hole with worse consequences, and the
# original report did not cover them.
check deny "python3 -c \"open('/dev/sda','wb').write(b'0'*4096)\""
check deny "perl -e 'open(D,\">\",\"/dev/nvme0n1\"); print D chr(0)'"
check deny "node -e \"require('fs').writeFileSync('/dev/vda','')\""

# --- SSH connection sharing (rules/ssh-connections.md) ---------
# Hostwarden's control socket must not read as key material, or
# every remote rm/mv/chmod sent with the standard options is
# denied (see the accepted false positives in the guard).
check pass 'ssh -o ControlMaster=auto -o ControlPath=~/.cache/hostwarden/ssh-%C root@h "rm -f /var/tmp/old.log; chmod 644 /etc/motd"'
