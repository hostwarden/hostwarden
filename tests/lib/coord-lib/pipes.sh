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
destkind "ssh -n reads no feed" \
  "echo reboot | ssh -n web2 sh -s" ''
destkind "-n in a cluster reads no feed" \
  "echo reboot | ssh -nT web2 sh -s" ''
destkind "ssh -f implies -n and reads no feed" \
  "echo reboot | ssh -f web2 sh -s" ''
destkind "an n that is -p's value is no -n" \
  "echo reboot | ssh -pn web2 sh -s" 'reboot'
destkind "stdin from /dev/null reads no feed" \
  "echo reboot | ssh web2 sh -s </dev/null" ''
destkind "stdin from a file by its number reads no feed" \
  "echo reboot | ssh web2 sh -s 0<input" ''
destkind "a here-string replaces the feed" \
  "echo reboot | ssh web2 sh -s <<<uptime" ''
destkind "a heredoc replaces the feed" \
  "$(printf 'echo reboot | ssh web2 sh -s <<EOS\nuptime\nEOS')" ''
destkind "stderr redirected still reads the feed" \
  "echo reboot | ssh web2 sh -s 2>/dev/null" 'reboot'

# A heredoc body is commands only where its command reads stdin as
# commands, the way a feed is; anything else keeps it as data.
destkind "a heredoc body a remote cat writes is data" \
  "$(printf "ssh web2 'cat > /tmp/notes' <<EOS\nreboot\nEOS")" ''
dest "a data body leaves the segment, its delimiters stay" \
  "$(printf "ssh web2 'cat > /tmp/notes' <<EOS\nreboot\nEOS")" \
  "$(printf "web2\tssh web2 'cat > /tmp/notes' <<EOS;EOS")"
kind "a heredoc body a remote cat writes is data, read directly" \
  "$(printf "ssh web2 'cat > /tmp/notes' <<EOS\nreboot\nEOS")" ''
destkind "a heredoc body beside a remote script file is data" \
  "$(printf 'ssh web2 sh /tmp/check.sh <<EOS\nreboot\nEOS')" ''
reboot "a heredoc body beside a remote script file, is_reboot" \
  "$(printf 'ssh web2 sh /tmp/check.sh <<EOS\nreboot\nEOS')" no
destkind "ssh -n reads no heredoc body" \
  "$(printf 'ssh -n web2 sh -s <<EOS\nreboot\nEOS')" ''
destkind "a heredoc body for a remote login shell" \
  "$(printf 'ssh web2 <<EOS\nsystemctl restart nginx\nEOS')" \
  'restart:nginx'
destkind "a heredoc body for a remote sudo bash" \
  "$(printf 'ssh web2 sudo bash <<EOS\nreboot\nEOS')" 'reboot'
destkind "a heredoc body for sh -s with stderr redirected" \
  "$(printf 'ssh web2 sh -s 2>/dev/null <<EOS\nreboot\nEOS')" 'reboot'
destkind "a heredoc body for a shell a second ssh runs" \
  "$(printf 'ssh web2 ssh db1 sh <<EOS\nreboot\nEOS')" 'reboot'
destkind "a heredoc body for a cat a second ssh runs" \
  "$(printf 'ssh web2 ssh db1 cat <<EOS\nreboot\nEOS')" ''
destkind "a heredoc body piped on is read" \
  "$(printf 'ssh web2 cat <<EOS | sh\nreboot\nEOS')" 'reboot'
destkind "a heredoc inside the remote command, written by cat" \
  "$(printf 'ssh web2 "cat > /tmp/f <<EOF\nreboot\nEOF"')" ''
destkind "a heredoc inside the remote command, read by bash" \
  "$(printf 'ssh web2 "uptime; bash <<EOF\nreboot\nEOF"')" 'reboot'
kind "a heredoc inside the remote command, written by cat, read directly" \
  "$(printf 'ssh web2 "cat > /tmp/f <<EOF\nreboot\nEOF"')" ''
