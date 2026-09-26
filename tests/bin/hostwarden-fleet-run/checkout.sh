# tests/bin/hostwarden-fleet-run/checkout.sh — the throwaway
# operations checkout and its fixture memory. Sourced by
# tests/bin/hostwarden-fleet-run.sh, in the order its PARTS lists,
# into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the checkout -----------------------------------------------
R="$TMP/repo"
H="$R/.agents/skills/hostwarden-housekeeping/references"
mkdir -p "$R/bin" "$R/lib" "$R/.claude/hooks" "$H"
cp "$REPO/bin/hostwarden-fleet-run" "$REPO/bin/hostwarden-sync" \
  "$REPO/bin/hostwarden-ssh-config" "$R/bin/"
cp "$REPO/lib/mode.sh" "$REPO/lib/hops.sh" "$REPO/lib/resolve.sh" \
  "$R/lib/"
cp -R "$REPO/lib/hostwarden-fleet-run" "$R/lib/"
printf 'Report format marker\n' >"$H/report-format.md"
printf 'Baseline marker: CRITICAL if any filesystem > 95%%\n' \
  >"$H/baseline-linux.md"
printf 'memory/\n' >"$R/.gitignore"
git -C "$R" init --quiet
git -C "$R" add -A && git -C "$R" commit --quiet -m init

M="$R/memory"
FR="$M/fleet/fleet-read"
mkdir -p "$FR/src" "$FR/files/etc/fleet-read"
git -C "$M" init --quiet
: >"$M/.hostwarden-workspace"
cp "$REPO/templates/workspace/.gitignore" "$M/.gitignore"
mkdir -p "$M/decisions"
cat >"$M/user.md" <<EOF
# Preferences
# Operator name: Your Full Name
Operator: ops1
Fleet key: $TMP/fleet-key
Workspace push: always
EOF
: >"$TMP/fleet-key"
printf -- '- %s\n' bad1.example.com jumped2.example.com-hop.example.com \
  2001:db8::66 alias2-old >"$M/blacklist.md"

ssh-keygen -q -t ed25519 -N '' -C signer -f "$TMP/signer"
printf 'fleet-read namespaces="fleet-read" %s\n' "$(cat "$TMP/signer.pub")" \
  >"$FR/files/etc/fleet-read/allowed_signers"
cat >"$FR/src/linux.sh" <<'EOF'
#!/bin/sh
# fleet-read bundle: linux
# valid-until: 2999-12-31
# sources: baseline-linux.md
echo placeholder
EOF
sign() {
  rm -f "$1.sig"
  ssh-keygen -q -Y sign -f "$TMP/signer" -n fleet-read "$1" >/dev/null 2>&1
}
sign "$FR/src/linux.sh"

server() {
  mkdir -p "$M/machines/$1"
  printf '# %s\n\n- Fleet read: ops1 (bundle linux, %s, 2026-09-23)\n%s\n' \
    "$1" "$2" "$3" >"$M/machines/$1/memory.md"
}
server web1.example.com 'key line present' \
'- Firewall: none on this host. The provider filters every packet in
  front of it, confirmed by alice.'
server down1.example.com 'key line present' ''
server db1.example.com 'waiting for the key line' ''
server part1.example.com 'key line present' ''
server nojudge1.example.com 'key line present' ''
server jumped1.example.com 'key line present' ''
server jumped2.example.com 'key line present' ''
server jumped3.example.com 'key line present' ''
server jumped4.example.com 'key line present' ''
server jumped5.example.com 'key line present' ''
server jumped6.example.com 'key line present' ''
server jumped7.example.com 'key line present' ''
server jumped8.example.com 'key line present' ''
server jumped9.example.com 'key line present' ''
server script1.example.com 'key line present' ''
server script2.example.com 'key line present' ''
server script3.example.com 'key line present' ''
server jumped10.example.com 'key line present' ''
server port1.example.com 'key line present' '- SSH port: 2222'
server dec1.example.com 'key line present' ''
server dec2.example.com 'key line present' ''
printf '%s\n' '# Decisions — dec1' 'Applies to: hosts dec1.example.com' '' \
  '## No local firewall' '- Decided: alice, 2026-09-18' \
  '- Why: The provider filters every packet in front of it.' \
  '- Settles: baseline → Firewall' '- Revisit: 2026-01-01' \
  >"$M/decisions/dec1.md"
sed -i.bak '2s/.*/Applies to: hosts dec1.example.com, dec2.example.com/' \
  "$M/decisions/dec1.md" && rm -f "$M/decisions/dec1.md.bak"
ln -s web1.example.com "$M/machines/alias1.example.com"
# Blacklisted by a DNS alias that resolves nowhere.
server alias2.example.com 'key line present' ''
ln -s alias2.example.com "$M/machines/alias2-old"
server two1.example.com 'key line present' \
'- Firewall: none on this host. The provider filters every packet in
  front of it, confirmed by alice.'
server bad1.example.com 'key line present' ''
server unreachable1.example.com 'key line present' ''
server partial1.example.com 'key line present' ''
server routed1.corp.example.net 'key line present' ''
printf -- '- alice\n- ops1 (operations host)\n' >"$M/operators.md"
git -C "$M" add -A && git -C "$M" commit --quiet -m init
git init --bare --quiet "$TMP/remote.git"
git -C "$M" remote add origin "$TMP/remote.git"
git -C "$M" push --quiet -u origin HEAD
sh "$R/bin/hostwarden-ssh-config" || { echo "FAIL: no ssh_config"; exit 1; }
