# tests/bin/hostwarden-password/askpass.sh — hostwarden-askpass and the password managers. Sourced by
# tests/bin/hostwarden-password.sh, in its order, into the one shell
# every part shares; never run on its own.
# shellcheck shell=sh

# --- hostwarden-askpass -------------------------------------------
out=$("$AP" "alice@192.0.2.1's password: " 2>&1)
lacks "$out" "p w!" "run directly, the helper printed the password"
has "$out" "answers ssh only" "run directly, the helper did not refuse"

out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
has "$out" "p w!" "the helper did not answer a password prompt"
has "$out" "rc=0" "the helper did not answer a password prompt"
out=$(ask "(alice@192.0.2.1) Password:" $F alice@rtr1 'grep -i include x | awk -F: 1')
has "$out" "rc=0" "the helper refused keyboard-interactive, or a remote command"
for pr in "Enter passphrase for key '/home/alice/.ssh/id_ed25519': " \
  "Are you sure you want to continue connecting (yes/no)? " \
  "(alice@192.0.2.1) Verification code:" "(alice@192.0.2.1) New password:"; do
  out=$(ask "$pr" $F alice@rtr1)
  lacks "$out" "p w!" "the helper answered: $pr"
done
out=$(ask "alice@192.0.2.1's password: " alice@rtr1)
lacks "$out" "p w!" "the helper answered an ssh without memory/ssh_config"
for o in "-o StrictHostKeyChecking=no" "-oUserKnownHostsFile=/dev/null" \
  "-o ProxyCommand=nc" "-o KnownHostsCommand=/bin/true"; do
  out=$(ask "alice@192.0.2.1's password: " $F $o alice@rtr1)
  lacks "$out" "p w!" "the helper answered with $o"
done

# A host or user name that holds a word of the refused prompts is
# still a password prompt, and so is one without a colon.
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
out=$(ask "admin@encoder1.example.com's password: " $F alice@rtr1)
has "$out" "p w!" "a host named encoder1 read as a one-time code"
out=$(ask "(otp-admin@192.0.2.1) Enter password" $F alice@rtr1)
has "$out" "p w!" "a keyboard-interactive prompt without a colon, or a user named otp-"
# A refusal ends the ssh process: the stand-in never prints rc=.
out=$(ask "Enter passphrase for key 'k': " $F alice@rtr1)
lacks "$out" "rc=" "a refusal left the ssh process running"
# -F through a symbolic link to the checkout counts.
ln -s "$OPS" "$TMP/link"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
out=$(ask "alice@192.0.2.1's password: " -F "$TMP/link/memory/ssh_config" alice@rtr1)
has "$out" "p w!" "-F through a link to the checkout was refused"
# ...and one whose path holds a space.
ln -s "$OPS" "$TMP/li nk"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
out=$(ask "alice@192.0.2.1's password: " -F "$TMP/li nk/memory/ssh_config" alice@rtr1)
has "$out" "p w!" "-F with a space in the checkout's path was refused"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*

# No answer, or one that names publickey: no password.
mv "$METHODS" "$METHODS.keep"
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
lacks "$out" "p w!" "the helper answered without knowing the host takes no key"
has "$out" "bin/hostwarden-password check" "the refusal did not name check"
echo publickey,password > "$METHODS"
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
lacks "$out" "p w!" "the helper answered a host that offers keys"
mv "$METHODS.keep" "$METHODS"
# A refusal before the password is read does not count: three of
# them leave the next login its answer.
mv "$KEYF" "$KEYF.keep"
for _ in 1 2 3; do ask "alice@192.0.2.1's password: " $F alice@rtr1 >/dev/null; done
mv "$KEYF.keep" "$KEYF"
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
has "$out" "p w!" "refusals counted toward the three"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*