destkind "a remote shell whose output a pipe tees reads the body" \
  "$(printf "ssh web2 'sudo bash -s 2>&1 | tee /tmp/up.log' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "a remote shell before a ; reads the body" \
  "$(printf "ssh web2 'sh -s; echo rc=\$?' <<EOS\nreboot\nEOS")" 'reboot'
destkind "a body cat stores and sh then runs is read" \
  "$(printf "ssh web2 'cat > /tmp/up.sh && sh /tmp/up.sh' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "a remote shell behind timeout reads the body" \
  "$(printf "ssh web2 'timeout -k 5 600 nice -n 10 bash -s' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "a remote shell behind nohup reads the body" \
  "$(printf "ssh web2 'nohup sh -s' <<EOS\nreboot\nEOS")" 'reboot'
destkind "a remote su -c of a shell reads the body" \
  "$(printf "ssh web2 \"su -c 'sh -s'\" <<EOS\nreboot\nEOS")" 'reboot'
destkind "an option after the destination is not the remote command" \
  "$(printf "ssh -F cfg root@web2 -o ConnectTimeout=10 'sh -s' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "-- after the destination is not the remote command" \
  "$(printf 'ssh web2 -- sh -s <<EOS\nreboot\nEOS')" 'reboot'
destkind "-n after the destination reads no heredoc body" \
  "$(printf 'ssh web2 -n sh -s <<EOS\nreboot\nEOS')" ''
destkind "an option after the destination still reads the feed" \
  "echo reboot | ssh web2 -T sh -s" 'reboot'
destkind "-n after the destination reads no feed" \
  "echo reboot | ssh web2 -n sh -s" ''
destkind "a remote shell before a ; reads the feed" \
  "echo reboot | ssh web2 'sh -s; echo done'" 'reboot'
destkind "a file cat writes inside an sh -s body is data" \
  "$(printf "ssh web2 'sh -s' <<'EOS'\ncat > /etc/cron.d/x <<'X'\n0 4 * * * root reboot\nX\nuptime\nEOS")" \
  ''
destkind "timeout -p takes no value" \
  "$(printf "ssh web2 'timeout -p 600 sh -s' <<EOS\nreboot\nEOS")" 'reboot'
destkind "time -p before a remote shell" \
  "$(printf "ssh web2 'time -p sh -s' <<EOS\nreboot\nEOS")" 'reboot'
destkind "a remote shell behind flock reads the body" \
  "$(printf "ssh web2 'flock -n /run/upg.lock bash -s' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "a remote shell behind runuser -- reads the body" \
  "$(printf "ssh web2 'runuser -u app -- bash -s' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "an assignment before a wrapper and a shell" \
  "$(printf "ssh web2 'LC_ALL=C nohup bash -s' <<EOS\nreboot\nEOS")" 'reboot'
destkind "a remote shell behind flock reads the feed" \
  "echo reboot | ssh web2 'flock /run/l sh -s'" 'reboot'
destkind "a body sudo tee writes is data" \
  "$(printf "ssh web2 'sudo tee /etc/x' <<EOS\nreboot\nEOS")" ''
kind "an option after the destination is not the remote command" \
  "ssh -F cfg root@web2 -o ConnectTimeout=10 reboot" 'reboot'
kind "-- after the destination is not the remote command" \
  "ssh web2 -- systemctl restart nginx" 'restart:nginx'
destkind "a quoted -c script behind a wrapper stays whole" \
  "$(printf "ssh web2 \"timeout 900 bash -c 'cd /srv/app && sh -s'\" <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "a -c script behind a wrapper that reads nothing" \
  "$(printf "ssh web2 'timeout 9 bash -c uptime' <<EOS\nreboot\nEOS")" ''
destkind "chroot without a command starts a shell" \
  "$(printf "ssh web2 'chroot /mnt' <<EOS\nreboot\nEOS")" 'reboot'
