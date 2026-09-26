# guard-taboos.d/interpreters.sh — effects reached through an interpreter.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh

# --- Effects reached through an interpreter -------------------
# Every rule above recognizes a write by the way it is spelled: a
# redirect, tee, sed -i, an editor, rm/mv/chmod/truncate. A
# language runtime spells none of those and reaches the same
# effects through plain file I/O:
#
#   python3 -c "open('/etc/ssh/sshd_config','a').write(...)"
#   node -e "require('fs').unlinkSync('...authorized_keys')"
#   python3 -c "open('/dev/sda','wb').write(...)"
#
# Its command line is opaque to a pattern matcher -- read and
# write look alike from outside -- so the read-only exemption
# cannot be proven, and an unprovable exemption must not apply.
# A runtime carrying a protected path or a raw device is
# therefore a write. Issue #6.
#
# This enumerates RUNTIMES, not write syntaxes, on purpose. The
# set of ways to write a file grows with every language feature
# and can never be closed; the set of interpreters Hostwarden might
# meet on a server is small and moves slowly. It still is a list,
# so this rule is a backstop against the everyday mistake, not a
# sandbox: an interpreter that builds its target string at
# runtime, or downloads it, defeats any string matcher. Real
# isolation is the operator's job, not this hook's.
#
# Interpreters that shell out (os.system, %x, child_process) need
# no rule of their own: every check above scans the whole command
# string, so the taboo word inside is caught where it stands.
#
# Accepted false positive: any command that merely mentions an
# interpreter alongside one of these targets is blocked too, even
# when it only reads -- awk '/^Port/' /etc/ssh/sshd_config, or a
# cat of the file chained to an unrelated python call. Read with
# cat, grep, jq, stat or sshd -T instead, which is what the rule
# files use anyway.
if hit "$INTERP" || { [ -n "$WIN" ] && hit_i "$WININTERP"; }; then
  if [ "$HAS_KEY" -eq 1 ]; then
    deny "an interpreter with an SSH key path on its command \
line can overwrite or delete the key, and a pattern matcher \
cannot tell that from a read - read keys with cat, stat or \
ssh-keygen -lf instead"
  fi
  if [ "$HAS_SSHD" -eq 1 ]; then
    deny "an interpreter with sshd_config on its command line \
can rewrite it, and a pattern matcher cannot tell that from a \
read - read it with cat, grep or sshd -T instead"
  fi
  if [ "$HAS_KRL" -eq 1 ]; then
    deny "an interpreter with sshd's revocation list on its \
command line can delete it, which makes sshd refuse every public \
key login - read it with ssh-keygen -Q -l or ls -l instead"
  fi
  if full && hit "$DEV"; then
    deny "an interpreter with a raw disk device on its command \
line can overwrite the device, which destroys everything the \
partition table points at"
  fi
fi
