# tests/hooks/guard-mode/operations.sh — the off switch, a worktree,
# operations, and the guard without jq. Sourced by
# tests/hooks/guard-mode.sh, in the order its PARTS lists, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# The taboo guard's off switch does not reach the mode guard, not
# even when it names the very host the command goes to.
out=$(bash_json '/usr/bin/ssh server1.example.com true' \
  | HOSTWARDEN_GUARD_DISABLE=server1.example.com \
    sh "$DEV/.claude/hooks/guard-mode.sh")
case "$out" in
*'"permissionDecision":"deny"'*) ok ;;
*) bad "HOSTWARDEN_GUARD_DISABLE switched the mode guard off" ;;
esac

# Worktree: development, whatever the main checkout is.
cmd deny "$WT" '/usr/bin/ssh root@server1.example.com uptime'
cmd pass "$WT" 'git status'
edit pass "$WT" "$WT/rules/backups.md"

# Operations: servers as usual, shipped files read-only.
cmd pass "$OPS" 'ssh root@server1.example.com uptime'
cmd pass "$OPS" 'sudo -n true'
edit deny "$OPS" "$OPS/rules/backups.md"
edit deny "$OPS" "$OPS/rules/new-rule.md"
edit deny "$OPS" "$OPS/memory/../rules/backups.md"
write deny "$OPS" "$OPS/memory/nosuch/../../rules/backups.md"
write pass "$OPS" "$OPS/memory/nosuch/../../memory/network.md"
edit deny "$OPS" "$OPS/.claude/hooks/guard-mode.sh"
edit pass "$OPS" "$OPS/memory/machines/server1.example.com/memory.md"
edit pass "$OPS" "$OPS/memory/user.md"
edit pass "$OPS" "$OPS/.claude/settings.local.json"
edit pass "$OPS" "$TMP/elsewhere.txt"
write deny "$OPS" "$OPS/rules/x.md"
# Text that looks like the tool name does not pass for a Bash call.
verdict deny "$OPS" "$(jq -n --arg p "$OPS/rules/x.md" \
  '{tool_name:"Write",tool_input:{file_path:$p,content:"\"tool_name\":\"Bash\""}}')"
write pass "$OPS" "$OPS/memory/network.md"
write pass "$OPS" "$OPS/memory/machines/server2.example.com/memory.md"
# A link in memory/ that leads to a shipped file is that file.
ln -s ../rules/backups.md "$OPS/memory/sneaky.md"
edit deny "$OPS" "$OPS/memory/sneaky.md"
drain
rm "$OPS/memory/sneaky.md"
# ...and so is the end of a chain too long to follow.
ln -s ../rules/backups.md "$OPS/memory/l0"
for n in 1 2 3 4 5 6 7 8 9 10 11; do
  ln -s "l$((n - 1))" "$OPS/memory/l$n"
done
edit deny "$OPS" "$OPS/memory/l11"
drain
rm "$OPS"/memory/l*
# A DNS alias links to another host's directory in memory/.
mkdir -p "$OPS/memory/machines/web1.example.com"
ln -s web1.example.com "$OPS/memory/machines/www.example.com"
edit pass "$OPS" "$OPS/memory/machines/www.example.com/memory.md"

# Without jq the guard reads what it can with sed and refuses
# what it cannot, never the other way round. A PATH that holds
# every tool the hook uses except jq.
mkdir -p "$TMP/nojq"
for t in cat sed tr awk git readlink head; do
  ln -s "$(command -v "$t")" "$TMP/nojq/$t"
done
nojq() {
  out=$(printf '%s' "$3" | PATH="$TMP/nojq" /bin/sh "$2/.claude/hooks/guard-mode.sh")
  case "$out" in *'"permissionDecision":"deny"'*) got=deny ;; *) got=pass ;; esac
  if [ "$got" = "$1" ]; then ok; else bad "[$1, got $got] without jq: $3"; fi
}
nojq deny "$DEV" "$(bash_json '/usr/bin/ssh server1.example.com true')"
nojq pass "$DEV" "$(bash_json 'ssh server1.example.com true')"
nojq pass "$DEV" "$(bash_json 'git status')"
nojq deny "$DEV" "$(bash_json 'tail -f /tmp/build.log' Monitor)"
nojq pass "$OPS" "$(bash_json 'ssh server1.example.com true' Monitor)"
nojq pass "$DEV" "$(edit_json "$DEV/rules/backups.md")"
nojq deny "$OPS" "$(edit_json "$OPS/rules/backups.md")"
nojq pass "$OPS" "$(edit_json "$OPS/memory/machines/server1.example.com/memory.md")"
nojq pass "$OPS" "$(bash_json 'ssh server1.example.com true')"
drain
