#!/bin/sh
# impact-test.sh — dev-only fixture matrix for bin/hostwarden-impact,
# the blast radius of a disruptive step. CI runs it through
# scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# Everything runs in a throwaway operations checkout under a temp
# directory with a fixture memory, and a stand-in for ssh that
# answers only -G, from one file per destination, and records every
# call.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-impact-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
has() { grep -qxF -- "$2" "$1" && ok || bad "$3"; }
lacks() { grep -qF -- "$2" "$1" && bad "$3" || ok; }
same() {
  if [ "$(cat "$1")" = "$2" ]; then ok; else
    bad "$3"; echo "--- expected"; echo "$2"; echo "--- got"; cat "$1"
  fi
}

export HOME="$TMP/home"
mkdir -p "$HOME"

# --- the checkout -----------------------------------------------
R="$TMP/repo"
mkdir -p "$R/bin" "$R/.claude/hooks"
cp "$REPO/bin/hostwarden-impact" "$REPO/bin/hostwarden-ssh-config" "$R/bin/"
cp "$REPO/.claude/hooks/mode.sh" "$REPO/.claude/hooks/hops.sh" \
  "$REPO/.claude/hooks/coord-lib.sh" "$REPO/.claude/hooks/resolve.sh" \
  "$R/.claude/hooks/"
git -C "$R" init --quiet
M="$R/memory"
mkdir -p "$M/servers" "$M/clusters/prod"
: >"$M/.hostwarden-workspace"
: >"$M/ssh_config"
cat >"$M/user.md" <<'EOF'
# SSH Users
Default: alice
- app1.example.com: deploy
EOF

# server <name> <lines> — a memory.md with the lines given.
server() {
  mkdir -p "$M/servers/$1"
  printf '# %s\n%s\n- Last connected: 2026-09-20\n' "$1" "$2" \
    >"$M/servers/$1/memory.md"
}
server pve1.example.com '- IP: 192.0.2.1
- Role: hypervisor
- Cluster: prod'
server pve2.example.com '- IP: 192.0.2.2
- Cluster: prod'
cat >"$M/clusters/prod/cluster.md" <<'EOF'
# Cluster prod (Proxmox VE)

- Members: pve1 → pve1.example.com, pve2 → pve2.example.com,
  pve3 → pve3.example.com, pve4 (no memory)
EOF
cat >"$M/servers/pve1.example.com/guests.md" <<'EOF'
# Guests on pve1.example.com

- Inventoried: 2026-01-02

- 101 web1 (VM): running, autostart. 192.0.2.21.
  → web1.example.com
- 110 mail-old (VM): stopped. Retired.
EOF
server web1.example.com '- IP: 192.0.2.21
- Role: web server
- Web server: nginx
- Runs on: pve1.example.com (VM 101)'
ln -s web1.example.com "$M/servers/web1"
server db1.example.com '- Runs on: cluster prod (VM 102), last on
  pve2.example.com'
server ct1.example.com '- Mode: via
- Runs on: pve1.example.com (container 105)'
server ct2.example.com '- Mode: via
- Runs on: pve1.example.com (container 107)'
server reg1.example.com '- Runs on: pve1.example.com (container 106)
- SSH: untested (registered through pve1.example.com)'
server nested1.example.com '- Runs on: web1.example.com (container app)'
server app1.example.com '- Role: app'
server app2.example.com ''
server app3.example.com '- Depends on: db1.example.com (DB postgres),
  nas1.example.com (NFS /srv/data)'
server app4.example.com '- Depends on: pve1.example.com (resolver)'
server app5.example.com '- Depends on: 192.0.2.1 (other backup target)'
server app6.example.com ''
server app7.example.com ''
server lone.example.com ''
server odd1.example.com ''
server pc1.example.com ''
# Reached as: an SSH alias, which ssh -G resolves.
server pc1-wsl-debian '- Reached as: pc1
- SSH port: 2222'

