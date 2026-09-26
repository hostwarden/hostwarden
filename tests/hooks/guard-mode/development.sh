# tests/hooks/guard-mode/development.sh — the mode guard in
# development: what goes past a PATH lookup. Sourced by
# tests/hooks/guard-mode.sh, in the order its PARTS lists, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# Development: the guard denies what goes past a PATH lookup. A
# bare tool name is the shim's (shim.sh), wherever it stands.
cmd deny "$DEV" '/usr/bin/ssh server1.example.com'
cmd deny "$DEV" 'cd /tmp && /usr/bin/scp a.txt server1.example.com:/tmp/'
cmd deny "$DEV" '! /usr/local/bin/mosh server1.example.com'
# The configuration tools open their own connections: ansible and
# its kin reach every host of an inventory, terraform and tofu a
# cloud. A path past the shim is denied like ssh's; reading their
# code, or a directory named after one, is not.
cmd deny "$DEV" '/opt/homebrew/bin/ansible all -m ping'
cmd deny "$DEV" '/home/alice/.local/bin/ansible-playbook -i inventory site.yml'
cmd deny "$DEV" '/usr/bin/ansible-pull -U https://git.example.com/site.git'
cmd deny "$DEV" '/usr/local/bin/terraform plan'
cmd deny "$DEV" 'FOO=1 /usr/bin/tofu apply'
cmd pass "$DEV" 'grep -rn become roles/ansible/tasks/'
cmd pass "$DEV" 'cat ~/infra/terraform/main.tf'
cmd pass "$DEV" 'ansible-lint site.yml'
cmd pass "$DEV" 'ansible-vault view --help'
cmd deny "$DEV" 'FOO=1 /usr/bin/sudo whoami'
cmd deny "$DEV" 'echo $(/usr/bin/ssh server1.example.com hostname)'
cmd deny "$DEV" 'bash -c "true; /usr/bin/sudo whoami"'
cmd deny "$DEV" 'command -p ssh server1.example.com'
cmd deny "$DEV" 'command -p sudo whoami'
cmd deny "$DEV" 'command  -p ssh server1.example.com'
cmd deny "$DEV" "sh -c 'command -p ssh server1.example.com'"
cmd deny "$DEV" 'eval "command -p sudo whoami"'
cmd pass "$DEV" 'command -v ssh-keygen; grep -p x file'
cmd deny "$DEV" 'exec /usr/bin/ssh server1.example.com'
cmd deny "$DEV" 'PATH=/usr/bin:/bin ssh server1.example.com'
cmd deny "$DEV" 'export PATH=/usr/bin:/bin; ssh server1.example.com'
cmd deny "$DEV" 'env -i ssh server1.example.com'
cmd deny "$DEV" 'env PATH=/usr/bin sudo whoami'
cmd deny "$DEV" 'unset PATH; ssh server1.example.com'
cmd deny "$DEV" "PATH=/usr/bin sh -c 'ssh server1.example.com'"
cmd deny "$DEV" 'path=(/usr/bin /bin); ssh server1.example.com'
cmd deny "$DEV" 'true
PATH=/usr/bin ssh server1.example.com'
cmd deny "$DEV" 'true
	path=(/usr/bin); ssh server1.example.com'
