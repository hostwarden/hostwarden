# tests/hooks/guard-taboos/edit.sh — Edit, Write, MultiEdit,
# NotebookEdit and Monitor. Sourced by tests/hooks/guard-taboos.sh,
# in its order, into the one shell every part shares; never run on
# its own.
# shellcheck shell=sh

# --- Edit, Write, MultiEdit, NotebookEdit: the target path ------
# Judged by the file they write, in every mode: an SSH key,
# authorized_keys or sshd_config is denied, and their content is
# never scanned. The file-tool branch runs before the scope is read,
# so one case in the development tree stands for the mode.
file_case() { hook_case "$HOOK" "file tool" "$@"; }
fjson() {
  # fjson <tool> <path> [content] [cwd]
  jq -n --arg t "$1" --arg p "$2" --arg c "${3:-x}" --arg w "${4:-/r}" \
    'if $t == "NotebookEdit"
     then {cwd:$w,tool_name:$t,tool_input:{notebook_path:$p,new_source:$c}}
     else {cwd:$w,tool_name:$t,tool_input:{file_path:$p,content:$c}} end'
}
file_case deny 'Write authorized_keys' \
  "$(fjson Write /home/alice/.ssh/authorized_keys)"
hook_case "$GUARD_DEV" "file tool in development" deny 'Write authorized_keys' \
  "$(fjson Write /home/alice/.ssh/authorized_keys)"
file_case deny 'Write authorized_keys2' \
  "$(fjson Write /root/.ssh/authorized_keys2)"
file_case deny 'Edit a private key' \
  "$(fjson Edit /Users/alice/.ssh/id_ed25519)"
file_case deny 'Write a public key' \
  "$(fjson Write /home/alice/.ssh/id_ed25519.pub)"
file_case deny 'Edit sshd_config' "$(fjson Edit /etc/ssh/sshd_config)"
file_case deny 'MultiEdit a Homebrew sshd_config' \
  "$(fjson MultiEdit /opt/homebrew/etc/ssh/sshd_config)"
file_case deny 'Edit QNAP sshd_config' \
  "$(fjson Edit /etc/config/ssh/sshd_config)"
file_case deny 'Write QNAP sshd_user_config' \
  "$(fjson Write /etc/config/ssh/sshd_user_config)"
file_case deny 'Write an sshd drop-in' \
  "$(fjson Write /etc/ssh/sshd_config.d/50-local.conf)"
file_case deny 'Write a host key under /usr/local' \
  "$(fjson Write /usr/local/etc/ssh/ssh_host_ed25519_key)"
file_case deny 'Write into an appliance key store' \
  "$(fjson Write /conf/sshd/ssh_host_rsa_key)"
file_case deny 'Write the file pfSense merges into sshd_config' \
  "$(fjson Write /etc/sshd_extra)"
file_case deny 'Write sshd_config in an offline image' \
  "$(fjson Write /mnt/etc/ssh/sshd_config)"
file_case deny 'NotebookEdit onto authorized_keys' \
  "$(fjson NotebookEdit /home/alice/.ssh/authorized_keys)"
file_case deny 'relative path resolved against cwd' \
  "$(fjson Write .ssh/authorized_keys x /home/alice)"
file_case deny 'Write a dropbear host key' \
  "$(fjson Write /etc/dropbear/dropbear_ed25519_host_key)"
file_case deny "Write OpenWrt's dropbear config" \
  "$(fjson Write /etc/config/dropbear)"
file_case deny "Edit OpenRC's dropbear config" \
  "$(fjson Edit /etc/conf.d/dropbear)"
file_case deny "Write a key in OpenMediaVault's authorized_keys directory" \
  "$(fjson Write /var/lib/openmediavault/ssh/authorized_keys/alice)"
file_case deny "Write Windows' sshd_config through /mnt/c" \
  "$(fjson Write /mnt/c/ProgramData/ssh/sshd_config)"
file_case deny "Write administrators_authorized_keys with backslashes" \
  "$(fjson Write 'C:\ProgramData\ssh\administrators_authorized_keys')"
file_case deny 'a private key behind Windows separators' \
  "$(fjson Write 'C:\Users\alice\.ssh\id_ed25519')"
file_case pass 'a note about dropbear' \
  "$(fjson Write /r/docs/dropbear.md)"
# macOS file systems ignore case by default, so the match does too.
file_case deny 'authorized_keys in upper case' \
  "$(fjson Write /Users/alice/.SSH/AUTHORIZED_KEYS)"