# --- the ssh stand-in -------------------------------------------
# One file per destination under $G, or per user@destination, which
# wins: what `ssh -G` prints beyond user and port. A file holding
# FAIL makes the call fail.
G="$TMP/sshg"
mkdir -p "$G" "$TMP/bin"
printf 'proxyjump web1.example.com\n' >"$G/deploy@app1.example.com"
printf 'proxyjump jump\n' >"$G/app2.example.com"
printf 'hostname 192.0.2.1\n' >"$G/jump"
printf 'proxyjump bastion2\n' >"$G/app6.example.com"
printf 'proxyjump bastion2:2222\n' >"$G/app7.example.com"
printf 'hostname bastion2.example.net\n' >"$G/bastion2"
printf 'proxycommand /usr/local/bin/tunnel %%h\n' >"$G/odd1.example.com"
printf 'hostname pc1.example.com\n' >"$G/pc1"
cat >"$TMP/bin/ssh" <<EOF
#!/bin/sh
echo "\$*" >>"$TMP/ssh.log"
u='' p='' g=''
while [ \$# -gt 0 ]; do
  case \$1 in
    -G) g=1 ;;
    -F|-o) shift ;;
    -l) u=\$2; shift ;;
    -p) p=\$2; shift ;;
    -*) ;;
    *) d=\$1 ;;
  esac
  shift
done
[ -n "\$g" ] || exit 255
# As ssh -v does: the configuration files it reads.
[ -f "$TMP/dot/extra" ] && echo "debug1: Reading configuration data $TMP/dot/extra" >&2
f="$G/\$u@\$d"; [ -f "\$f" ] || f="$G/\$d"
[ -f "\$f" ] && grep -qx FAIL "\$f" && exit 255
echo "user \${u:-alice}"
echo "port \${p:-22}"
[ -f "\$f" ] && cat "\$f"
[ -f "\$f" ] && grep -q '^hostname ' "\$f" || echo "hostname \$d"
exit 0
EOF
chmod +x "$TMP/bin/ssh"
export PATH="$TMP/bin:$PATH"

run() { sh "$R/bin/hostwarden-impact" "$@"; }

# --- usage ------------------------------------------------------
# exits <status> <why> <args…> — the run ends with that status.
exits() {
  want=$1 why=$2
  shift 2
  run "$@" >/dev/null 2>&1
  [ $? -eq "$want" ] && ok || bad "$why"
}
exits 2 "no subcommand is not usage"
exits 2 "a radius without a kind is not usage" radius pve1.example.com
exits 2 "a radius without a host is not usage" radius reboot
exits 2 "restart without a unit is not usage" radius pve1.example.com restart
exits 2 "a name with a ; is not refused" radius 'a;b' reboot
exits 2 "--jumps without a host is not usage" radius --jumps
run --help | grep -q '^Usage:' && ok || bad "--help prints no usage"

# --- a reboot: out, hit, unreadable -----------------------------
run radius pve1.example.com reboot >"$TMP/out" 2>"$TMP/err"
same "$TMP/out" 'pve1.example.com origin -
app1.example.com behind web1.example.com web1.example.com
app2.example.com behind pve1.example.com 192.0.2.1
app3.example.com depends db1.example.com DB postgres
app4.example.com depends pve1.example.com resolver
app5.example.com depends pve1.example.com other backup target
ct1.example.com via pve1.example.com container 105
ct2.example.com via pve1.example.com container 107
db1.example.com guest pve1.example.com VM 102
nested1.example.com guest web1.example.com container app
pve2.example.com cluster pve1.example.com prod
pve3.example.com cluster pve1.example.com prod
pve4 cluster pve1.example.com prod
reg1.example.com guest pve1.example.com container 106
web1.example.com guest pve1.example.com VM 101
odd1.example.com unreadable -' "reboot of pve1"
[ -s "$TMP/err" ] && bad "reboot of pve1 wrote to stderr: $(cat "$TMP/err")" || ok
[ -f "$HOME/.cache/hostwarden/ws-$(printf %s "$R" | cksum | cut -d' ' -f1)/radius.idx" ] \
  && ok || bad "no index under the checkout's cache directory"

