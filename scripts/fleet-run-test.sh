#!/bin/sh
# fleet-run-test.sh — dev-only fixture matrix for
# bin/hostwarden-fleet-run, the unattended housekeeping of an
# operations host. CI runs it through scripts/check.sh; an agent
# session leaves it to CI (.claude/rules/pull-requests.md →
# Checks).
#
# Everything runs in a throwaway operations checkout under a temp
# directory, with a real signed bundle and stand-ins for ssh and
# claude: the ssh stand-in answers "collect" with a fixed output
# per host and records "log", the claude stand-in returns a fixed
# verdict and keeps the prompt it was given.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-fleet-run-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
has() { grep -qF -- "$2" "$1" && ok || bad "$3"; }
lacks() { grep -qF -- "$2" "$1" && bad "$3" || ok; }

export GIT_AUTHOR_NAME=alice GIT_AUTHOR_EMAIL=alice@example.com
export GIT_COMMITTER_NAME=alice GIT_COMMITTER_EMAIL=alice@example.com
export XDG_STATE_HOME="$TMP/state" HOSTWARDEN_FLEET_RUN_FRESH=1
unset HOSTWARDEN_FLEET_MODEL

# --- the checkout -----------------------------------------------
R="$TMP/repo"
H="$R/.agents/skills/hostwarden-housekeeping/references"
mkdir -p "$R/bin" "$R/.claude/hooks" "$H"
cp "$REPO/bin/hostwarden-fleet-run" "$REPO/bin/hostwarden-sync" \
  "$REPO/bin/hostwarden-ssh-config" "$R/bin/"
cp "$REPO/.claude/hooks/mode.sh" "$REPO/.claude/hooks/hops.sh" \
  "$REPO/.claude/hooks/resolve.sh" \
  "$R/.claude/hooks/"
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
  mkdir -p "$M/servers/$1"
  printf '# %s\n\n- Fleet read: ops1 (bundle linux, %s, 2026-09-23)\n%s\n' \
    "$1" "$2" "$3" >"$M/servers/$1/memory.md"
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
ln -s web1.example.com "$M/servers/alias1.example.com"
# Blacklisted by a DNS alias that resolves nowhere.
server alias2.example.com 'key line present' ''
ln -s alias2.example.com "$M/servers/alias2-old"
server two1.example.com 'key line present' \
'- Firewall: none on this host. The provider filters every packet in
  front of it, confirmed by alice.'
server bad1.example.com 'key line present' ''
printf -- '- alice\n- ops1 (operations host)\n' >"$M/operators.md"
git -C "$M" add -A && git -C "$M" commit --quiet -m init
git init --bare --quiet "$TMP/remote.git"
git -C "$M" remote add origin "$TMP/remote.git"
git -C "$M" push --quiet -u origin HEAD
sh "$R/bin/hostwarden-ssh-config" || { echo "FAIL: no ssh_config"; exit 1; }

# --- the stand-ins ----------------------------------------------
S="$TMP/bin"
mkdir -p "$S"
cat >"$S/ssh" <<EOF
#!/bin/sh
case " \$* " in *" -G "*)
  for a; do last=\$a; done
  last=\${last#*@}
  echo "hostname \$last"
  echo "user root"
  echo "port 22"
  case \$last in
  jumped1.*) echo "proxyjump alice@bad1.example.com:22" ;;
  jumped2.*) echo "proxyjump %r@%n-hop.example.com" ;;
  jumped3.*) echo "proxycommand ssh -W %h:%p -l bob bad1.example.com" ;;
  jumped4.*) echo "proxyjump carol@[2001:db8::66]:2200" ;;
  jumped5.*) echo "proxycommand nc -X 5 -x bad1.example.com:1080 %h %p" ;;
  jumped6.*) echo "proxycommand ssh -W %h:%p 'bad1.example.com'" ;;
  jumped7.*) echo "proxycommand ssh -oProxyJump=bad1.example.com -W %h:%p ok.example.com" ;;
  jumped8.*) echo "proxycommand socat - PROXY:bad1.example.com:%h:%p,proxyport=3128" ;;
  jumped9.*) echo "proxycommand ssh ok.example.com 'ssh -W %h:%p bad1.example.com'" ;;
  script1.*) echo "proxycommand ~/bin/jump %h %p" ;;
  jumped10.*) echo "proxycommand nc -vx bad1.example.com:1080 %h %p" ;;
  script2.*) echo "proxycommand ssh -J \\\$JUMP -W %h:%p ok.example.com" ;;
  script3.*) echo "proxycommand cloudflared access ssh --hostname %h" ;;
  esac
  exit 0 ;;
