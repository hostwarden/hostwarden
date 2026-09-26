# tests/hooks/guard-taboos/override.sh — malformed input, the
# operator override, guard-settings.sh and the deny message. Sourced
# by tests/hooks/guard-taboos.sh, in its order, into the one shell
# every part shares; never run on its own.
# shellcheck shell=sh

# --- fallback path: malformed (non-JSON) stdin -----------------
OUT=$(printf '%s' 'mkfs.ext4 /dev/sda1' \
  | env -u HOSTWARDEN_GUARD_DISABLE sh "$HOOK")
if printf '%s' "$OUT" \
  | grep -q '"permissionDecision":"deny"'; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: raw-input fallback did not deny mkfs"
fi

expect() {
  # expect <label> <command...> — passes when the command succeeds.
  L=$1; shift
  if "$@"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $L"
  fi
}
V=HOSTWARDEN_GUARD_DISABLE

# --- operator override: one host, set at launch, recorded then ---
# The variable names one host, or localhost, and switches the guard
# off only toward it, and only for a session whose start
# check-session.sh recorded with that host; a value that arrives or
# changes mid-session finds no record of itself. HOME is a scratch
# directory, so the tester's own records never decide a fixture.
GHOME=$(mktemp -d)
mkdir -p "$GHOME/.cache/hostwarden"
echo web1.example.com > "$GHOME/.cache/hostwarden/guard-off-s-web1"
echo localhost > "$GHOME/.cache/hostwarden/guard-off-s-local"
off_case() {
  # off_case <expect> <session> <value> <label> <json>
  E=$1 S=$2 X=$3 L=$4
  OUT=$(printf '%s' "$5" | jq -c --arg s "$S" '. + {session_id: $s}' \
    | env HOME="$GHOME" "$V=$X" sh "$HOOK")
  if denied "$OUT"; then GOT=deny; else GOT=pass; fi
  expect "off switch [$E, got $GOT]: $L" [ "$GOT" = "$E" ]
}
off_bash() {
  # off_bash <expect> <session> <value> <command>
  off_case "$1" "$2" "$3" "$4" "$(json_for "$4")"
}
W=web1.example.com
off_bash pass s-web1 $W "ssh root@$W mkfs.ext4 /dev/sda1"
off_bash pass s-web1 WEB1.Example.com. "ssh -p 2222 $W sgdisk -Z /dev/sda"
off_bash pass s-web1 $W "xz -dc img.xz | ssh $W 'dd of=/dev/sda bs=4M'"
off_bash pass s-web1 $W "sudo ssh -F '/a b/ssh_config' $W wipefs -a /dev/sda"
off_bash pass s-web1 $W "ssh $W sh -s <<'EOF'
sgdisk -Z /dev/sda
mkfs.ext4 /dev/sda1
EOF"
off_bash deny s-web1 $W 'ssh db1.example.com mkfs.ext4 /dev/sda1'
off_bash deny s-web1 $W 'mkfs.ext4 /dev/sda1'
off_bash deny s-web1 $W "ssh $W true; mkfs.ext4 /dev/sda1"
off_bash deny s-web1 $W "ssh $W 'dd if=/dev/sda' > /dev/sdb"
off_bash deny s-web1 $W "ssh $W 'ssh db1.example.com mkfs.ext4 /dev/sda1'"
off_bash deny s-web1 $W "ssh $W true && ssh db1.example.com wipefs -a /dev/sda"
off_bash deny s-web1 $W 'H=web1.example.com; ssh $H mkfs.ext4 /dev/sda1'
off_bash deny s-web1 $W "scp /tmp/img.raw $W:/dev/sda"
off_bash deny s-web1 1 "ssh $W mkfs.ext4 /dev/sda1"
off_bash deny s-web1 db1.example.com 'ssh db1.example.com mkfs.ext4 /dev/sda1'
off_bash deny s-unrecorded $W "ssh $W mkfs.ext4 /dev/sda1"
off_case pass s-web1 $W 'Monitor toward the host' \
  "$(json_for "ssh $W mkfs.ext4 /dev/sda1" Monitor)"
off_case deny s-web1 $W 'a key edit stays guarded' \
  '{"tool_name":"Write","tool_input":{"file_path":"/etc/ssh/sshd_config","content":"x"}}'