destkind "flock -c with a shell command string" \
  "$(printf "ssh web2 'flock /run/l -c \"bash -s\"' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "env -S with a shell command string" \
  "$(printf "ssh web2 'env -S \"sh -s\"' <<EOS\nreboot\nEOS")" 'reboot'
destkind "flock -c with a command string that stores" \
  "$(printf "ssh web2 'flock /run/l -c \"cat > /x\"' <<EOS\nreboot\nEOS")" ''
destkind "tcsh reads a heredoc body" \
  "$(printf 'ssh root@fbsd1 tcsh <<EOS\nreboot\nEOS')" 'reboot'
destkind "fish behind sudo -u reads the feed" \
  "echo reboot | ssh fbsd1 sudo -u app fish" 'reboot'
destkind "xargs running each line reads the body" \
  "$(printf "ssh web2 'xargs -I{} sh -c \"{}\"' <<EOS\nreboot\nEOS")" 'reboot'
destkind "parallel without a command runs its lines" \
  "$(printf 'ssh web2 parallel <<EOS\nreboot\nEOS')" 'reboot'
destkind "at runs what it reads later" \
  "$(printf 'ssh web2 at now + 1 minute <<EOS\nreboot\nEOS')" 'reboot'
destkind "lxc-attach without a command starts a shell" \
  "$(printf "ssh web2 'lxc-attach -n ct1' <<EOS\nreboot\nEOS")" 'reboot'
destkind "a script that is /dev/stdin reads the body" \
  "$(printf 'ssh web2 bash /dev/stdin <<EOS\nreboot\nEOS')" 'reboot'
destkind ". /dev/stdin in a -c script reads the body" \
  "$(printf "ssh web2 \"sh -c '. /dev/stdin'\" <<EOS\nreboot\nEOS")" 'reboot'
destkind "xargs reads the feed" \
  "echo reboot | ssh web2 'xargs -I{} sh -c {}'" 'reboot'
destkind "at behind env LC_ALL=C reads the body" \
  "$(printf 'ssh root@fbsd1 env LC_ALL=C at now + 1 minute <<EOS\nreboot\nEOS')" \
  'reboot'
destkind "lxc-attach behind timeout starts a shell" \
  "$(printf "ssh web2 'timeout 60 lxc-attach -n ct1' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "a script that is /dev/stdin after --" \
  "$(printf 'ssh web2 bash -- /dev/stdin <<EOS\nreboot\nEOS')" 'reboot'
destkind "at behind env reads the feed" \
  "echo reboot | ssh web2 env LC_ALL=C at now" 'reboot'
destkind "runuser without -u starts a shell, as su does" \
  "$(printf "ssh root@web2 'runuser -s /bin/sh app' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "runuser --shell= is no command of its own" \
  "$(printf "ssh root@web2 'runuser --shell=/bin/sh app' <<EOS\nreboot\nEOS")" \
  'reboot'
destkind "a \$( in an unquoted body cat stores still runs" \
  "$(printf "ssh host 'cat > /tmp/notes <<EOF\n\$(reboot)\nEOF'")" 'reboot'
