# tests/hooks/guard-mode/monitor.sh — Monitor, which runs a shell
# command too. Sourced by tests/hooks/guard-mode.sh, in the order
# its PARTS lists, into the one shell every part shares; never run
# on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# Monitor runs a shell command too. Everything denied for Bash is
# denied for it, and since the env file that carries the shim is
# documented for Bash only, so is a bare tool at the start of a
# segment. A watch that reaches no server passes, and so does a
# WebSocket watch, which starts no shell.
mon() { queue "$1" "$2" Monitor "$3"; }
mon deny "$DEV" '/usr/bin/ssh server1.example.com tail -f /var/log/syslog'
mon deny "$DEV" 'PATH=/usr/bin:/bin ssh server1.example.com uptime'
mon deny "$DEV" 'command -p ssh server1.example.com'
mon deny "$DEV" 'ssh root@server1.example.com tail -f /var/log/syslog'
mon deny "$DEV" 'sudo tail -f /var/log/auth.log | grep --line-buffered sshd'
mon deny "$DEV" 'while true; do "ssh" server1.example.com uptime; sleep 30; done'
mon deny "$DEV" 'rsync -av server1.example.com::mod here/'
mon deny "$DEV" 'ssh.exe server1.example.com tail -f /var/log/syslog'
mon deny "$DEV" 'wsl.exe -u root -e tail -f /var/log/auth.log'
mon deny "$DEV" 'PowerShell.exe -Command Get-Content -Wait C:\log.txt'
mon deny "$DEV" 'ansible all -m command -a uptime'
mon deny "$DEV" 'while true; do ansible-playbook --check site.yml; sleep 60; done'
mon deny "$DEV" 'tofu plan -detailed-exitcode'
mon pass "$DEV" 'tail -f /tmp/build.log | grep --line-buffered ansible-playbook'
mon pass "$DEV" 'tail -f /tmp/build.log | grep --line-buffered "ssh.exe|wsl.exe"'
mon pass "$DEV" 'tail -f /tmp/build.log | grep --line-buffered -E "error|ssh"'
mon pass "$DEV" 'until gh pr checks 12 | grep -qv pending; do sleep 30; done'
# Launchers run the rest of their line, past their options, the
# values those take and their operands, and so does a redirection.
mon deny "$DEV" 'setsid ssh server1.example.com true'
mon deny "$DEV" 'setsid -w ssh server1.example.com true'
mon deny "$DEV" 'env LC_ALL=C ssh server1.example.com uptime'
mon deny "$DEV" 'env -u LANG FOO=1 ssh server1.example.com uptime'
mon deny "$DEV" "env -S 'ssh server1.example.com uptime'"
mon deny "$DEV" 'timeout 5 ssh server1.example.com uptime'
mon deny "$DEV" 'timeout -s KILL 5 ssh server1.example.com uptime'
mon deny "$DEV" 'timeout --kill-after 5 10 ssh server1.example.com uptime'
mon deny "$DEV" 'nice -n 5 ssh server1.example.com uptime'
mon deny "$DEV" 'nohup ssh server1.example.com uptime'
mon deny "$DEV" 'nohup env timeout 5 sudo tail -f /var/log/auth.log'
mon deny "$DEV" 'time -p ssh server1.example.com uptime'
mon deny "$DEV" 'exec -a watcher ssh server1.example.com uptime'
mon deny "$DEV" 'stdbuf -o L ssh server1.example.com tail -f /var/log/syslog'
mon deny "$DEV" 'echo server1.example.com | xargs -n 1 -I h ssh h uptime'
mon deny "$DEV" 'echo server1.example.com | xargs -Is ssh s uptime'
mon deny "$DEV" 'echo server1.example.com | xargs --max-args 1 ssh h uptime'
mon deny "$DEV" 'echo server1.example.com | xargs --max-procs 4 --delimiter , ssh'
mon deny "$DEV" 'stdbuf --output L ssh server1.example.com tail -f /var/log/syslog'
mon deny "$DEV" 'ionice --class 3 ssh server1.example.com uptime'
mon deny "$DEV" 'echo server1.example.com | xargs --replace ssh {} uptime'
mon deny "$DEV" 'time ! ssh server1.example.com true'
mon deny "$DEV" 'time -p ! ssh server1.example.com true'
mon deny "$DEV" 'flock /tmp/lock ssh server1.example.com true'
mon deny "$DEV" 'flock -w 5 /tmp/lock ssh server1.example.com true'
mon deny "$DEV" "flock -c 'ssh server1.example.com true' /tmp/lock"
mon deny "$DEV" "flock /tmp/lock -c 'ssh server1.example.com true'"
mon deny "$DEV" "flock --command 'ssh server1.example.com true' /tmp/lock"
mon pass "$DEV" 'flock /tmp/lock tail -f /tmp/build.log'
mon deny "$DEV" "env -S'ssh server1.example.com true'"
mon deny "$DEV" "env --split-string='ssh server1.example.com true'"
mon deny "$DEV" "env -iS'ssh server1.example.com true'"
mon deny "$DEV" 'builtin exec ssh server1.example.com true'
mon deny "$DEV" 'builtin command ssh server1.example.com true'
mon deny "$DEV" 'busybox ssh server1.example.com true'
mon deny "$DEV" 'unbuffer ssh server1.example.com tail -f /var/log/syslog'
mon deny "$DEV" 'chronic ssh server1.example.com true'
mon deny "$DEV" 'ssh-agent -t 60 ssh server1.example.com true'
mon deny "$DEV" 'watch -n 5 ssh server1.example.com uptime'
mon pass "$DEV" 'watch -n 5 gh pr checks 12'
mon pass "$DEV" "env -S'tail -f /tmp/build.log'"
cmd deny "$DEV" "env -S'SSH.EXE server1.example.com'"
mon pass "$DEV" 'time ! grep -q error /tmp/build.log'
mon deny "$DEV" 'env -iu LANG ssh server1.example.com uptime'
mon deny "$DEV" 'chrt 10 ssh server1.example.com uptime'
mon deny "$DEV" 'taskset 0x3 ssh server1.example.com uptime'
mon deny "$DEV" 'caffeinate -i ssh server1.example.com uptime'
mon deny "$DEV" '2>&1 ssh server1.example.com uptime'
mon deny "$DEV" '</dev/null ssh server1.example.com uptime'
mon pass "$DEV" 'timeout 600 tail -f /tmp/build.log'
mon pass "$DEV" 'nice -n 10 grep --line-buffered ssh /tmp/build.log'
mon pass "$DEV" 'stdbuf -oL tail -f /tmp/build.log 2>&1 | grep -E "ssh|scp"'
verdict pass "$DEV" \
  '{"tool_name":"Monitor","tool_input":{"ws":{"url":"wss://events.example.com/x"},"description":"ws","timeout_ms":300000}}'
mon deny "$WT" 'ssh root@server1.example.com uptime'
mon pass "$OPS" 'ssh root@server1.example.com tail -f /var/log/syslog'
# Text that says Monitor does not turn a Bash call into one.
cmd pass "$DEV" 'echo "Monitor" ssh'
# Containers: as scripts/lab.sh starts them, never with a way
# into this machine.