off_bash pass s-local localhost 'mkfs.ext4 /dev/sda1'
off_bash pass s-local localhost 'xz -dc img.xz | dd of=/dev/disk4 bs=4m'
off_bash deny s-local localhost 'ssh localhost wipefs -a /dev/sda'
off_bash deny s-local localhost 'ssh -p 2222 root@127.0.0.1 wipefs -a /dev/vda'
off_bash deny s-local localhost 'ssh db1.example.com mkfs.ext4 /dev/sda1'
off_bash deny s-local localhost \
  'mkfs.ext4 /dev/sda1; ssh db1.example.com wipefs -a /dev/sda'
off_bash deny s-local localhost 'scp /tmp/img.raw db1.example.com:/dev/sda'
off_bash deny s-web1 $W "ssh $W 'dd if=/dev/sda' > \"/dev/sdb\""
off_bash pass s-web1 $W "ssh $W 'sh -s' <<'EOF'
echo b > /proc/sysrq-trigger
EOF"
off_bash pass s-web1 $W "ssh $W 'mkdir -p /mnt/etc/ssh; chmod 600 /mnt/root/.ssh/authorized_keys'"
off_bash deny s-web1 $W "ssh $W 'timeout 9 ssh db1.example.com wipefs -a /dev/sda'"
off_bash deny s-web1 $W \
  "ssh $W 'ansible db1.example.com -m parted -a device=/dev/sda'"
off_bash deny s-web1 $W "ssh $W 'pct exec 105 -- sgdisk -Z /dev/sda'"
off_bash deny s-web1 $W "ssh $W sh -s <<'EOF'
export LC_ALL=C
lsblk
ssh db1.example.com wipefs -a /dev/sda
EOF"
# The line after a heredoc's closing line is a command of its own,
# never part of the heredoc's segment.
off_bash deny s-web1 $W "ssh $W sh -s <<'EOF'
lsblk
EOF
mkfs.ext4 /dev/sda1"
off_bash deny s-web1 $W "ssh $W '\$SUDO ssh db1.example.com wipefs -a /dev/sda'"
off_bash deny s-web1 $W "ssh $W '/usr/bin/ssh db1.example.com mkfs.ext4 /dev/sda1'"
off_bash pass s-local localhost 'sudo mkfs.ext4 /dev/sda1'
off_bash pass s-local 127.0.0.1 'mkfs.ext4 /dev/sda1'
off_bash pass s-local ::1 'mkfs.ext4 /dev/sda1'
off_bash deny s-local localhost 'timeout 60 ssh db1.example.com wipefs -a /dev/sda'
off_bash deny s-local localhost 'systemctl -H db1.example.com poweroff'
off_bash deny s-local localhost 'pvesh create /nodes/db1/status --command shutdown'
off_bash deny s-web1 $W "ssh $W 'pvesh create /nodes/db1/status --command shutdown'"
off_bash deny s-web1 $W "ssh $W 'systemctl -H db1.example.com poweroff'"
off_bash deny s-local localhost "sh -c 'ssh db1.example.com mkfs.ext4 /dev/sda1'"
off_bash deny s-local localhost \
  'ansible db1.example.com -m command -a "wipefs -a /dev/sda"'
# A guest behind a forwarded port owns the name localhost in the
# radius index; the off switch never resolves localhost through it.
OFF_WS=$(cd "$(dirname "$HOOK")/../.." && pwd)
OFF_CS=$(printf %s "$OFF_WS" | cksum | cut -d' ' -f1)
mkdir -p "$GHOME/.cache/hostwarden/ws-$OFF_CS"
printf 'K\tvm1\tlocalhost\n' > "$GHOME/.cache/hostwarden/ws-$OFF_CS/radius.idx"
off_bash deny s-local localhost 'ssh vm1 wipefs -a /dev/vda'
echo vm1 > "$GHOME/.cache/hostwarden/guard-off-s-vm1"
off_bash deny s-vm1 vm1 'ssh localhost mkfs.ext4 /dev/sda1'
off_bash pass s-vm1 vm1 'ssh vm1 wipefs -a /dev/vda'
off_case pass s-local localhost 'an edit in local mode' \
  '{"tool_name":"Write","tool_input":{"file_path":"/etc/ssh/sshd_config","content":"x"}}'