# The index is read, not rebuilt, while nothing changed; a changed
# memory.md, and a new alias, rebuild it.
calls=$(wc -l <"$TMP/ssh.log")
run radius pve1.example.com network >"$TMP/out2"
[ "$(wc -l <"$TMP/ssh.log")" -eq "$calls" ] && ok || bad "an unchanged index was rebuilt"
sed 1d "$TMP/out" >"$TMP/a"; sed 1d "$TMP/out2" >"$TMP/b"
cmp -s "$TMP/a" "$TMP/b" && ok || bad "network and reboot differ"
sleep 1
printf -- '- Depends on: web1.example.com (SMB /srv/share)\n' \
  >>"$M/servers/lone.example.com/memory.md"
run radius pve1.example.com reboot >"$TMP/out"
[ "$(wc -l <"$TMP/ssh.log")" -gt "$calls" ] && ok || bad "a changed memory.md did not rebuild"
has "$TMP/out" 'lone.example.com depends web1.example.com SMB /srv/share' \
  "a dependent of a guest is not hit"
# A file the SSH configuration includes rebuilds it too.
sleep 1
calls=$(wc -l <"$TMP/ssh.log")
mkdir -p "$HOME/.ssh/conf.d"
: >"$HOME/.ssh/conf.d/extra"
run radius pve1.example.com reboot >/dev/null
[ "$(wc -l <"$TMP/ssh.log")" -gt "$calls" ] && ok \
  || bad "a changed included SSH configuration did not rebuild"
# So does one it includes from anywhere else, once ssh has named it.
mkdir -p "$TMP/dot"
: >"$TMP/dot/extra"
sleep 1
: >"$HOME/.ssh/conf.d/extra"
run radius pve1.example.com reboot >/dev/null
[ -s "$HOME/.cache/hostwarden/ws-$(printf %s "$R" | cksum | cut -d' ' -f1)/radius-sources" ] \
  && ok || bad "the configuration files read are not kept"
sleep 1
calls=$(wc -l <"$TMP/ssh.log")
echo '# changed' >"$TMP/dot/extra"
run radius pve1.example.com reboot >/dev/null
[ "$(wc -l <"$TMP/ssh.log")" -gt "$calls" ] && ok \
  || bad "a changed Include target outside ~/.ssh did not rebuild"
# A file the index was read from, removed, rebuilds it.
for f in "$M/servers/reg1.example.com/memory.md" "$TMP/dot/extra" "$M/user.md"; do
  sleep 1
  cp "$f" "$TMP/keep"
  calls=$(wc -l <"$TMP/ssh.log")
  rm "$f"
  run radius pve1.example.com reboot >/dev/null 2>&1
  [ "$(wc -l <"$TMP/ssh.log")" -gt "$calls" ] && ok \
    || bad "removing ${f#"$TMP"/} did not rebuild"
  cp "$TMP/keep" "$f"
done
sleep 1
ln -s pve1.example.com "$M/servers/pve1"
run radius pve1 reboot >"$TMP/out"
head -n 1 "$TMP/out" >"$TMP/a"
same "$TMP/a" 'pve1.example.com origin -' "a new alias did not rebuild the index"

# --- restarts ---------------------------------------------------
run radius pve1.example.com restart:unbound >"$TMP/out"
same "$TMP/out" 'pve1.example.com origin -
app4.example.com depends pve1.example.com resolver
app5.example.com depends pve1.example.com other backup target' "restart of a resolver"
run radius pve1.example.com restart:postgresql.service >"$TMP/out"
same "$TMP/out" 'pve1.example.com origin -
app5.example.com depends pve1.example.com other backup target' "restart of a database"
run radius pve1.example.com restart:frobd >"$TMP/out"
same "$TMP/out" 'pve1.example.com origin -
app4.example.com depends pve1.example.com resolver
app5.example.com depends pve1.example.com other backup target' "restart of an unknown unit"
run radius pve1.example.com reboot >"$TMP/a"
for u in tailscaled wg-quick@wg0 ssh.socket com.openssh.sshd nftables \
  NetworkManager; do
  run radius pve1.example.com "restart:$u" >"$TMP/b"
  cmp -s "$TMP/a" "$TMP/b" && ok || bad "restart:$u does not take the whole radius"
done