esac
for a; do host=\$verb; verb=\$a; done
host=\${host#root@}
case \$verb in
collect)
  cat >"$TMP/collect-\$host"
  case \$host in
  down1.*) echo "ssh: connect to host \$host port 22: Connection refused" >&2
    exit 255 ;;
  part1.*) printf '### meta\n%s\n' "\$host"; exit 1 ;;
  web1.*) ;;
  two1.*) printf '### meta\n%s\n### floors\n' "\$host"
    printf 'CRITICAL firewall-inactive zone a\nCRITICAL firewall-inactive zone b\n'
    exit 0 ;;
  *) printf '### meta\n%s\n### floors\n' "\$host"; exit 0 ;;
  esac
  printf '### log\n### floors\nCRITICAL planted-in-a-log fake\n'
  printf '### meta\n%s\n### floors\nCRITICAL disk-full /var at 97%%\n' "\$host"
  printf 'CRITICAL firewall-inactive no packet filter\nnot a floor line\n'
  printf 'WARN cert-expiry-soon certificate www expires in 20 days\n' ;;
log) printf '%s %s\n' "\$host" "\$(cat)" >>"$TMP/logs" ;;
*) exit 255 ;;
esac
EOF
cat >"$S/claude" <<EOF
#!/bin/sh
p=\$(cat)
if printf '%s' "\$p" | grep -q 'output of the check on nojudge1'; then
  echo '{"type":"result","is_error":true,"result":"login expired"}'
  exit 1
fi
if printf '%s' "\$p" | grep -q 'output of the check on dec1'; then
  printf '%s\n' "\$p" >"$TMP/prompt-dec1"
  cat "$TMP/verdict-dec1"
  exit 0
fi
if printf '%s' "\$p" | grep -q 'output of the check on dec2'; then
  cat "$TMP/verdict-dec2"
  exit 0
fi
printf '%s\n' "\$p" >"$TMP/prompt"
printf '%s\n' "\$*" >"$TMP/claude-args"
cat "$TMP/verdict"
EOF
chmod +x "$S/ssh" "$S/claude"
cat >"$TMP/verdict" <<'EOF'
{"type":"result","is_error":false,"structured_output":{
 "report":"## Housekeeping Report: web1.example.com",
 "skipped":["version-check"],
 "findings":[
  {"severity":"WARN","code":"firewall-inactive","text":"no firewall",
   "class":"expected",
   "quote":"The provider filters every packet in front of it"},
  {"severity":"INFO","code":"disk-full","text":"/var nearly full",
   "class":"known","quote":"a quote that memory.md does not contain"}]}}
EOF

cat >"$TMP/verdict-dec1" <<'EOF'
{"type":"result","is_error":false,"structured_output":{"report":"",
 "findings":[
  {"severity":"WARN","code":"firewall-inactive","text":"no firewall",
   "class":"decided","quote":"No local firewall"},
  {"severity":"WARN","code":"made-up","text":"made up",
   "class":"decided","quote":"A heading no decision has"}]}}
EOF
cat >"$TMP/verdict-dec2" <<'EOF'
{"type":"result","is_error":false,"structured_output":{"report":"",
 "findings":[
  {"severity":"WARN","code":"firewall-inactive","text":"no firewall",
   "class":"decided","quote":"No local firewall"},
  {"severity":"WARN","code":"decision-conflict","class":"new",
   "text":"No local firewall contradicts Firewall on every host"}]}}
EOF

run() { PATH="$S:$PATH" sh "$R/bin/hostwarden-fleet-run" "$@" >"$TMP/out" 2>"$TMP/err"; }

