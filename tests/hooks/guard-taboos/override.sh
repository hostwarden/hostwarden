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

# --- operator override: set at launch, and recorded then ---------
# The variable switches the guard off only for a session whose start
# check-session.sh recorded; a value that arrives mid-session finds
# no record. HOME is a scratch directory, so the tester's own records
# never decide a fixture.
GHOME=$(mktemp -d)
mkdir -p "$GHOME/.cache/hostwarden"
: > "$GHOME/.cache/hostwarden/guard-off-s-recorded"
override_out() {
  printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":"mkfs.ext4 /dev/sda1"}}' "$1" \
    | env HOME="$GHOME" "$V=1" sh "$HOOK"
}
expect "the override did not disable the guard for a recorded session" \
  [ -z "$(override_out s-recorded)" ]
expect "the override disabled the guard without a record (mid-session)" \
  denied "$(override_out s-unrecorded)"
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
