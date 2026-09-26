# tests/hooks/guard-mode/init.sh — bin/hostwarden-init, bin/ and
# bin/hostwarden-ssh-config. Sourced by tests/hooks/guard-mode.sh,
# in the order its PARTS lists, into the one shell every part
# shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- bin/hostwarden-init ---------------------------------------
[ -d "$OPS/memory/.git" ] && ok || bad "init made no repository in memory/"
[ -f "$OPS/memory/.hostwarden-workspace" ] && ok || bad "init wrote no marker"
if [ -z "$(git -C "$OPS" status --porcelain)" ]; then ok
else bad "the workspace shows up in the outer repository"; fi
# What a team shares is not ignored, what stays personal is.
mkdir -p "$OPS/memory/machines/server1.example.com"
for f in machines/server1.example.com/memory.md \
    machines/server1.example.com/changelog.log network.md \
    custom-rules/all.md service-policy.md .hostwarden-workspace; do
  if git -C "$OPS/memory" check-ignore -q --no-index -- "$f"; then
    bad "the workspace ignores $f, which a team shares"
  else ok; fi
done
for f in user.md blacklist.md readonly.md opencode.json \
    machines/localhost/memory.md machines/.link-probe.x; do
  if git -C "$OPS/memory" check-ignore -q --no-index -- "$f"; then ok
  else bad "the workspace would share $f, which is personal"; fi
done
# Idempotent, and a repair: a second run fills in what is gone.
rm "$OPS/memory/.gitignore"
sh "$OPS/bin/hostwarden-init" >/dev/null 2>&1 && ok || bad "second init failed"
[ -f "$OPS/memory/.gitignore" ] && ok || bad "second init did not repair .gitignore"
# A hook of the user's own, or a core.hooksPath elsewhere, would
# leave the secret scan out: init refuses before it marks
# anything as a workspace.
H=$(checkout hooks)
git -C "$H" init --quiet memory
printf '#!/bin/sh\nexit 0\n' > "$H/memory/.git/hooks/pre-push"
fails "init ran beside a pre-push hook of the user's own" sh "$H/bin/hostwarden-init"
mode_is development "$H"
rm "$H/memory/.git/hooks/pre-push"
git -C "$H/memory" config core.hooksPath /tmp/elsewhere
fails "init ran with core.hooksPath pointing elsewhere" sh "$H/bin/hostwarden-init"
mode_is development "$H"
# The override the refusal recommends is accepted.
git -C "$H/memory" config core.hooksPath .git/hooks
sh "$H/bin/hostwarden-init" >/dev/null 2>&1 && ok \
  || bad "init refused core.hooksPath set to the workspace's own hooks"
mode_is operations "$H"
# Never in a worktree.
fails "init ran in a linked worktree" sh "$WT/bin/hostwarden-init"
[ -x "$OPS/memory/.git/hooks/pre-commit" ] \
  && [ -x "$OPS/memory/.git/hooks/pre-push" ] && ok \
  || bad "init installed no secret scan in the workspace"

# --- bin/ -------------------------------------------------------
# The rules tell a session to run these by path, not through sh,
# so every one of them has to be committed executable.
git -C "$REPO" ls-files -s -- bin | while read -r m _ _ f; do
  [ "$m" = 100755 ] || echo "$f"
done > "$TMP/modes"
if [ -s "$TMP/modes" ]; then
  bad "committed without the executable bit: $(tr '\n' ' ' < "$TMP/modes")"
else ok; fi

# --- bin/hostwarden-ssh-config ---------------------------------
CFG="$OPS/memory/ssh_config"
gen() { sh "$OPS/bin/hostwarden-ssh-config" 2>/dev/null; }
# init wrote it, for this checkout, and the workspace keeps it to
# this machine.
grep -qF "UserKnownHostsFile \"$OPS/memory/known_hosts\"" "$CFG" \
  && ok || bad "init wrote no memory/ssh_config naming this checkout"
git -C "$OPS/memory" check-ignore -q ssh_config && ok \
  || bad "the workspace would share memory/ssh_config"
# Masters of this checkout's own: its checksum is in ControlPath.
id=$(printf %s "$OPS" | cksum | cut -d' ' -f1)
grep -qxF "  ControlPath ~/.cache/hostwarden/ssh-$id-%C" "$CFG" && ok \
  || bad "memory/ssh_config shares masters with other checkouts"