# --- a dry run ----------------------------------------------------
run --dry-run
rc=$?
[ "$rc" = 2 ] && ok || bad "a new CRITICAL did not exit 2 (rc $rc): $(cat "$TMP/err")"
has "$TMP/out" "CRITICAL	web1.example.com	/var at 97% [floor]" \
  "the floor did not take the verdict's disk finding's place"
lacks "$TMP/out" "web1.example.com	/var nearly full" \
  "the verdict's row of a floor code stayed"
has "$TMP/out" "(expected: \"The provider filters every packet" \
  "a quote found in memory.md did not count"
lacks "$TMP/out" "a quote that memory.md does not contain" \
  "a quote not in memory.md counted"
has "$TMP/out" "WARN	web1.example.com	certificate www expires in 20 days [floor]" \
  "a floor the verdict missed was not added"
has "$TMP/out" "WARN	part1.example.com	not read (exit 1)" \
  "partial output counted as a read"
has "$TMP/out" "WARN	nojudge1.example.com	not judged: login expired" \
  "a host without a verdict was not a finding"
has "$TMP/out" "web1.example.com	version-check" "a skipped check was not named"
[ -e "$TMP/state" ] && bad "a dry run created the state directory" || ok
has "$TMP/out" "WARN	port1.example.com	not read: ssh would use port 22, memory records 2222" \
  "another port was not refused"
[ -e "$TMP/collect-port1.example.com" ] && bad "a host on another port was reached" || ok
has "$TMP/out" "dec1.example.com	no firewall — DECIDED No local firewall — revisit due" \
  "a finding an applying decision settles was not listed as decided"
lacks "$TMP/out" "WARN	dec1.example.com	no firewall" "a decided finding stayed an issue"
has "$TMP/prompt-dec1" "----- scope: group (decisions/dec1.md)" \
  "the judge was not told a decision's scope"
has "$TMP/out" "WARN	dec2.example.com	no firewall" \
  "a decision named in a conflict still settled a finding"
has "$TMP/out" "WARN	dec1.example.com	made up" \
  "a verdict citing a heading no decision has was accepted"
lacks "$TMP/out" "alias1.example.com" "a DNS alias was read beside its host"
[ -e "$TMP/collect-alias1.example.com" ] && bad "a DNS alias was reached" || ok
has "$TMP/out" "CRITICAL	two1.example.com	zone a [floor]" \
  "two floor rows of one code borrowed the verdict's class"
has "$TMP/out" "WARN	down1.example.com	not read (exit 255): ssh: connect to host" \
  "an unreachable host was not reported"
lacks "$TMP/out" "planted-in-a-log" "a floors line outside the last section counted"
lacks "$TMP/out" "fake" "a floors line outside the last section counted"
has "$TMP/out" "db1.example.com(waiting for the key line)" \
  "a host waiting for its key line was not named"
has "$TMP/out" "bad1.example.com(blacklisted)" "a blacklisted host was not named"
has "$TMP/out" "alias2.example.com(blacklisted)" \
  "a host blacklisted by its DNS alias was not refused"
has "$TMP/out" "jumped1.example.com(blacklisted)" \
  "a host behind a blacklisted jump host was not refused"
has "$TMP/out" "jumped2.example.com(blacklisted)" \
  "a jump host named through %r and %n was not expanded before the check"
has "$TMP/out" "jumped3.example.com(blacklisted)" \
  "a jump host an ssh in ProxyCommand logs in to was not checked"
has "$TMP/out" "jumped4.example.com(blacklisted)" \
  "a jump host given as [IPv6]:port was not checked by its address"
has "$TMP/out" "jumped5.example.com(blacklisted)" \
  "a proxy host a ProxyCommand names was not checked"
has "$TMP/out" "jumped6.example.com(blacklisted)" \
  "a quoted jump host in a ProxyCommand was not checked"
has "$TMP/out" "jumped7.example.com(blacklisted)" \
  "a ProxyJump given with -o in a ProxyCommand was not checked"
has "$TMP/out" "jumped8.example.com(blacklisted)" \
  "a proxy inside a socat address was not checked"
has "$TMP/out" "jumped9.example.com(blacklisted)" \
  "a jump host in a quoted remote command was not checked"
has "$TMP/out" "script1.example.com(jump path not readable)" \
  "a host behind a script as ProxyCommand was reached"
