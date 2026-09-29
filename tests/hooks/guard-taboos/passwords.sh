# tests/hooks/guard-taboos/passwords.sh — stored SSH passwords and
# password manager secrets (guard-taboos.d/passwords.sh). Sourced by
# tests/hooks/guard-taboos.sh, in its order, into the one shell every
# part shares; never run on its own.
# shellcheck shell=sh

# --- reading a stored password or token ------------------------
check deny 'security find-generic-password -s hostwarden-ssh -a admin@192.0.2.1:22 -w'
check deny 'security find-generic-password -gs hostwarden-ssh -a admin@192.0.2.1:22'
check deny 'security find-internet-password -s rtr1.example.com -w'
check deny 'security dump-keychain -d'
check deny 'security export -k login.keychain -o /tmp/k'
check pass 'security find-generic-password -s hostwarden-ssh -a admin@192.0.2.1:22 >/dev/null'
check pass 'security list-keychains'
check deny 'secret-tool lookup service hostwarden-ssh account admin@192.0.2.1:22'
check deny 'secret-tool search service hostwarden-ssh'
check pass 'secret-tool clear service hostwarden-ssh account admin@192.0.2.1:22'
check deny 'op read "op://Hostwarden/rtr1/password"'
check deny 'op read --no-newline op://Hostwarden/rtr1/password'
check deny 'op --account example read op://Hostwarden/rtr1/password'
check deny 'op item get rtr1 --reveal --fields password'
check deny 'op document get cert'
check deny 'op inject -i tpl.env'
check deny 'op run --env-file=app.env -- env'
check pass 'op --version'
check pass 'op vault list'
check deny 'rbw get Router admin'
check deny 'rbw get --field hostwarden Router admin'
check deny 'rbw code Router'
check pass 'rbw unlocked'
check deny 'bws secret get 11111111-1111-1111-1111-111111111111 --output json'
check deny 'BWS_ACCESS_TOKEN=x bws secret list'
check deny 'bws run -- env'
check pass 'bws project list'
check deny 'bw get password rtr1'
check deny 'bw list items --search rtr1'
check deny 'bw export --format json'
check pass 'bw status'
check deny 'cat ~/.config/hostwarden/password-key'
check deny 'ls -l ~/.local/share/hostwarden/passwords/'
check deny 'openssl enc -d -aes-256-cbc -pbkdf2 -pass file:/home/alice/.config/hostwarden/password-key -in x'

# --- another way to hand ssh a password ------------------------
check deny 'sshpass -p hunter2 ssh admin@rtr1.example.com'
check deny 'sshpass -e ssh admin@rtr1.example.com'
check deny 'SSH_ASKPASS=/tmp/keep-it ssh -F m admin@rtr1.example.com'
check deny 'export SSH_ASKPASS=/home/alice/answer.sh'
check deny 'env SSH_ASKPASS="/usr/bin/ssh-askpass" ssh admin@rtr1.example.com'
check pass 'SSH_ASKPASS=/srv/hostwarden/bin/hostwarden-askpass SSH_ASKPASS_REQUIRE=force ssh -F "/srv/hostwarden/memory/ssh_config" admin@rtr1.example.com true'
check pass "SSH_ASKPASS='/srv/hostwarden/bin/hostwarden-askpass' ssh admin@rtr1.example.com true"
check pass 'SSH_ASKPASS= ssh admin@rtr1.example.com true'

# --- what stays open -------------------------------------------
check pass 'bin/hostwarden-password check admin@rtr1'
check pass "bin/hostwarden-password link admin@rtr1 '1password op://Hostwarden/rtr1/password'"
check pass 'bin/hostwarden-password remove admin@rtr1'
check pass 'git add bin/hostwarden-askpass lib/passwords.sh'
check pass 'shellcheck bin/hostwarden-askpass'
check pass 'grep -n "op re[a]d" lib/passwords.sh'
check pass 'git log --oneline --grep=sshpass'

# --- the same in a development checkout ------------------------
check_dev deny 'security find-generic-password -s hostwarden-ssh -a a -w'
check_dev deny 'op read op://Hostwarden/rtr1/password'
check_dev pass 'bin/hostwarden-password check admin@rtr1'
