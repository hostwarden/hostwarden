# tests/hooks/guard-taboos/pass-ssh.sh — read-only forms around
# keys, certificates and sshd. Sourced by
# tests/hooks/guard-taboos.sh, in its order, into the one shell
# every part shares; never run on its own.
# shellcheck shell=sh

# --- the system-account probe fails closed ---------------------
# Printing only shells that end in sh passes the guard and misses
# every shell it does not know. The probe is read from the skill,
# and stripping its path makes awk read the fixture from stdin; a
# missing probe or one that stops ending in /etc/passwd fails.
PROBE=$(awk '/^## System Accounts with Login Shells/ { s = 1 }
  s && b && /^```$/ { exit }
  b { print }
  s && /^```bash$/ { b = 1 }' \
  "$SKILLS_DIR/hostwarden-security/references/user-accounts.md")
WANT="bash empty ksh postgres py root "
GOT=$(printf '%s\n' \
  'root:x:0:0:root:/root:/bin/bash' \
  'daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin' \
  'sync:x:4:65534:sync:/bin:/bin/sync' \
  'games:x:5:60:games:/usr/games:/bin/false' \
  'shutdown:x:6:0:shutdown:/sbin:/sbin/shutdown' \
  'halt:x:7:0:halt:/sbin:/sbin/halt' \
  'postgres:x:110:118::/var/lib/postgresql:/bin/bash' \
  'bash:x:990:990::/tmp:/bin/bash' \
  'ksh:x:991:991::/tmp:/bin/ksh93' \
  'py:x:992:992::/tmp:/usr/bin/python3' \
  'empty:x:993:993::/tmp:' \
  'alice:x:1000:1000::/home/alice:/usr/bin/zsh' \
  | sh -c "${PROBE%/etc/passwd}" | cut -d: -f1 | LC_ALL=C sort \
  | tr '\n' ' ')
if [ "$GOT" = "$WANT" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: system-account probe reported [$GOT], want [$WANT]"
fi

# --- read-only forms of the newly covered tools (issue #5) -----
check pass 'diskutil info disk0'
check pass 'diskutil apfs list'
check pass 'gpt show /dev/da0'
check pass 'parted /dev/sda print'
check pass 'parted /dev/sda unit MiB print'
check pass 'parted -m -l'
check pass 'sgdisk -p /dev/sda'
check pass 'sgdisk -i 1 /dev/sda'
check pass 'sgdisk -v /dev/sda'
check pass 'nvme list'
check pass 'nvme id-ctrl /dev/nvme0'
check pass 'nvme smart-log /dev/nvme0'
check pass 'badblocks -sv /dev/sda'
check pass 'hdparm -I /dev/sda'
check pass 'blockdev --getsize64 /dev/sda'
check pass 'shred -u /tmp/leftover.txt'
check pass 'wc -l /root/.ssh/authorized_keys'
check pass 'cp /etc/ssh/ssh_host_rsa_key.pub /tmp/'
check pass 'echo done > /dev/null'
check pass 'ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub'
check pass 'growpart --dry-run /dev/sda 1'

# --- key probes deny each other when chained (rules/secrets.md) -
# Accepted false positive; see the list in the guard header.
check pass 'file /etc/ssh/ssh_host_ed25519_key'
check deny 'file /etc/ssh/ssh_host_ed25519_key; ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub'

# --- SSH certificates are public (rules/ssh-ca.md) -------------
# A certificate beside its key ends in -cert.pub and is read
# with ssh-keygen -L; any other hyphen suffix is still a private
# key.
check pass 'ssh-keygen -L -f /etc/ssh/ssh_host_ed25519_key-cert.pub'
check pass 'ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key-cert.pub'
check pass 'ssh root@web1.example.com "ssh-keygen -L -f /usr/local/etc/ssh/ssh_host_ed25519_key-cert.pub"'
check pass 'ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub'
check pass 'cat /etc/ssh/ssh_host_rsa_key-cert.pub'
check deny 'ssh-keygen -q -N "" -f /etc/ssh/ssh_host_ed25519_key-cert'
check deny 'ssh-keygen -q -N "" -f /etc/ssh/ssh_host_ed25519_key-certs.pub'
check deny 'ssh-keygen -q -N "" -f /etc/ssh/ssh_host_rsa_key-old'
check deny 'ssh-keygen -q -N "" -f ~/.ssh/id_ed25519-work'
check deny 'ssh-keygen -q -N "" -f ~/.ssh/id_ed25519-c'
check deny ': > /etc/ssh/ssh_host_ed25519_key-cert'

# --- sshd's revocation list (RevokedKeys) -----------------------
# Missing or unreadable, it makes sshd refuse every public key
# login. Reading and writing it stay allowed.
check deny 'rm /etc/ssh/revoked_keys'
check deny 'rm -f /usr/local/etc/ssh/revoked_keys.krl'
check deny 'mv /etc/ssh/revoked_keys /tmp/'
check deny 'mv /tmp/krl.new /etc/ssh/user_ca.krl'
check deny 'chmod 000 /etc/ssh/revoked_keys'
check deny 'chown nobody /etc/ssh/ca/revoked'
check deny 'ln -sf /dev/null /etc/ssh/revoked_keys'
check deny 'find /etc/ssh/revoked_keys -delete'
check deny 'ssh root@web1.example.com "rm /etc/ssh/Revoked_Keys"'
check deny "python3 -c \"import os; os.remove('/etc/ssh/revoked_keys')\""
check pass 'ssh-keygen -Q -l -f /etc/ssh/revoked_keys'
check pass 'ls -l /etc/ssh/revoked_keys'
check pass 'sha256sum /etc/ssh/revoked_keys'
check pass 'ssh-keygen -k -u -f /etc/ssh/revoked_keys /tmp/leaked-cert.pub'
check pass 'cp /tmp/revoked_keys /etc/ssh/revoked_keys'
check pass 'rm /tmp/revoked_keys'
check pass 'rm /srv/backup/etc-ssh/revoked_keys'

# --- interpreters away from a protected target (issue #6) ------
# Only the combination is a taboo. An interpreter on its own,
# even writing files, is ordinary work and must stay usable.
check pass 'python3 --version'
check pass 'python3 -c "import json,sys; print(json.load(sys.stdin))"'
check pass "python3 -c \"open('/tmp/report.txt','w').write('x')\""
check pass 'node -e "console.log(process.version)"'
check pass 'python3 -m json.tool /etc/myapp/config.json'
check pass 'awk "/^worker_processes/ {print \$2}" /etc/nginx/nginx.conf'
check pass 'perl -pe "s/foo/bar/" /tmp/notes.txt'
check pass 'mix deps.get'
check pass 'ls -l /root/.ssh/'
check pass 'stat -c %a /root/.ssh/authorized_keys'

# --- .ssh as a directory: inspection stays allowed (issue #7) --
# Widening KEY to the directory must not cost the read-only
# probes the rule files themselves prescribe.
check pass 'ls -la /home/alice/.ssh'
check pass 'stat -c "%A %U:%G %n" /home/alice/.ssh'
check pass 'find /home/alice/.ssh -maxdepth 1 -type f'
check pass 'test -w /home/alice/.ssh'
check pass 'getfacl /home/alice/.ssh'
# .ssh must match as a path component, not as a prefix, and a
# destructive command away from it stays ordinary work.
check pass 'chmod 700 /home/alice/.sshrc'
check pass 'chown -R alice:alice /home/alice/Documents'
check pass 'rm -rf /home/alice/.cache'