# check-session.sh records the host it is given, normalised, and
# refuses a value that names none.
CS="$CLAUDE_DIR/hooks/check-session.sh"
cs_run() {
  # cs_run <session> <value> — the SessionStart output.
  printf '{"session_id":"%s","source":"startup"}' "$1" \
    | env HOME="$GHOME" "$V=$2" sh "$CS"
}
OUT=$(cs_run s-new Web1.Example.COM.)
expect "check-session did not record the host" \
  [ "$(cat "$GHOME/.cache/hostwarden/guard-off-s-new")" = "$W" ]
case "$OUT" in *"OFF toward $W"*) PASS=$((PASS + 1)) ;;
*) FAIL=$((FAIL + 1)); echo "FAIL: check-session did not name the host" ;;
esac
for X in 1 0 '' 'web1.example.com db1.example.com' 'a,b' '-x'; do
  OUT=$(cs_run s-bad "$X")
  expect "check-session recorded '$X'" \
    [ ! -e "$GHOME/.cache/hostwarden/guard-off-s-bad" ]
  if [ -n "$X" ]; then
    case "$OUT" in *"names no single host"*) PASS=$((PASS + 1)) ;;
    *) FAIL=$((FAIL + 1)); echo "FAIL: check-session took '$X' silently" ;;
    esac
  fi
done
rm -rf "$GHOME"

# --- settings files and records: guard-settings.sh ---------------
# The variable in a settings file would switch the guard off for the
# next session, and a forged record for this one; both are denied
# through every tool, whether or not the guard is already off.
SGUARD="$CLAUDE_DIR/hooks/guard-settings.sh"
hook_case() {
  # hook_case <hook> <name> <expect> <label> <json> [env assignment...]
  H=$1 N=$2 E=$3 L=$4 J=$5; shift 5
  OUT=$(printf '%s' "$J" | env -u "$V" "$@" sh "$H")
  if denied "$OUT"; then GOT=deny; else GOT=pass; fi
  expect "$N [$E, got $GOT]: $L" [ "$GOT" = "$E" ]
}
settings_case() { hook_case "$SGUARD" guard-settings "$@"; }
# A PATH without jq, for the fallbacks below: judged on the raw
# text, which may over-block, never under.
NOJQ=$(mktemp -d)
for t in sh cat grep printf sed tr head; do
  P=$(command -v "$t" 2>/dev/null) && ln -s "$P" "$NOJQ/$t"
done
settings_case deny 'Write settings.local.json' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/settings.local.json","content":"{\"env\":{\"'"$V"'\":\"1\"}}"}}'
settings_case deny 'Edit user settings.json' \
  '{"tool_name":"Edit","tool_input":{"file_path":"/h/.claude/settings.json","old_string":"{","new_string":"{\"env\":{\"'"$V"'\":\"1\"},"}}'
settings_case deny 'MultiEdit managed-settings.json' \
  '{"tool_name":"MultiEdit","tool_input":{"file_path":"/etc/claude-code/managed-settings.json","edits":[{"old_string":"a","new_string":"b"},{"old_string":"{","new_string":"{\"'"$V"'\":1,"}]}}'
settings_case deny 'Write while the guard is already off' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/settings.local.json","content":"'"$V"'"}}' \
  "$V=1"
settings_case deny 'Write to the settings file in upper case' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/SETTINGS.LOCAL.JSON","content":"'"$V"'"}}'
settings_case pass 'Edit that removes it again' \
  '{"tool_name":"Edit","tool_input":{"file_path":"/r/.claude/settings.local.json","old_string":"\"'"$V"'\": \"1\"","new_string":""}}'
settings_case pass 'README naming it' \
  '{"tool_name":"Edit","tool_input":{"file_path":"/r/README.md","old_string":"a","new_string":"'"$V"'"}}'
settings_case pass 'settings file without it' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/settings.local.json","content":"{\"env\":{\"HOSTWARDEN_NO_UPDATE\":\"1\"}}"}}'
settings_case deny 'Bash: jq into settings.local.json' \
  "$(json_for 'jq ".env.'"$V"' = \"1\"" .claude/settings.local.json')"