# memory/known_hosts alone decides: ssh rewrites nothing, and a
# KnownHostsCommand is off wherever this ssh knows the keyword. One
# that does not would reject the line and fail every call.
grep -qxF "  UpdateHostKeys no" "$CFG" && ok \
  || bad "memory/ssh_config lets ssh rewrite memory/known_hosts"
grep -qxF "  VerifyHostKeyDNS no" "$CFG" && ok \
  || bad "memory/ssh_config lets a DNS fingerprint stand in for known_hosts"
if ssh -F /dev/null -G -o KnownHostsCommand=none example.invalid \
    >/dev/null 2>&1; then
  grep -qxF "  KnownHostsCommand none" "$CFG" && ok \
    || bad "memory/ssh_config leaves a KnownHostsCommand on"
elif grep -q KnownHostsCommand "$CFG"; then
  bad "memory/ssh_config names KnownHostsCommand to an ssh that rejects it"
else ok; fi
# A workspace .gitignore older than the file: the clone's exclude
# list keeps it out instead.
cp "$OPS/memory/.gitignore" "$TMP/gi.orig"
grep -v '^/ssh_config$' "$TMP/gi.orig" > "$OPS/memory/.gitignore"
gen && git -C "$OPS/memory" check-ignore -q ssh_config && ok \
  || bad "an older workspace .gitignore left memory/ssh_config shared"
cp "$TMP/gi.orig" "$OPS/memory/.gitignore"
# The five keywords come through, ahead of the standard options.
printf '%s\n' '# web' 'Host web1 web1.example.com' '  HostName 192.0.2.10' \
  '  Port 2222' '  ProxyJump alice@jump.example.com:2200,[2001:db8::1]' \
  '  HostKeyAlias web1.example.com' > "$OPS/memory/ssh_hosts"
if gen && grep -q '^  Port 2222$' "$CFG" \
    && [ "$(grep -n '^Host web1' "$CFG" | cut -d: -f1)" -lt \
         "$(grep -n '^Match all' "$CFG" | cut -d: -f1)" ]; then ok
else bad "memory/ssh_hosts did not reach memory/ssh_config ahead of Match all"; fi
# Anything else fails, and keeps every host block out, the good
# ones too.
for l in '  ProxyCommand nc %h %p' '  User alice' '  Include /tmp/x' \
    '  LocalCommand id' 'Match exec true' '  HostName $(id)' \
    '  HostName -oProxyCommand=x' '  HostName %h.example.com' \
    '  Port 70000' '  Port=22' '  ProxyJump ssh://jump.example.com' \
    '  ProxyJump -oProxyCommand=x' 'Host "web2"'; do
  printf 'Host web1\n  Port 2222\n%s\n' "$l" > "$OPS/memory/ssh_hosts"
  if gen; then bad "memory/ssh_hosts passed with: $l"
  elif grep -q '^Host' "$CFG"; then bad "host blocks kept beside: $l"
  elif ! grep -q '^Match all' "$CFG"; then bad "no standard options beside: $l"
  else ok; fi
done
rm "$OPS/memory/ssh_hosts"
# A link is refused unread, even to a file that would pass.
printf 'Host web1\n  Port 2222\nsecret-line\n' > "$TMP/target"
ln -s "$TMP/target" "$OPS/memory/ssh_hosts"
out=$(sh "$OPS/bin/hostwarden-ssh-config" 2>&1) && bad "a linked memory/ssh_hosts passed"
case "$out" in *secret-line*) bad "a linked memory/ssh_hosts was read: $out" ;; *) ok ;; esac
if grep -q '^Host' "$CFG"; then
  bad "a linked memory/ssh_hosts reached memory/ssh_config"
else ok; fi
rm "$OPS/memory/ssh_hosts"
# A backup leaves it out: it names this checkout's path.
if sh "$OPS/bin/hostwarden-backup" --list | grep -qx memory/ssh_config; then
  bad "the backup carries memory/ssh_config"
else ok; fi
# Outside operations it does nothing; every pull writes it.
sh "$DEV/bin/hostwarden-ssh-config" && [ ! -e "$DEV/memory" ] && ok \
  || bad "ssh-config acted in a development checkout"
rm "$CFG"
sh "$OPS/bin/hostwarden-sync" pull && [ -f "$CFG" ] && ok \
  || bad "sync pull did not write memory/ssh_config"