cmd deny "$DEV" 'env -u PATH sudo whoami'
cmd deny "$DEV" 'env --unset=PATH ssh server1.example.com'
cmd deny "$DEV" 'env -uPATH ssh server1.example.com'
cmd deny "$DEV" 'env --unset PATH ssh server1.example.com'
cmd deny "$DEV" 'env - ssh server1.example.com'
cmd deny "$DEV" 'env -iv sudo whoami'
cmd pass "$DEV" 'env -u LANG sort file.txt'
cmd deny "$DEV" 'env -u LANG -i ssh server1.example.com'
cmd deny "$DEV" 'env FOO=1 --unset PATH ssh server1.example.com'
cmd pass "$DEV" 'env LANG=C grep -i ssh rules/ssh-user.md'
# rsync talks to a daemon itself; no ssh, so no shim, on the way.
cmd deny "$DEV" 'rsync -a rsync://server1.example.com/mod/ here/'
cmd deny "$DEV" "rsync -a 'rsync://server1.example.com/mod/' here/"
cmd deny "$DEV" 'rsync -av server1.example.com::mod here/'
cmd deny "$DEV" 'rsync -av here/ "server1.example.com::mod/x"'
cmd pass "$DEV" 'rsync -a src/ /tmp/copy/'
cmd pass "$DEV" 'grep -rn "std::string" src/ | rsync -a src/ /tmp/copy/'
cmd pass "$DEV" 'rsync -a src/ /tmp/copy/ && grep -rn "std::string" src/'
# A path elsewhere in the command counts once it is a program.
mkdir -p "$TMP/bin"
printf '#!/bin/sh\n' > "$TMP/bin/ssh"
chmod +x "$TMP/bin/ssh"
cmd deny "$DEV" "rsync -a -e $TMP/bin/ssh src/ server1.example.com:/srv/"
cmd deny "$DEV" "rsync -a -e '$TMP/bin/ssh -p 2222' src/ server1.example.com:/srv/"
cmd deny "$DEV" "git -c core.sshCommand=$TMP/bin/ssh push"
cmd pass "$DEV" "grep -rn Port $TMP/bin/ssh.d/"
cmd pass "$DEV" 'ls /etc/ssh'
# Every path in the command is looked at, not only the first.
cmd deny "$DEV" "ls /etc/ssh && rsync -a -e $TMP/bin/ssh src/ server1.example.com:/srv/"
cmd deny "$DEV" '$GIT_SSH_COMMAND root@server1.example.com uptime'
cmd deny "$DEV" '"${GIT_SSH_COMMAND}" server1.example.com'
cmd deny "$DEV" 'env "$GIT_SSH_COMMAND" server1.example.com'
cmd deny "$DEV" 'timeout 5 $GIT_SSH_COMMAND server1.example.com'
cmd deny "$DEV" 'ssh-keygen -lf k.pub; /usr/bin/doas true'
# WSL: Windows programs by their path, and in a spelling the shim
# misses, since the drives under /mnt ignore case.
cmd deny "$DEV" '/mnt/c/Windows/System32/OpenSSH/ssh.exe server1.example.com'
cmd deny "$DEV" '/mnt/c/Windows/System32/wsl.exe -u root -e id'
cmd deny "$DEV" '/mnt/c/Program\ Files/PowerShell/7/pwsh.exe -c Get-Disk'
cmd deny "$DEV" 'SSH.EXE server1.example.com'
cmd deny "$DEV" 'Wsl.exe -u root -e id'
cmd deny "$DEV" 'true; PowerShell.exe -Command Get-Service'
cmd deny "$DEV" 'CMD.EXE /c ver'
cmd deny "$DEV" '"SSH.EXE" server1.example.com'
cmd deny "$DEV" '"WSL.EXE" -u root -e id'
# A redirection attached to the name, or standing before it, is
# not part of it, and a launcher runs what follows it.
cmd deny "$DEV" 'SSH.EXE>out server1.example.com'
cmd deny "$DEV" 'WSL.EXE>/tmp/x -u root -e id'
cmd deny "$DEV" '"SSH.EXE">out server1.example.com'
cmd deny "$DEV" '2>/dev/null SSH.EXE server1.example.com'
cmd deny "$DEV" '2> /dev/null WSL.EXE -u root -e id'
cmd deny "$DEV" 'env SSH.EXE server1.example.com'
cmd deny "$DEV" 'env LC_ALL=C WSL.EXE -u root -e id'
cmd deny "$DEV" '/usr/bin/env -u LANG SSH.EXE server1.example.com'
cmd deny "$DEV" 'timeout -s KILL 5 WSL.EXE -u root -e id'
cmd deny "$DEV" 'nohup nice -n 5 SSH.EXE server1.example.com'
cmd pass "$DEV" 'env LANG=C grep -i SSH.EXE rules/'
cmd pass "$DEV" 'clip.exe >out'
cmd deny "$DEV" 'command -p wsl.exe -u root'
cmd deny "$DEV" 'PATH=/mnt/c/Windows/System32 wsl.exe -u root'
printf '#!/bin/sh\n' > "$TMP/bin/ssh.exe"
chmod +x "$TMP/bin/ssh.exe"
cmd deny "$DEV" "rsync -a -e $TMP/bin/ssh.exe src/ server1.example.com:/srv/"
cmd pass "$DEV" 'explorer.exe .'
cmd pass "$DEV" 'clip.exe < notes.md'
cmd pass "$DEV" 'code.exe --version'
cmd pass "$DEV" 'grep -rn wsl.exe rules/'
cmd pass "$DEV" 'python3 -c "import sys; print(sys.executable)"'
cmd pass "$DEV" 'sed -n 1,20p .claude/hooks/shim/wsl.exe'
# ...and everything a development session actually does passes.
cmd pass "$DEV" 'ssh root@server1.example.com uptime'
cmd pass "$DEV" 'sudo apt-get update'
cmd pass "$DEV" 'grep -rn ssh rules/'
cmd pass "$DEV" 'git commit -F /tmp/msg.txt'
cmd pass "$DEV" 'git push -u origin feat/28-workspace-mode'
cmd pass "$DEV" 'ssh-keygen -lf key.pub'
cmd pass "$DEV" 'ls -l /etc/ssh/'
cmd pass "$DEV" 'rsync -a templates/ /tmp/copy/'
cmd pass "$DEV" 'sh tests/hooks/guard-taboos.sh'
cmd pass "$DEV" 'git commit -m "ssh: keep one connection per host"'
cmd pass "$DEV" 'command -v ssh'
cmd pass "$DEV" 'command -pv sudo'
cmd pass "$DEV" 'PATH="$PWD/stub:$PATH" sh test.sh'
cmd pass "$DEV" 'PYTHONPATH=lib python3 ssh_check.py'
cmd pass "$DEV" 'grep -n Port rules/ssh-connections.md'
cmd pass "$DEV" 'sed -n 1,20p .claude/hooks/shim/ssh'
cmd pass "$DEV" 'echo "$GIT_SSH_COMMAND"'
cmd pass "$DEV" 'cat > notes.md <<EOF
ssh root@server1.example.com uptime
sudo systemctl reload nginx
EOF'
edit pass "$DEV" "$DEV/rules/backups.md"