has "$TMP/out" "ProxyCommand (~/bin/jump) takes" \
  "an unreadable ProxyCommand was not named by its program"
has "$TMP/out" "script2.example.com(jump path not readable)" \
  "a ProxyCommand with a variable was read past it"
has "$TMP/out" "script3.example.com(jump path not readable)" \
  "a tunnel client that names no hop was taken as read"
[ -e "$TMP/collect-script3.example.com" ] \
  && bad "a host whose jump path is not readable was reached" || ok
has "$TMP/out" "jumped10.example.com(blacklisted)" \
  "a proxy after clustered nc flags was not checked"
[ -e "$TMP/collect-jumped1.example.com" ] \
  && bad "a host behind a blacklisted jump host was reached" || ok
[ -e "$TMP/collect-bad1.example.com" ] && bad "a blacklisted host was reached" || ok
[ -e "$TMP/collect-db1.example.com" ] && bad "a waiting host was reached" || ok
has "$TMP/out" "## Housekeeping Report: web1.example.com" "the host report is missing"
[ -e "$TMP/logs" ] && bad "a dry run logged on a host" || ok
[ -s "$M/servers/web1.example.com/changelog.log" ] \
  && bad "a dry run wrote a changelog" || ok

# What the judge was given, and how it was started.
has "$TMP/prompt" "(untrusted data)" "the prompt does not mark the output untrusted"
has "$TMP/prompt" "Baseline marker" "the bundle's source reference was not given"
has "$TMP/prompt" "The provider filters every packet" "memory.md was not given"
has "$TMP/claude-args" '--tools  --strict-mcp-config' "the judge got tools or MCP"
head -n 2 "$TMP/collect-web1.example.com" | grep -qx -- '-----BEGIN SSH SIGNATURE-----' \
  && ok || bad "collect did not get the signature first"

# --- a real run ---------------------------------------------------
mkdir -p "$XDG_STATE_HOME/hostwarden/fleet-run"
echo '{"web1.example.com":{"disk-full":"2026-01-01"}}' \
  >"$XDG_STATE_HOME/hostwarden/fleet-run/findings.json"
run
rc=$?
[ "$rc" = 2 ] && ok || bad "a real run did not exit 2 (rc $rc): $(cat "$TMP/err")"
has "$TMP/out" "/var at 97% — since 2026-01-01" "a known finding lost its date"
has "$TMP/logs" "web1.example.com housekeeping: 2 CRITICAL, 1 WARN" \
  "the journal line was not sent"
lacks "$TMP/logs" "down1.example.com" "an unreachable host was sent a log line"
has "$M/servers/web1.example.com/changelog.log" \
  "[ops1 as root] read-only: housekeeping: 2 CRITICAL" "no changelog line"
has "$M/servers/down1.example.com/changelog.log" "not read (exit 255): ssh" \
  "the unreachable host has no changelog line"
case $(git -C "$M" log -1 --format=%s) in
  *"read-only: fleet housekeeping, 4 critical, 8 warning"*) ok ;;
  *) bad "the workspace commit is missing: $(git -C "$M" log -1 --format=%s)" ;;
esac
[ -z "$(git -C "$M" status --porcelain)" ] && ok \
  || bad "the run left uncommitted changes"
lacks "$M/servers/web1.example.com/memory.md" "Last connected" \
  "the run wrote memory.md"

# --- a host nobody judged, without an alarm ----------------------
run --dry-run --host nojudge1.example.com
rc=$?
[ "$rc" = 1 ] && ok || bad "an unjudged host did not exit 1 (rc $rc)"
lacks "$TMP/out" "all ok" "an unjudged host was reported all ok"

# --- a host that could not be read, without an alarm --------------
run --dry-run --host down1.example.com
rc=$?
[ "$rc" = 1 ] && ok || bad "an unread host did not exit 1 (rc $rc)"

# --- --no-judge fails on an unread host --------------------------
run --no-judge --host down1.example.com
rc=$?
[ "$rc" = 1 ] && ok || bad "--no-judge on an unread host did not exit 1 (rc $rc)"

