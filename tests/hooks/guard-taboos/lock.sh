# tests/hooks/guard-taboos/lock.sh — the server lock. Sourced by
# tests/hooks/guard-taboos.sh, in its order, into the one shell
# every part shares; never run on its own.
# shellcheck shell=sh

# --- The server lock: /etc/hostwarden.conf, /etc/heinzel.conf --
# The machine's owner sets it; Hostwarden reads it and never lifts
# it, by any of the ways a file gets written, moved or deleted,
# under either name and every spelling of it
# (guard-taboos.d/lock.sh).
for LK in /etc/hostwarden.conf /etc/heinzel.conf; do
  check deny "echo \"allow_changes = true\" > $LK"
  check deny "echo x >> $LK"
  check deny "sed -i 's/false/true/' $LK"
  check deny "rm $LK"
  check deny "rm -f /private$LK"
  check deny "mv $LK ${LK}.off"
  check deny "chmod 000 $LK"
  check deny "truncate -s 0 $LK"
  check deny "cp lock.conf $LK"
  check deny "tee $LK < x"
  check deny "vi $LK"
  check deny "ssh root@h \"rm $LK\""
  check deny "ssh root@h \"sed -i s/false/true/ $LK\""
  check deny "python3 -c \"import os; os.remove('$LK')\""
  check deny "ln -sf /dev/null $LK"
  check pass "cat $LK"
  check pass "ssh root@h \"cat $LK\""
  check pass "grep -i allow_changes $LK"
  check pass "ls -l $LK"
done
# Other spellings of the same file: a case-insensitive file system
# (macOS), // and /./, a relative name after cd, find -delete.
check deny 'rm /ETC/HOSTWARDEN.CONF'
check deny 'rm /etc/HeInZeL.conf'
check deny 'rm /etc//hostwarden.conf'
check deny 'rm /etc/./heinzel.conf'
check deny 'cd /etc && rm hostwarden.conf'
check deny 'cd /etc; echo allow_changes=true > heinzel.conf'
check deny 'find /etc -name hostwarden.conf -delete'
check deny 'find /etc -name heinzel.conf -delete'
check deny 'ssh root@h "find /etc -name '"'"'heinzel.conf'"'"' -delete"'
check deny 'ssh root@h "find /etc -maxdepth 1 -name hostwarden.conf -exec rm {} +"'
check deny 'ssh root@h "gawk -i inplace 1 /etc/hostwarden.conf"'
check pass 'rm /etc/hostwarden.conf.bak'
check deny 'mv /etc/heinzel.conf /etc/heinzel.conf.bak'
check deny "sed -i.bak 's/false/true/' /etc/hostwarden.conf"
check deny "sed --in-place=.bak 's/false/true/' /etc/heinzel.conf"
check deny "sed -ni 's/false/true/p' /etc/heinzel.conf"
check deny "sed -I '' 's/false/true/' /etc/heinzel.conf"
check pass "sed -En 's/false//p' /etc/heinzel.conf"
check deny "perl -pi.bak -e 's/false/true/' /etc/hostwarden.conf"
check deny 'touch /etc/hostwarden.conf'
check deny 'ssh root@h "touch /etc/heinzel.conf"'
check deny 'cd /etc && touch heinzel.conf'
check pass 'touch /etc/hostwarden.conf.bak'
check pass 'touch -r /etc/hostwarden.conf /tmp/copy'
check pass 'touch --reference=/etc/heinzel.conf /tmp/copy'
check deny 'touch -r /tmp/x /etc/heinzel.conf'
check deny 'touch -r /etc/hostwarden.conf /etc/heinzel.conf'
check deny 'touch -r /etc/hostwarden.conf /tmp/copy /etc/heinzel.conf'
check deny 'touch /etc/heinzel.conf -r /tmp/x'
check deny 'touch -r /etc/hostwarden.conf /tmp/a; touch /etc/heinzel.conf'
check deny 'touch -r /etc/hostwarden.conf /etc/hostwarden.conf'
check deny 'touch /srv/a-r /etc/hostwarden.conf'
# The drop-in the baseline writes at first boot is another file;
# only the lock's own names count.
check pass 'ls /etc/foo.d/10-hostwarden.conf'
# The probe rules/access-control.md ships reads both files.
check pass 'ssh root@h "for f in /etc/hostwarden.conf /etc/heinzel.conf; do if [ -e \"\$f\" ] || [ -L \"\$f\" ]; then echo LOCK_FILE \$f; cat \"\$f\" || echo LOCK_UNREADABLE; else echo LOCK_ABSENT \$f; fi; done; echo LOCK_DONE"'
# The probe rides in the activity check's call: other commands
# beside it, a classifier pipe into awk, a cp or rm on another path.
check pass 'ssh root@h "echo ##lock; for f in /etc/hostwarden.conf /etc/heinzel.conf; do cat \$f; done; echo LOCK_DONE; journalctl -t hostwarden --no-pager | awk \"\$C\""'
check pass 'ssh root@h "cat /etc/heinzel.conf; cp /etc/hosts /root/hosts.bak; rm -f /tmp/x"'
# Copying the file out names it as an operand of cp: accepted.
check deny 'cp /etc/hostwarden.conf /tmp/lock.bak'
# A development checkout reaches no server: a commit message that
# names the lock and a delete is the work there.
check_dev pass 'git commit -m "docs: never rm /etc/hostwarden.conf"'