# The cleanup takes old notes, never an answer about login methods.
OLDM=${METHODS%/*}/methods-0
: > "$OLDM"
touch -t 200001010000 "$OLDM"
ask "alice@192.0.2.1's password: " $F alice@rtr1 >/dev/null
[ -f "$OLDM" ] && ok || bad "the cleanup removed an answer about login methods"
rm -f "$OLDM" "$HOME"/.cache/hostwarden/*/askpass/count-*

# A note whose start time is not the process's is stale.
PIDNOTE=$("$SSHSH" -c 'echo $$; "$1" --note rtr1 alice 192.0.2.1 22
  sleep 0' ssh "$AP")
NOTEF=$(find "$HOME/.cache/hostwarden" -name "$PIDNOTE" -type f | head -1)
[ -n "$NOTEF" ] && ok || bad "the note was not written"
[ "$(sed -n 2,5p "$NOTEF" | tr '\n' ' ')" = "rtr1 alice 192.0.2.1 22 " ] &&
  ok || bad "the note holds: $(cat "$NOTEF")"

# Three answers a quarter hour, per target: the tests above gave
# two. Clear the count and give three, then the fourth is refused.
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
for _ in 1 2 3; do ask "alice@192.0.2.1's password: " $F alice@rtr1 >/dev/null; done
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
lacks "$out" "p w!" "the helper answered a fourth time"
has "$out" "15 minutes" "the fourth refusal did not say why"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*

# Password managers: only an entry that names the target.
askm() {
  lib "pw_record alice@rtr1 '$1'"
  rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
  ask "alice@192.0.2.1's password: " $F alice@rtr1
}
# 1Password only through a service account's token.
out=$(askm '1password op://V/rtr1/password')
lacks "$out" "op-secret" "1Password: a password without a service account token"
has "$out" "service account" "1Password: the missing token was not named"
lib 'printf %s tok-1p | pw_local_put file token 1password'
out=$(askm '1password op://V/rtr1/password')
has "$out" "op-secret" "1Password: a bound entry gave nothing"
out=$(askm '1password op://V/bank/password')
lacks "$out" "bank-secret" "1Password: an entry without the field gave its password"
out=$(askm '1password op://V/other/password')
lacks "$out" "other-secret" "1Password: an entry for another target gave its password"
# ...and every login rechecks that the token still sees one vault.
printf '%s' '[{"id":"v1","name":"V"},{"id":"v2","name":"Private"}]' \
  > "$TMP/op-vaults"
out=$(askm '1password op://V/rtr1/password')
lacks "$out" "op-secret" "1Password: a token that now sees two vaults gave a password"
has "$out" "no longer goes through" "1Password: the widened scope was not named"
printf '%s' '[{"id":"v1","name":"V"}]' > "$TMP/op-vaults"
askm '1password op://V/rtr1/password' >/dev/null
[ "$(cat "$TMP/op-token")" = tok-1p ] && ok ||
  bad "1Password: the stored token did not reach op's environment"
: > "$TMP/rbw-locked"
out=$(askm 'rbw hw/Router')
lacks "$out" "rbw-secret" "rbw: a locked vault gave a password"
has "$out" "rbw unlock" "rbw: a locked vault was not named"
rm -f "$TMP/rbw-locked"
out=$(askm 'rbw hw/Router')
has "$out" "rbw-secret" "rbw: a bound entry gave nothing"
out=$(askm 'rbw mine/Router')
lacks "$out" "rbw-secret" "rbw: a profile other than the one named answered"
if command -v jq >/dev/null 2>&1; then
  out=$(askm 'bws 11111111-1111-1111-1111-111111111111')
  lacks "$out" "bws-secret" "bws: a password without a stored token"
  lib 'printf %s tok-bws | pw_local_put file token bws'
  out=$(askm 'bws 11111111-1111-1111-1111-111111111111')
  has "$out" "bws-secret" "bws: a bound secret gave nothing"
  out=$(askm 'bws 22222222-2222-2222-2222-222222222222')
  lacks "$out" "rc=0" "bws: a secret named otherwise was answered"
  out=$(askm 'bws 33333333-3333-3333-3333-333333333333')
  lacks "$out" "rc=0" "bws: a failed read was answered, empty"
else
  bad "jq is missing, which the bws cases need"
fi
lib 'pw_unrecord alice@rtr1'

# Logins at once cannot pass the third answer together: six at the
# same moment for one target get three passwords.
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*
for i in 1 2 3 4 5 6; do
  ask "alice@192.0.2.1's password: " $F alice@rtr1 > "$TMP/par.$i" &
done
wait
GOT=$(cat "$TMP"/par.* | grep -c 'p w!')
[ "$GOT" -eq 3 ] && ok || bad "six logins at once got $GOT passwords, not 3"
rm -f "$TMP"/par.* "$HOME"/.cache/hostwarden/*/askpass/count-*
# A login that ends without a password cancels its line: three
# refusals before the password was read cost nothing (further up),
# and a killed one keeps its line, counted as given.
CNT=$(ls -d "$HOME"/.cache/hostwarden/*/askpass 2>/dev/null | head -n 1)
CF=$(printf %s 'alice@192.0.2.1:22' | cksum | cut -d' ' -f1)
printf 'R %s dead-1\nR %s dead-2\nR %s dead-3\n' "$(date +%s)" "$(date +%s)" \
  "$(date +%s)" > "$CNT/count-$CF"
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
lacks "$out" "p w!" "three live reservations left a fourth login through"
printf 'R %s dead-1\nR %s dead-2\nR %s dead-3\nC dead-2\n' "$(date +%s)" \
  "$(date +%s)" "$(date +%s)" > "$CNT/count-$CF"
out=$(ask "alice@192.0.2.1's password: " $F alice@rtr1)
has "$out" "p w!" "a cancelled reservation did not free its place"
rm -f "$HOME"/.cache/hostwarden/*/askpass/count-*

# The limit ends the CLI itself, not only the shell around it.
T0=$(date +%s)
lib 'pw_limit 2 pw_op read op://V/slow/hostwarden' >/dev/null 2>&1
[ $(($(date +%s) - T0)) -lt 20 ] && ok || bad "pw_limit left op running"

# A source line the Markdown wrap broke is read back whole, and
# replaced whole.
printf '%s\n' '# SSH Passwords' '' \
  '- alice@rtr1: 1password' '  op://V/rtr1/password' '- bob@rtr1: local' \
  > "$OPS/memory/user.md"
[ "$(lib 'pw_source alice rtr1')" = "1password op://V/rtr1/password" ] && ok ||
  bad "a wrapped source line was read in part: $(lib 'pw_source alice rtr1')"
lib 'pw_record alice@rtr1 "local file"'
grep -q 'op://' "$OPS/memory/user.md" && bad "pw_record left the wrapped rest" || ok
grep -qx -- '- bob@rtr1: local' "$OPS/memory/user.md" && ok ||
  bad "pw_record took the next login with it"
printf '# SSH Users\n\nDefault: alice\n' > "$OPS/memory/user.md"

# A login whose host name holds colons keeps its line: an IPv6 address.
lib 'pw_record alice@2001:db8::1 "local file"'
[ "$(lib 'pw_source alice 2001:db8::1')" = "local file" ] && ok ||
  bad "the source of an IPv6 login was not found"
lib 'pw_record alice@2001:db8::1 "local keychain"'
[ "$(grep -c '^- alice@2001:db8::1:' "$OPS/memory/user.md")" -eq 1 ] && ok ||
  bad "an IPv6 login's line was not replaced"
lib 'pw_unrecord alice@2001:db8::1'
grep -q '2001:db8' "$OPS/memory/user.md" && bad "an IPv6 login's line was kept" || ok
printf '# SSH Users\n\nDefault: alice\n' > "$OPS/memory/user.md"

