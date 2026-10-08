# tests/hooks/guard-taboos/redirect.sh — a redirect onto a computed
# target. Sourced by tests/hooks/guard-taboos.sh, in its order,
# into the one shell every part shares; never run on its own.
# shellcheck shell=sh

# --- a redirect onto a computed target -------------------------
# The shape that truncated /usr/bin/nvim upstream, escaped through
# ssh and bash -ic, then each form on its own: an arrow onto a
# lookup, a variable and a braced variable, and every redirect
# spelling onto a lookup, quoted, bare and escaped for an inner ssh.
check deny 'ssh root@h '\''bash -ic "echo sensible-editor would run: \$SELECTED_EDITOR -> \$(readlink -f \$SELECTED_EDITOR)"'\'''
check deny 'echo editor -> $(readlink -f /usr/bin/editor)'
check deny 'echo editor -> $SELECTED_EDITOR'
check deny 'ssh h "echo editor ->\${EDITOR}"'
check deny 'echo x > "$(command -v nvim)"'
check deny 'echo x >|$(which vim)'
check deny 'echo x >> $(command -v vim)'
check deny 'ssh h "echo x 1> \$(command -v vim)"'
check deny 'ssh h "echo editor -> \$E"'
# The older spelling of a lookup, a redirect merged with stderr, and
# the quote itself escaped one ssh level in.
check deny 'echo x > `which vim`'
check deny 'echo editor -> `readlink -f /usr/bin/editor`'
check deny 'ssh root@h "bash -c '\''echo editor -> \`readlink -f /usr/bin/editor\`'\''"'
check deny 'echo x >& $(which vim)'
check deny 'echo x > "`which vim`"'
check deny 'echo x >`which vim`'
check deny 'echo x>`which vim`'
check deny 'echo x >> `which vim`'
check deny 'echo x 2>>`which vim`'
check deny 'echo x &>> `which vim`'
check deny 'echo $E>`readlink -f $E`'
check deny 'echo editor ->`which vim`'
check deny 'ssh root@h "bash -c '\''echo editor -> \"\`readlink -f /usr/bin/editor\`\"'\''"'
check deny 'ssh h "echo x > \"\$(command -v vim)\""'
check deny 'ssh h "echo editor -> \"\$E\""'
# A target set in sight, a lookup inside the text, process
# substitution and an arrow onto a plain word are not that.
check pass 'out=$(ls /etc 2>&1); echo "$out"'
check pass 'echo "$(date) done" > log.txt'
check pass 'echo "built `date`" > log.txt'
# Prose: a placeholder closed before a code span, and an arrow
# quoted as one.
check pass 'printf "%s\\n" "a key (`0x<key>`) and an arrow (`->`)"'
check pass 'cmd 2>&1 >/dev/null | grep $PAT'
check pass 'cat - > "$OUT"'
check pass 'tar -cf - . > "$T/backup.tar"'
check pass 'echo editor -> vim'
check pass 'diff <(sort a) <(sort b)'
check pass 'ls | tee >(wc -l) > list.txt'
check pass 'ssh h "ls > /tmp/out; echo \$HOME"'
check pass 'ssh h "readlink -f \$(command -v editor)"'
check pass 'php -r '\''$a = ["k" => $v];'\'''
# Accepted false positive: quoted here, but one ssh or bash -c
# level further in the same quotes are gone, and the guard cannot
# count quote depth. The same shape as a search pattern is text
# and counts too (the header of guard-taboos.sh).
check deny 'echo "editor -> $(readlink -f /usr/bin/editor)"'
check deny "grep -n 'echo x > \"\$(command -v nvim)\"' tests/hooks/guard-taboos/redirect.sh"
# The local scope leaves this user's own files to the user, so the
# repository's own fixtures can be searched; a route to a server
# brings the rule back.
if [ -n "$LOCAL_SCOPE" ]; then
  check_dev pass "grep -n 'echo x > \"\$(command -v nvim)\"' tests/hooks/guard-taboos/redirect.sh"
  check_dev pass 'git commit -m "guard: deny echo editor -> $(readlink -f $E)"'
fi
check_dev deny 'ssh h "echo editor -> \$(readlink -f /usr/bin/editor)"'
check_dev deny 'sudo sh -c "echo x > $(command -v nvim)"'