settings_case deny 'Bash: heredoc into settings.local.json' \
  "$(json_for 'cat > .claude/settings.local.json <<EOF
{"env": {"'"$V"'": "1"}}
EOF')"
settings_case deny 'Bash: append to user settings.json, guard off' \
  "$(json_for "printf x $V >> ~/.claude/settings.json")" "$V=1"
settings_case pass 'Bash: naming it in the docs' \
  "$(json_for "echo see $V in the docs")"
settings_case pass 'Bash: reading the settings file' \
  "$(json_for 'jq .env .claude/settings.local.json')"
settings_case deny 'Write a guard-off record' \
  '{"tool_name":"Write","tool_input":{"file_path":"/h/.cache/hostwarden/guard-off-abc","content":""}}'
settings_case deny 'Bash: touch a guard-off record' \
  "$(json_for 'cd ~/.cache/hostwarden && touch guard-off-abc')"
settings_case deny 'Write a Windows path to the settings file' \
  '{"tool_name":"Write","tool_input":{"file_path":"C:\\\\Users\\\\alice\\\\hw\\\\.claude\\\\settings.local.json","content":"'"$V"'"}}'
# While a settings file carries the variable, a change that never
# names it could flip its value: every Edit of it is denied, and so
# is a shell command naming a settings file. A Write without it, or
# the operator by hand, takes it out.
SET=$(mktemp -d)
mkdir -p "$SET/.claude"
printf '{"env": {"%s": "0"}}\n' "$V" > "$SET/.claude/settings.local.json"
settings_case deny 'Edit flipping the value of an existing key' \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$SET"'/.claude/settings.local.json","old_string":"\"0\"","new_string":"\"1\""}}'
settings_case pass 'Write taking the existing key out' \
  '{"tool_name":"Write","tool_input":{"file_path":"'"$SET"'/.claude/settings.local.json","content":"{}"}}'
settings_case deny 'Bash: sed on settings while the key exists' \
  "$(json_for "sed -i 's/0/1/' .claude/settings.local.json")" \
  "CLAUDE_PROJECT_DIR=$SET" "HOME=$SET/none"
settings_case pass 'Bash: sed on settings without the key' \
  "$(json_for "sed -i 's/0/1/' .claude/settings.local.json")" \
  "CLAUDE_PROJECT_DIR=$SET/none" "HOME=$SET/none"
# Without CLAUDE_PROJECT_DIR the hook finds the project from its own
# path, also when it runs by bare name from its directory.
mkdir -p "$SET/.claude/hooks" "$SET/lib"
cp "$SGUARD" "$SET/.claude/hooks/"
cp "$REPO/lib/json.sh" "$SET/lib/"
SED_JSON=$(json_for "sed -i 's/0/1/' .claude/settings.local.json")
for RUN in "sh $SET/.claude/hooks/guard-settings.sh" \
  "cd $SET/.claude/hooks && sh guard-settings.sh"; do
  OUT=$(printf '%s' "$SED_JSON" | env -u "$V" -u CLAUDE_PROJECT_DIR \
    HOME="$SET/none" sh -c "$RUN")
  expect "guard-settings found no project without CLAUDE_PROJECT_DIR: $RUN" \
    denied "$OUT"
done
rm -rf "$SET"
settings_case pass 'Edit a hook that mentions the records' \
  '{"tool_name":"Edit","tool_input":{"file_path":"/r/.claude/hooks/check-session.sh","old_string":"a","new_string":"guard-off-"}}'
settings_case deny 'no jq: Write settings.local.json' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/settings.local.json","content":"'"$V"'"}}' \
  "PATH=$NOJQ"

# --- the deny message: effect versus text ----------------------
# A deny forbids reaching the effect another way and names the
# route for a command that only carries the word as text. Without
# the second half an agent guesses, and learns to route around.
OUT=$(json_for 'mkfs.ext4 /dev/sda1' | env -u "$V" sh "$HOOK")
for w in 'never reach the same effect' 'git commit -F' \
  'gh --body-file' 'power[o]ff'; do
  case "$OUT" in
  *"$w"*) PASS=$((PASS + 1)) ;;
  *) FAIL=$((FAIL + 1)); echo "FAIL: the deny message lost: $w" ;;
  esac
done
expect "the deny message is not valid JSON" \
  sh -c 'printf "%s" "$1" | jq -e .hookSpecificOutput >/dev/null' _ "$OUT"
