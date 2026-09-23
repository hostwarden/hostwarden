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
cp "$REPO/bin/hostwarden-fleet-run" "$REPO/bin/hostwarden-sync" "$R/bin/"
cp "$REPO/.claude/hooks/mode.sh" "$R/.claude/hooks/"
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
cat >"$M/user.md" <<EOF
# Preferences
# Operator name: Your Full Name
Operator name: ops1
Fleet key: $TMP/fleet-key
Workspace push: always
EOF
: >"$TMP/fleet-key"
printf -- '- bad1.example.com\n' >"$M/blacklist.md"

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
server bad1.example.com 'key line present' ''
git -C "$M" add -A && git -C "$M" commit --quiet -m init

# --- the stand-ins ----------------------------------------------
S="$TMP/bin"
mkdir -p "$S"
cat >"$S/ssh" <<EOF
#!/bin/sh
for a; do host=\$verb; verb=\$a; done
host=\${host#root@}
case \$verb in
collect)
  cat >"$TMP/collect-\$host"
  case \$host in
  down1.*) echo "ssh: connect to host \$host port 22: Connection refused" >&2
    exit 255 ;;
  esac
  printf '### meta\n%s\n### floors\ndisk 97 /var\ndisk 40 /\n' "\$host"
  printf 'firewall inactive no packet filter\ncert 20 www\n' ;;
log) printf '%s %s\n' "\$host" "\$(cat)" >>"$TMP/logs" ;;
*) exit 255 ;;
esac
EOF
cat >"$S/claude" <<EOF
#!/bin/sh
cat >"$TMP/prompt"
printf '%s\n' "\$*" >"$TMP/claude-args"
cat "$TMP/verdict"
EOF
chmod +x "$S/ssh" "$S/claude"
cat >"$TMP/verdict" <<'EOF'
{"type":"result","is_error":false,"structured_output":{
 "report":"## Housekeeping Report: web1.example.com",
 "findings":[
  {"severity":"WARN","code":"firewall-inactive","text":"no firewall",
   "class":"expected",
   "quote":"The provider filters every packet in front of it"},
  {"severity":"INFO","code":"disk-full","text":"/var nearly full",
   "class":"known","quote":"a quote that memory.md does not contain"}]}}
EOF

run() { PATH="$S:$PATH" sh "$R/bin/hostwarden-fleet-run" "$@" >"$TMP/out" 2>"$TMP/err"; }

# --- a dry run ----------------------------------------------------
run --dry-run
rc=$?
[ "$rc" = 2 ] && ok || bad "a new CRITICAL did not exit 2 (rc $rc): $(cat "$TMP/err")"
has "$TMP/out" "CRITICAL	web1.example.com	/var nearly full" \
  "the verdict's disk finding was not raised to CRITICAL"
has "$TMP/out" "(expected: \"The provider filters every packet" \
  "a quote found in memory.md did not count"
lacks "$TMP/out" "a quote that memory.md does not contain" \
  "a quote not in memory.md counted"
has "$TMP/out" "WARN	web1.example.com	certificate www expires in 20 days [floor]" \
  "a floor the verdict missed was not added"
has "$TMP/out" "WARN	down1.example.com	not read: ssh: connect to host" \
  "an unreachable host was not reported"
has "$TMP/out" "db1.example.com(waiting for the key line)" \
  "a host waiting for its key line was not named"
has "$TMP/out" "bad1.example.com(blacklisted)" "a blacklisted host was not named"
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
echo '{"web1.example.com":{"disk-full":"2026-01-01"}}' \
  >"$XDG_STATE_HOME/hostwarden/fleet-run/findings.json"
run
rc=$?
[ "$rc" = 2 ] && ok || bad "a real run did not exit 2 (rc $rc): $(cat "$TMP/err")"
has "$TMP/out" "/var nearly full — since 2026-01-01" "a known finding lost its date"
has "$TMP/logs" "web1.example.com housekeeping: 2 CRITICAL, 1 WARN" \
  "the journal line was not sent"
lacks "$TMP/logs" "down1.example.com" "an unreachable host was sent a log line"
has "$M/servers/web1.example.com/changelog.log" \
  "[ops1 as root] read-only: housekeeping: 2 CRITICAL" "no changelog line"
has "$M/servers/down1.example.com/changelog.log" "not read: ssh" \
  "the unreachable host has no changelog line"
case $(git -C "$M" log -1 --format=%s) in
  *"read-only: fleet housekeeping, 2 critical, 2 warning"*) ok ;;
  *) bad "the workspace commit is missing: $(git -C "$M" log -1 --format=%s)" ;;
esac
[ -z "$(git -C "$M" status --porcelain)" ] && ok \
  || bad "the run left uncommitted changes"
lacks "$M/servers/web1.example.com/memory.md" "Last connected" \
  "the run wrote memory.md"

# --- a bundle that no longer verifies -----------------------------
rm -f "$TMP"/collect-*
echo 'echo changed' >>"$FR/src/linux.sh"
run --dry-run --host web1.example.com
has "$TMP/out" "bundle linux does not verify" "a changed bundle was not named"
[ -e "$TMP/collect-web1.example.com" ] && bad "a changed bundle was sent" || ok

# --- only in operations -------------------------------------------
rm "$M/.hostwarden-workspace"
run --dry-run
rc=$?
[ "$rc" = 1 ] && grep -q 'operations checkout only' "$TMP/err" && ok \
  || bad "a development checkout ran (rc $rc)"

echo "fleet-run: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