file_case deny 'a private key in mixed case' \
  "$(fjson Write /Users/alice/.ssh/Id_Ed25519)"
file_case deny 'sshd_config under a mixed-case /etc/SSH' \
  "$(fjson Edit /etc/SSH/sshd_config)"
file_case pass 'a document named after the key file' \
  "$(fjson Edit /r/rules/authorized_keys.md)"
file_case pass 'an example sshd_config' \
  "$(fjson Edit /r/docs/sshd_config.example)"
file_case pass 'ssh client config' "$(fjson Write /home/alice/.ssh/config)"
file_case pass 'known_hosts' "$(fjson Write /home/alice/.ssh/known_hosts)"
file_case pass 'content that names taboos is text' \
  "$(fjson Edit /r/rules/os/debian.md 'mkfs.ext4 /dev/sda1; rm ~/.ssh/id_ed25519; shutdown -h now')"
file_case pass 'content with the off switch is text (guard-settings has settings)' \
  "$(fjson Write /r/docs/x.md 'HOSTWARDEN_GUARD_DISABLE=1')"
# Links: the file system decides, not the spelling.
FL=$(mktemp -d)
FL=$(cd "$FL" && pwd -P)
mkdir -p "$FL/.ssh"
: > "$FL/.ssh/authorized_keys"
ln -s .ssh/authorized_keys "$FL/notes.md"
ln -s .ssh "$FL/keys"
file_case deny 'a link that points at authorized_keys' \
  "$(fjson Write "$FL/notes.md")"
file_case deny 'a key reached through a linked directory' \
  "$(fjson Write "$FL/keys/id_ed25519")"
# A .. after a directory that does not exist yet: a tool that
# normalises the path by text lands on the key.
file_case deny 'a key behind a missing directory and ..' \
  "$(fjson Write "$FL/.ssh/nosuch/../id_ed25519")"
file_case deny 'a linked key directory behind a missing directory and ..' \
  "$(fjson Write "$FL/keys/nosuch/../id_ed25519")"
file_case pass 'a .. that leaves the key directory' \
  "$(fjson Write "$FL/.ssh/../notes.txt")"
ln -s loop-b "$FL/loop-a"
ln -s loop-a "$FL/loop-b"
file_case deny 'a chain of links that does not end' \
  "$(fjson Write "$FL/loop-a")"
rm -rf "$FL"
file_case deny 'no jq: Write authorized_keys' \
  "$(fjson Write /home/alice/.ssh/authorized_keys)" "PATH=$NOJQ"
file_case pass 'no jq: Write an ordinary file' \
  "$(fjson Write /r/docs/x.md 'hello')" "PATH=$NOJQ"
rm -rf "$NOJQ"

# --- Monitor runs a shell command too -----------------------------
# Its command arrives in tool_input.command like Bash's, and the
# matcher in settings.json hands it to both guards. A taboo sent
# through Monitor is a taboo; an ordinary watch passes.
check deny 'poweroff' Monitor
check deny 'sgdisk --zap-all /dev/sda' Monitor
check deny 'ssh root@h "shutdown -h now"' Monitor
check deny "printf 'PermitRootLogin no\\n' >> /etc/ssh/sshd_config" Monitor
check deny 'while true; do rm -f ~/.ssh/authorized_keys; sleep 60; done' Monitor
check pass 'tail -f /var/log/syslog | grep --line-buffered -E "error|fail"' Monitor
check pass 'until gh pr checks 12 | grep -qv pending; do sleep 30; done' Monitor
# A WebSocket watch has no command and starts no shell, so its
# description is not scanned as one.
check pass '{"tool_name":"Monitor","tool_input":{"ws":{"url":"wss://events.example.com/x"},"description":"watch shutdown events"}}' JSON
check pass '{"tool_name":"Monitor","tool_input":{"ws":{"url":"wss://events.example.com/x"},"description":"mkfs progress","timeout_ms":300000}}' JSON
# Its description does not rescue a command that is one.
check deny '{"tool_name":"Monitor","tool_input":{"command":"poweroff","description":"ws"}}' JSON
settings_case deny 'Monitor: write it into settings.local.json' \
  "$(json_for "printf x $V >> .claude/settings.local.json" Monitor)"
settings_case deny 'Monitor: touch a guard-off record' \
  "$(json_for 'touch ~/.cache/hostwarden/guard-off-abc' Monitor)"
settings_case pass 'Monitor: tail a log' \
  "$(json_for 'tail -f /var/log/syslog' Monitor)"
