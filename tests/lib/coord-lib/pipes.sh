# tests/lib/coord-lib/pipes.sh — a command over several lines, and a
# printf or echo piped into the far shell. Sourced by
# tests/lib/coord-lib.sh, in its order, into the one shell every
# part shares; never run on its own.
# shellcheck shell=sh

# A newline ends a command at the top level too, so every line's
# own ssh is found, each with its own segment: one line's reboot is
# never charged to the host another line reaches.
dest "a destination on each line" \
  "$(printf 'ssh web1 uname\nssh web2 uname')" \
  "$(printf 'web1\tssh web1 uname\nweb2\tssh web2 uname')"
destkind "a reboot on the second line is the second host's" \
  "$(printf 'ssh web1 uptime\nssh web2 reboot')" 'reboot'
dest "a reboot on the second line is not the first line's" \
  "$(printf 'ssh web1 uptime\nssh web2 reboot')" \
  "$(printf 'web1\tssh web1 uptime\nweb2\tssh web2 reboot')"
dest "a line continued by a backslash stays one command" \
  "$(printf 'ssh web1 \\\n  uptime')" \
  "$(printf 'web1\tssh web1 \;  uptime')"
dest "a quoted newline stays inside its segment" \
  "$(printf "ssh web1 'uptime\nuname'")" \
  "$(printf "web1\tssh web1 'uptime;uname'")"
dest "the line after a heredoc's closing line is read on its own" \
  "$(printf 'ssh h1 uptime; ssh h2 sh -s <<EOS\nsystemctl reboot\nEOS\nssh h3 uname')" \
  "$(printf 'h1\tssh h1 uptime\nh2\tssh h2 sh -s <<EOS;systemctl reboot;EOS\nh3\tssh h3 uname')"
destkind "the host after a heredoc is not charged with its body" \
  "$(printf 'ssh h2 sh -s <<EOS\nsystemctl restart nginx\nEOS\nssh h3 uname')" \
  'restart:nginx'

# A pipeline feeding a remote shell on stdin runs what it writes
# there, the way a heredoc body does: a printf or echo upstream is
# read as that shell's commands.
destkind "printf piped into a remote sh -s" \
  "printf '%s\n' 'export LC_ALL=C' 'systemctl reboot' | ssh web2 'sh -s'" \
  'reboot'
dest "printf piped into a remote sh -s joins its segment" \
  "printf '%s\n' 'export LC_ALL=C' 'systemctl reboot' | ssh web2 'sh -s'" \
  "$(printf "web2\tssh web2 'sh -s';export LC_ALL=C;systemctl reboot")"
destkind "echo piped into a remote login shell" \
  "echo 'systemctl restart nginx' | ssh web2" 'restart:nginx'
destkind "an escaped newline in a printf format" \
  "printf 'uptime\nsudo reboot\n' | sudo ssh -F cfg root@web2 bash" 'reboot'
destkind "a pipeline continued on the next line" \
  "$(printf "echo reboot |\n  ssh web2 sh")" 'reboot'
destkind "a stage after the printf leaves nothing read" \
  "printf 'reboot\n' | tr a-z a-z | ssh web2 sh" ''
destkind "a filter after the echo leaves nothing read" \
  "echo reboot | grep -v reboot | ssh web2 sh" ''
destkind "the last stage's printf is what is read" \
  "echo uptime | printf 'reboot\n' | ssh web2 sh" 'reboot'
destkind "printf %s writes an argument's \\n as it stands" \
  "printf '%s\n' 'echo harmless\nreboot' | ssh web2 sh" ''
destkind "printf %b expands its argument's \\n" \
  "printf '%b\n' 'uptime\nsudo reboot' | ssh web2 sh -s" 'reboot'
destkind "an escaped backslash before n is no newline" \
  "printf 'echo a\\\\nreboot\n' | ssh web2 sh" ''
destkind "a conversion without an argument prints nothing" \
  "printf 'reboot%s\n' | ssh web2 sh" 'reboot'
destkind "echo without -e is read with \\n decoded, as zsh writes it" \
  "echo 'uptime\nreboot' | ssh web2 sh" 'reboot'
destkind "echo -E writes \\n as it stands" \
  "echo -E 'uptime\nreboot' | ssh web2 sh" ''
destkind "echo -e decodes \\n" \
  "echo -e 'uptime\nreboot' | ssh web2 sh" 'reboot'
destkind "sftp runs no far shell for a feed" \
  "echo reboot | sftp web2" ''
destkind "a remote shell running a script file reads no feed" \
  "echo reboot | ssh web2 sh /tmp/check.sh" ''
destkind "a remote shell with -s and positional arguments reads stdin" \
  "echo reboot | ssh web2 bash -s -- arg1" 'reboot'
destkind "a remote shell with -o and its value reads stdin" \
  "echo reboot | ssh web2 bash -o pipefail" 'reboot'
destkind "a remote command other than a shell reads no feed" \
  "echo reboot | ssh web2 'cat > /tmp/notes'" ''
destkind "a remote sh -c reads no feed" \
  "echo reboot | ssh web2 sh -c uptime" ''
destkind "|| is no pipe" "echo reboot || ssh web2 sh" ''
destkind "a ; ends the feed" "echo reboot; true | ssh web2 sh" ''
destkind "echo writes its operands as one line" \
  "echo shutdown -r now | ssh web2 sh" 'reboot'
destkind "echo of an unquoted restart" \
  "echo systemctl restart nginx | ssh web2" 'restart:nginx'
destkind "printf fills its format and reuses it" \
  "printf 'systemctl restart %s\n' nginx php-fpm | ssh web2 sh" \
  "$(printf 'restart:nginx\nrestart:php-fpm')"
destkind "printf -- takes the next word as its format" \
  "printf -- '%s\n' 'systemctl reboot' | ssh web2 sh -s" 'reboot'
destkind "printf -v writes nothing into the pipe" \
  "printf -v x 'reboot\n' | ssh web2 sh -s" ''
destkind "a double-quoted printf format keeps its \\n" \
  'printf "uptime\nsystemctl reboot\n" | ssh web2 sh -s' 'reboot'
destkind "echo -e of a double-quoted \\n" \
  'echo -e "uptime\nreboot" | ssh web2 sh -s' 'reboot'
destkind "a remote env with an assignment reads stdin" \
  "printf 'systemctl reboot\n' | ssh web2 env LC_ALL=C sh -s" 'reboot'
destkind "a remote env -C reads stdin" \
  "echo reboot | ssh web2 env -C /tmp sh" 'reboot'
destkind "a remote VAR=value prefix reads stdin" \
  "echo reboot | ssh web2 LC_ALL=C bash" 'reboot'
destkind "a remote su - reads stdin" \
  "echo reboot | ssh web2 sudo su -" 'reboot'
destkind "a remote su -c reads no feed" \
  "echo reboot | ssh web2 su -c uptime" ''
destkind "an unreadable upstream adds nothing" \
  "cat script.sh | ssh web2 sh" ''