# --- a dry run writes no ssh_config -------------------------------
mv "$M/ssh_config" "$TMP/ssh_config.saved"
run --dry-run --host web1.example.com
rc=$?
[ "$rc" = 1 ] && [ ! -e "$M/ssh_config" ] && ok \
  || bad "a dry run generated ssh_config (rc $rc)"
mv "$TMP/ssh_config.saved" "$M/ssh_config"

# --- a dry run leaves both checkouts alone ------------------------
# check-updates.sh is not in this checkout: a call would show up in
# the report's notes.
(unset HOSTWARDEN_FLEET_RUN_FRESH; run --dry-run --host web1.example.com)
lacks "$TMP/out" "at the start" "a dry run ran the update and the pull"

# --- an argument not known here runs no update --------------------
# A stand-in update that leaves a mark, removed again after.
printf '#!/bin/sh\n: >"%s/updated"\n' "$TMP" >"$R/.claude/hooks/check-updates.sh"
for args in --dry-runn '--hots web1.example.com' --host '--host --dry-run'; do
  # shellcheck disable=SC2086 # split on purpose: one case, many words
  (unset HOSTWARDEN_FLEET_RUN_FRESH; run $args)
  rc=$?
  [ "$rc" = 1 ] && ok || bad "'$args' did not exit 1 (rc $rc)"
  has "$TMP/err" 'Usage:' "'$args' printed no usage"
  [ -e "$TMP/updated" ] && bad "'$args' ran the update" || ok
  rm -f "$TMP/updated"
done
rm "$R/.claude/hooks/check-updates.sh"

# --- a report the mail transport refuses -------------------------
server ok1.example.com 'key line present' ''
git -C "$M" add -A && git -C "$M" commit --quiet -m ok1
echo 'Report email: ops@example.com' >>"$M/user.md"
printf '#!/bin/sh\ncat >/dev/null\nexit 75\n' >"$S/sendmail"
chmod +x "$S/sendmail"
run --host ok1.example.com
rc=$?
[ "$rc" = 1 ] && ok || bad "a refused mail did not exit 1 (rc $rc)"
grep -q 'the mail was not accepted' "$TMP/err" && ok \
  || bad "a refused mail was not named"
has "$TMP/out" "# Fleet housekeeping:" "a refused mail's report was lost"

# --- a bundle that no longer verifies -----------------------------
rm -f "$TMP"/collect-*
echo 'echo changed' >>"$FR/src/linux.sh"
run --dry-run --host web1.example.com
has "$TMP/out" "bundle 'linux' is missing or does not verify" \
  "a changed bundle was not named"
[ -e "$TMP/collect-web1.example.com" ] && bad "a changed bundle was sent" || ok

# --- a handle the remote's operators.md does not hold -------------
# Listed in the local copy only, as before a push.
cp "$M/user.md" "$TMP/user.md"
sed 's/^Operator: ops1$/Operator: ops2/' "$TMP/user.md" >"$M/user.md"
printf -- '- ops2\n' >>"$M/operators.md"
run --dry-run
rc=$?
[ "$rc" = 1 ] && grep -q "not in the remote's memory/operators.md" "$TMP/err" \
  && ok || bad "an unpushed handle ran (rc $rc)"
cp "$TMP/user.md" "$M/user.md"
git -C "$M" checkout --quiet -- operators.md

# --- a handle marked inactive -------------------------------------
cp "$M/operators.md" "$TMP/operators.md"
printf -- '- alice\n- ops1 (inactive since 2026-09-01)\n' >"$M/operators.md"
git -C "$M" commit --quiet -am inactive && git -C "$M" push --quiet
run --dry-run
rc=$?
[ "$rc" = 1 ] && grep -q "marked inactive" "$TMP/err" \
  && ok || bad "an inactive handle ran (rc $rc)"
cp "$TMP/operators.md" "$M/operators.md"
git -C "$M" commit --quiet -am active && git -C "$M" push --quiet

# --- only in operations -------------------------------------------
rm "$M/.hostwarden-workspace"
run --dry-run
rc=$?
[ "$rc" = 1 ] && grep -q 'operations checkout only' "$TMP/err" && ok \
  || bad "a development checkout ran (rc $rc)"

echo "fleet-run: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
