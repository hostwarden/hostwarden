# tests/bin/hostwarden-password/command.sh — hostwarden-password itself. Sourced by
# tests/bin/hostwarden-password.sh, in its order, into the one shell
# every part shares; never run on its own.
# shellcheck shell=sh

# --- hostwarden-password ------------------------------------------
out=$(sh "$PWD_CMD" set alice@rtr1 </dev/null 2>&1)
has "$out" "needs a terminal" "set ran without a terminal"
out=$(sh "$PWD_CMD" token 1password </dev/null 2>&1)
has "$out" "needs a terminal" "token ran without a terminal"
out=$(sh "$PWD_CMD" check alice@rtr1 2>&1)
has "$out" "(alice@192.0.2.1:22): in the file store" "check without a line"
sh "$PWD_CMD" check alice@rtr2 >/dev/null 2>&1 &&
  bad "check found a password for rtr2" || ok
out=$(sh "$PWD_CMD" link alice@rtr1 'rbw a;b' 2>&1)
has "$out" "not a source" "link took an invalid source"
out=$(sh "$PWD_CMD" link alice@rtr1 '1password op://V/bank/password' 2>&1)
has "$out" "must hold alice@192.0.2.1:22" "link took an unbound entry"
grep -q 'bank' "$OPS/memory/user.md" && bad "link recorded an unbound entry" || ok
# Only through an identity that sees Hostwarden's entries alone.
printf '%s' '[{"id":"v1","name":"V"},{"id":"v2","name":"Private"}]' \
  > "$TMP/op-vaults"
out=$(sh "$PWD_CMD" link alice@rtr1 '1password op://V/rtr1/password' 2>&1)
has "$out" "sees 2 vaults" "link took a service account that sees two vaults"
printf '%s' '[{"id":"v2","name":"Other"}]' > "$TMP/op-vaults"
out=$(sh "$PWD_CMD" link alice@rtr1 '1password op://V/rtr1/password' 2>&1)
has "$out" "another vault" "link took a reference to a vault the account cannot see"
printf '%s' '[{"id":"v1","name":"V"}]' > "$TMP/op-vaults"
out=$(sh "$PWD_CMD" link alice@rtr1 'rbw mine/Router' 2>&1)
has "$out" "not set up" "link took an rbw profile that is not set up"
out=$(sh "$PWD_CMD" link alice@rtr1 'rbw hw/Router' 2>&1)
grep -qx -- '- alice@rtr1: rbw hw/Router' "$OPS/memory/user.md" && ok ||
  bad "link did not record a set-up rbw profile: $out"
out=$(sh "$PWD_CMD" link alice@rtr1 '1password op://V/rtr1/password' 2>&1)
lacks "$out" "op-secret" "link printed the password"
grep -qx -- '- alice@rtr1: 1password op://V/rtr1/password' \
  "$OPS/memory/user.md" && ok || bad "link recorded no line"
out=$(sh "$PWD_CMD" check alice@rtr1 2>&1)
has "$out" "entry names the target" "check of a linked entry"
lacks "$out" "op-secret" "check printed the password"
sh "$PWD_CMD" remove alice@rtr1 >/dev/null 2>&1
grep -q '^- alice@rtr1' "$OPS/memory/user.md" && bad "remove kept the line" || ok
lib 'pw_record alice@rtr1 "local file"'
sh "$PWD_CMD" remove alice@rtr1 >/dev/null 2>&1
lib 'pw_local_has file ssh alice@192.0.2.1:22' &&
  bad "remove kept the stored password" || ok
# A password stored before a link goes too, from whichever local
# store holds it, or it would answer again once the line is gone.
lib 'printf %s old | pw_local_put file ssh alice@192.0.2.1:22
  pw_record alice@rtr1 "1password op://V/rtr1/password"'
HOSTWARDEN_PASSWORD_STORE=keychain sh "$PWD_CMD" remove alice@rtr1 \
  >/dev/null 2>&1
lib 'pw_local_has file ssh alice@192.0.2.1:22' &&
  bad "remove kept a password stored before the link" || ok
# A Mac without security cannot ask its keychain; any other system
# has none.
lib 'uname() { echo Darwin; }; pw_has() { return 1; }
  pw_local_probe keychain ssh alice@192.0.2.1:22'
[ $? -eq 2 ] && ok || bad "a Mac without security was called an empty keychain"
lib 'uname() { echo Linux; }; pw_has() { return 1; }
  pw_local_probe keychain ssh alice@192.0.2.1:22'
[ $? -eq 1 ] && ok || bad "a system without a keychain was called unreachable"
# A store that cannot be asked is not an empty one: nothing is
# forgotten and the line stays.
lib 'printf %s old | pw_local_put file ssh alice@192.0.2.1:22
  pw_record alice@rtr1 "local file"'
: > "$TMP/sec-down"
out=$(HOSTWARDEN_PASSWORD_STORE=keychain sh "$PWD_CMD" remove alice@rtr1 2>&1)
has "$out" "could not be checked" "remove called an unreachable keychain empty"
grep -q '^- alice@rtr1' "$OPS/memory/user.md" && ok ||
  bad "remove dropped the line although the keychain could not be checked"
lib 'pw_local_has file ssh alice@192.0.2.1:22' && ok ||
  bad "remove deleted the file store's password before it was sure"
rm -f "$TMP/sec-down"
HOSTWARDEN_PASSWORD_STORE=keychain sh "$PWD_CMD" remove alice@rtr1 \
  >/dev/null 2>&1
lib 'pw_local_has file ssh alice@192.0.2.1:22' &&
  bad "remove kept the password once the keychain answered" || ok
out=$(sh "$REPO/bin/hostwarden-password" check alice@rtr1 2>&1)
has "$out" "only an operations checkout" "ran outside an operations checkout"

