# tests/bin/hostwarden-password/store.sh — the source lines, the file store and the login methods. Sourced by
# tests/bin/hostwarden-password.sh, in its order, into the one shell
# every part shares; never run on its own.
# shellcheck shell=sh

# --- the source lines in memory/user.md ---------------------------
lib 'pw_record alice@rtr1 "local file"
  pw_record bob@rtr1 "1password op://V/rtr1/password"
  pw_record alice@rtr1 "local keychain"'
want=$(printf '# SSH Users\n\nDefault: alice\n\n# SSH Passwords\n\n%s\n%s' \
  '- alice@rtr1: local keychain' '- bob@rtr1: 1password op://V/rtr1/password')
[ "$(cat "$OPS/memory/user.md")" = "$want" ] && ok ||
  bad "pw_record wrote: $(cat "$OPS/memory/user.md")"
[ "$(lib 'pw_source BOB RTR1')" = "1password op://V/rtr1/password" ] && ok ||
  bad "pw_source is not case-blind on the login"
lib 'pw_source carol rtr1' >/dev/null && bad "pw_source found carol" || ok
lib 'pw_unrecord bob@rtr1; pw_unrecord alice@rtr1'
grep -q '^- ' "$OPS/memory/user.md" && bad "pw_unrecord left a line" || ok

for s in 'local' 'local file' 'local keychain' \
  '1password op://V/I/f' '1password op://Vault One/I/S/f' 'rbw hw/My Router' \
  'bws 0123abcd-0123-0123-0123-0123456789ab'; do
  lib "pw_valid_source '$s'" && ok || bad "valid source refused: $s"
done
for s in 'local foo' 'local secret-service' 'rbw My Router' '1password op://V/I' '1password op://V/I/f?attribute=otp' \
  'rbw a;b' 'rbw $(id)' 'bws 42' 'pass show x' ''; do
  lib "pw_valid_source '$s'" && bad "invalid source taken: $s" || ok
done
[ "$(lib 'pw_target alice RTR1.Example.com 2222')" = \
  "alice@rtr1.example.com:2222" ] && ok || bad "pw_target"

# --- the file store's key is created once -------------------------
# Two first runs at once each generate a key; the second must find
# the first's, never replace it.
KEY0=$HOME/.config/hostwarden/password-key
rm -f "$KEY0"
for _ in 1 2 3 4 5 6; do lib 'pw_file_key' & done
wait
[ -s "$KEY0" ] && ok || bad "no key after concurrent first runs"
SUM0=$(cksum < "$KEY0")
for _ in 1 2 3 4; do lib 'pw_file_key' & done
wait
[ "$(cksum < "$KEY0")" = "$SUM0" ] && ok || bad "a second run replaced the key"
ls "$KEY0".* >/dev/null 2>&1 && bad "a temporary key was left behind" || ok
rm -f "$KEY0"

# --- the file store -----------------------------------------------
lib 'printf "%s" "p w!" | pw_local_put file ssh alice@192.0.2.1:22'
[ "$(lib 'pw_local_get file ssh alice@192.0.2.1:22')" = "p w!" ] && ok ||
  bad "the file store did not give back what it stored"
KEYF=$HOME/.config/hostwarden/password-key
[ "$(ls -l "$KEYF" | cut -c1-10)" = "-rw-------" ] && ok ||
  bad "the store's key is not 0600"
if grep -rq 'p w!' "$HOME/.local/share/hostwarden"; then
  bad "the file store holds the password in clear"
else
  ok
fi
lib 'pw_local_has file ssh alice@192.0.2.2:22' &&
  bad "the file store has a target it never stored" || ok
# A password whose key is gone is not held for a login, but remove
# still finds the file to delete.
mv "$KEYF" "$KEYF.away"
lib 'pw_local_has file ssh alice@192.0.2.1:22' &&
  bad "a password without its key was reported as available" || ok
lib 'pw_local_probe file ssh alice@192.0.2.1:22'
[ $? -eq 0 ] && ok || bad "remove would not find a file whose key is gone"
mv "$KEYF.away" "$KEYF"

# --- only where no key logs in ---------------------------------------
# An ssh that ignores SSH_ASKPASS_REQUIRE would send an empty password.
touch "$TMP/ssh-old"
out=$(FAKE_SSH_OLD=$TMP/ssh-old sh "$PWD_CMD" check alice@rtr1 2>&1)
has "$out" "older than OpenSSH 8.4" "check went on with an ssh before 8.4"
rm -f "$TMP/ssh-old"
out=$(sh "$PWD_CMD" check alice@rtr2 2>&1)
has "$out" "offers key logins" "check did not refuse a host that takes keys"
out=$(sh "$PWD_CMD" link alice@rtr2 '1password op://V/other/password' 2>&1)
has "$out" "offers key logins" "link took a host that takes keys"
grep -q 'rtr2' "$OPS/memory/user.md" && bad "a key host got a source line" || ok
out=$(sh "$PWD_CMD" set alice@rtr2 </dev/null 2>&1)
has "$out" "offers key logins" "set took a host that takes keys"
out=$(sh "$PWD_CMD" check alice@rtr3 2>&1)
has "$out" "named no login methods" "a jump host's refusal was read as the target's"
out=$(sh "$PWD_CMD" check alice@rtr4 2>&1)
has "$out" "offers no password login" "a host without a password method passed"
# rtr1's answer, which every helper test below needs.
sh "$PWD_CMD" check alice@rtr1 >/dev/null 2>&1
METHODS=$(find "$HOME/.cache/hostwarden" -name 'methods-*' -type f -exec \
  grep -l keyboard-interactive {} + | head -n 1)
[ -n "$METHODS" ] && ok || bad "check recorded no answer for rtr1"