destkind "a backtick in an unquoted body cat stores still runs" \
  "$(printf "ssh host 'cat > /tmp/notes' <<EOF\n\`reboot\`\nEOF")" 'reboot'
destkind "a \${ cmd; } in an unquoted body still runs" \
  "$(printf "ssh host 'cat > /tmp/n' <<EOF\na \${ reboot; } b\nEOF")" 'reboot'
destkind "a quoted delimiter keeps \$( as data" \
  "$(printf "ssh host 'cat > /tmp/notes' <<'EOF'\n\$(reboot)\nEOF")" ''
destkind "an interpreter reading stdin reads the body" \
  "$(printf "ssh host python3 - <<'EOF'\nreboot\nEOF")" 'reboot'
destkind "unshare without a program starts a shell" \
  "$(printf 'ssh host unshare <<EOS\nreboot\nEOS')" 'reboot'
destkind "grep keeps the body as data" \
  "$(printf "ssh host 'grep foo' <<EOS\nreboot\nEOS")" ''
destkind "an escaped \\\$( in a stored body runs nothing" \
  "$(printf "ssh web1 'cat > /usr/local/sbin/x.sh' <<EOF\nd=\\\\\$(date +%%F)\nsystemctl restart nginx\nEOF")" \
  ''
destkind "an escaped \\\$( in a double-quoted remote string runs" \
  "$(printf "ssh web1 \"cat > f <<EOF\n\\\\\$(reboot)\nEOF\"")" 'reboot'
destkind "bash -O and its value read the body" \
  "$(printf "ssh web1 'bash -O extglob' <<EOS\nreboot\nEOS")" 'reboot'
destkind "bash --rcfile and its value read the body" \
  "$(printf 'ssh web1 bash --rcfile /dev/null <<EOS\nreboot\nEOS')" 'reboot'
destkind "an escaped \\\$( in a double-quoted string that goes on runs" \
  "$(printf "ssh web1 \"cat > /tmp/n <<EOF\n\\\\\$(reboot)\nEOF\necho done\"")" \
  'reboot'
kind "an escaped \\\$( in a double-quoted string that goes on, read directly" \
  "$(printf "ssh web1 \"cat > /tmp/n <<EOF\n\\\\\$(reboot)\nEOF\necho done\"")" \
  'reboot'
destkind "an escaped \\\$( in a single-quoted string runs nothing" \
  "$(printf "ssh web1 'cat > /tmp/n <<EOF\n\\\\\$(reboot)\nEOF\necho done'")" ''
destkind "an apostrophe in an earlier heredoc body opens no quote" \
  "$(printf "ssh web1 sh <<'O'\ncat > /tmp/a <<'X'\nit's here\nX\nssh db1 \"cat > /tmp/n <<EOF\n\\\\\$(reboot)\nEOF\necho done\"\nO")" \
  'reboot'
destkind "a chain that only stores and chmods reads no feed" \
  "printf 'reboot\n' | ssh web2 'cat > /tmp/notes && chmod 600 /tmp/notes'" ''
destkind "a chain that only stores and chmods keeps the body as data" \
  "$(printf "ssh web2 'cat > /tmp/notes && chmod 600 /tmp/notes' <<EOS\nreboot\nEOS")" \
  ''
destkind "a subshell group that only stores keeps the body as data" \
  "$(printf "ssh web2 '(umask 077; cat > f)' <<EOS\nreboot\nEOS")" ''
destkind "wall prints a feed, never runs it" \
  "echo 'reboot in 5 minutes' | ssh web2 wall" ''
destkind "|| after the delimiter is no pipe" \
  "$(printf "ssh web2 'cat > /tmp/notes' <<EOS || echo failed\nreboot\nEOS")" ''
destkind "\$(( in a stored body is arithmetic, no command" \
  "$(printf "ssh web2 'cat > f' <<EOF\nx=\$((1+2))\nreboot\nEOF")" ''
destkind "a jail named like a data command, then a shell" \
  "$(printf "ssh bsd1 'jexec mail sh' <<EOS\nreboot\nEOS")" 'reboot'
destkind "a user named like a data command, then a shell" \
  "$(printf "ssh web2 'runuser -u mail -- bash -s' <<EOS\nreboot\nEOS")" 'reboot'
destkind "a jail named like a data command, entered without one" \
  "$(printf "ssh bsd1 'jexec mail' <<EOS\nreboot\nEOS")" 'reboot'
destkind "a container named like a data command, attached without one" \
  "$(printf "ssh pve 'lxc-attach -n test' <<EOS\nreboot\nEOS")" 'reboot'
destkind "bastille console of a jail named like a data command" \
  "$(printf "ssh bsd1 'bastille console mail' <<EOS\nreboot\nEOS")" 'reboot'