# --- names --------------------------------------------------------
run radius web1 reboot >"$TMP/out"
same "$TMP/out" 'web1.example.com origin -
app1.example.com behind web1.example.com web1.example.com
lone.example.com depends web1.example.com SMB /srv/share
nested1.example.com guest web1.example.com container app
odd1.example.com unreadable -' "an alias as the origin"
run radius 192.0.2.21 reboot >"$TMP/b"
cmp -s "$TMP/out" "$TMP/b" && ok || bad "an IP of one host is not that host"
run radius pc1.example.com reboot >"$TMP/out"
same "$TMP/out" 'pc1.example.com origin -
pc1-wsl-debian reached pc1.example.com pc1.example.com
odd1.example.com unreadable -' "a Reached as: destination"
run radius bastion2 network >"$TMP/out" 2>"$TMP/err"
same "$TMP/out" 'bastion2 origin -
app6.example.com behind bastion2 bastion2
app7.example.com behind bastion2 bastion2
odd1.example.com unreadable -' "a jump host without memory"
grep -q 'bastion2 has no memory' "$TMP/err" && ok || bad "no note on an origin without memory"
run radius pve1.example.com pve2.example.com reboot >"$TMP/out"
head -n 2 "$TMP/out" >"$TMP/a"
same "$TMP/a" 'pve1.example.com origin -
pve2.example.com origin -' "two origins"
lacks "$TMP/out" 'pve2.example.com cluster' "an origin is also listed as a peer"

# --- the report -------------------------------------------------
run radius --report pve1.example.com reboot >"$TMP/out"
has "$TMP/out" 'What reboot of pve1.example.com would reach: 16 hosts besides it' \
  "report: headline"
has "$TMP/out" 'Guests, out with it:' "report: guests heading"
has "$TMP/out" '  web1.example.com — on pve1.example.com (VM 101)' "report: a guest"
has "$TMP/out" '      Role: web server; Web server: nginx' "report: service lines"
has "$TMP/out" '  app4.example.com — resolver, on pve1.example.com' "report: a dependent"
has "$TMP/out" '  pve3.example.com — cluster prod, with pve1.example.com' "report: a peer"
has "$TMP/out" 'Guests of pve1.example.com with no memory of their own: 110 mail-old (VM)' \
  "report: guests without memory"
has "$TMP/out" 'Only registered, never onboarded: reg1.example.com; onboarding it records what depends on it' \
  "report: a registered host"
has "$TMP/out" 'Oldest record relied on: 2026-01-02, the guest inventory of pve1.example.com; the next connection to it refreshes it' \
  "report: the oldest record"
has "$TMP/out" 'No Last connected: in memory: pve3.example.com pve4' "report: a host with no date"

# --- jump groups --------------------------------------------------
run radius --jumps app1.example.com web1 app6.example.com app7.example.com \
  ct1.example.com ct2.example.com odd1.example.com lone.example.com \
  web1.example.com >"$TMP/out"
same "$TMP/out" 'group app1.example.com web1
group app6.example.com app7.example.com
group ct1.example.com ct2.example.com
group lone.example.com
unreadable odd1.example.com' "jump groups"
run radius --jumps pc1-wsl-debian pc1.example.com >"$TMP/out"
same "$TMP/out" 'group pc1-wsl-debian pc1.example.com' \
  "a Reached as: destination and its host in one group"
# An alias with its own SSH user takes its own way in too.
ln -s app2.example.com "$M/servers/app2"
printf -- '- app2: deploy\n' >>"$M/user.md"
printf 'proxyjump bastion2\n' >"$G/deploy@app2"
run radius --jumps app2 app6.example.com >"$TMP/out"
same "$TMP/out" 'group app2 app6.example.com' "an alias with its own user"
run radius bastion2 network >"$TMP/out" 2>/dev/null
has "$TMP/out" 'app2.example.com behind bastion2 bastion2' \
  "the radius misses the way in of an alias with its own user"

# --- only in an operations checkout -----------------------------
rm "$M/.hostwarden-workspace"
exits 1 "runs outside an operations checkout" radius pve1.example.com reboot

echo "impact: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
