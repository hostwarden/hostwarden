# tests/hooks/coordination/coordinator.sh — the coordinator. Sourced
# by tests/hooks/coordination.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# ================================================================
echo "== the coordinator"

# A stand-in for the claude CLI: agents --json prints
# $TMP/agents.json, --bg records what it was asked to start.
echo '[]' >"$TMP/agents.json"
cat >"$TMP/bin/claude" <<EOF
#!/bin/sh
case "\$1" in
  agents) cat "$TMP/agents.json" ;;
  --bg) echo "\$*" >>"$TMP/claude-bg" ;;
esac
exit 0
EOF
chmod +x "$TMP/bin/claude"

# start <source> — runs check-session.sh as a SessionStart hook.
start() {
  printf '{"hook_event_name":"SessionStart","session_id":"s0","source":"%s"}' "$1" \
    | sh "$R/.claude/hooks/check-session.sh" >"$TMP/hookout" 2>&1
}
started() {
  i=0
  while [ "$i" -lt 5 ] && [ ! -s "$TMP/claude-bg" ]; do sleep 1; i=$((i + 1)); done
  [ -s "$TMP/claude-bg" ]
}
LOCK="$CACHE/coordinator-start"

rm -f "$TMP/claude-bg"
start startup
hasi "$TMP/hookout" "coordinator started" "check-session: starts one where none runs"
started && hasi "$TMP/claude-bg" "/hostwarden-coordinator" \
  "check-session: starts the skill in the background" \
  || bad "check-session: nothing was started"

rm -f "$TMP/claude-bg"
start startup
lacks "$TMP/hookout" "coordinator started" "check-session: a held start lock starts none"

# The watch marks the coordinator and prints the picture first; a
# second one exits. A long command's run entry is no event.
echo '[{"sessionId":"coord1","kind":"background"}]' >"$TMP/agents.json"
mkdir -p "$PRES/sessw+web1.example.com+$(date +%s)" "$PRES/sessw+web1.example.com+run"
: >"$PRES/sessw+web1.example.com+run/1"
HOSTWARDEN_WATCH_ONCE=1 HOSTWARDEN_SESSION=coord1 run watch >"$TMP/out"
[ $? = 0 ] && ok || bad "watch: the first coordinator marks itself"
has "$TMP/out" "+ presence sessw web1.example.com touched" "watch: prints a touched entry"
lacks "$TMP/out" " run" "watch: a run entry is no event"
[ -d "$LOCK" ] && bad "watch: its mark releases the start lock" || ok
rm -rf "$PRES/sessw+web1.example.com+"*

# An impact 30 minutes past its window leaves the watch's picture.
OLDIMP="$CACHE/impact/oldid+pve1.example.com+reboot+$(($(date +%s) - 3000))+origin9"
mkdir -p "$OLDIMP/radius"
HOSTWARDEN_WATCH_ONCE=1 HOSTWARDEN_SESSION=coord1 run watch >"$TMP/out"
lacks "$TMP/out" "oldid+" "watch: an expired impact is pruned, not reported"
[ -d "$OLDIMP" ] && bad "watch: prunes an expired impact" || ok
HOSTWARDEN_WATCH_ONCE=1 HOSTWARDEN_SESSION=coord2 run watch >"$TMP/out"
[ $? = 1 ] && ok || bad "watch: a second coordinator exits"
hasi "$TMP/out" "another coordinator runs: coord1" "watch: names the first"
run coordinator >"$TMP/out"
has "$TMP/out" "coord1" "coordinator: names the live one"
# Two marks at once: the smaller session id stays.
echo '[{"sessionId":"coord0"},{"sessionId":"coord1"}]' >"$TMP/agents.json"
mkdir "$CACHE/coordinator+coord0+$(date +%s)"
HOSTWARDEN_WATCH_ONCE=1 HOSTWARDEN_SESSION=coord1 run watch >"$TMP/out"
[ $? = 1 ] && ok || bad "watch: the larger of two session ids exits"
hasi "$TMP/out" "another coordinator runs: coord0" "watch: names the one that stays"
rm -rf "$CACHE"/coordinator+coord0+*
echo '[{"sessionId":"coord1","kind":"background"}]' >"$TMP/agents.json"

rm -f "$TMP/claude-bg"
start startup
lacks "$TMP/hookout" "coordinator started" "check-session: a live coordinator starts none"

# Its session gone, the entry is stale and a new one starts.
echo '[]' >"$TMP/agents.json"
run coordinator >/dev/null
[ $? = 1 ] && ok || bad "coordinator: a session not listed is not live"
rm -f "$TMP/claude-bg"
start resume
started && ok || bad "check-session: a stale coordinator is replaced"
rmdir "$LOCK" 2>/dev/null

# Coordinator: off, a compaction and a development checkout start none.
printf '# Preferences\nCoordinator: off\n' >>"$M/user.md"
rm -f "$TMP/claude-bg"
start startup
lacks "$TMP/hookout" "coordinator started" "check-session: Coordinator: off starts none"
sed -i.bak '/^Coordinator: off$/d' "$M/user.md" && rm -f "$M/user.md.bak"
start compact
lacks "$TMP/hookout" "coordinator started" "check-session: a compaction starts none"
rm "$M/.hostwarden-workspace"
start startup
lacks "$TMP/hookout" "coordinator started" "check-session: a development checkout starts none"
: >"$M/.hostwarden-workspace"
rm -f "$TMP/bin/claude"
