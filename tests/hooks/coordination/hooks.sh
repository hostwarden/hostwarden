# tests/hooks/coordination/hooks.sh — maintenance windows, the
# operations-only check, and the presence and impact hooks' reading
# of a command. Sourced by tests/hooks/coordination.sh, in the order
# its PARTS lists, into the one shell every part shares; never run
# on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- status and maintenance windows ------------------------------
# rules/maintenance-windows.md → What other sessions do with it:
# status also reports a Downtime: window that covers the current
# time. No jq needed — window_status reads memory alone. The
# window spans the whole calendar day (00:00-23:59) rather than an
# hour around "now", so the test never flakes by crossing midnight
# — a Downtime: line's single date cannot express that, the same
# limit the plan format itself has.
drop_downtime() { sed -i.bak '/^- Downtime:/d' "$M/machines/pve1.example.com/memory.md"; }

TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)
WTZ=$(readlink /etc/localtime 2>/dev/null | sed 's#.*/zoneinfo/##')
: "${WTZ:=UTC}"
mkdir -p "$M/plans"

printf -- '- Downtime: %s 00:00-23:59 (plan now-window)\n' "$TODAY" \
  >>"$M/machines/pve1.example.com/memory.md"
printf -- '# now window\n- Window: %s 00:00-23:59 %s\n' "$TODAY" "$WTZ" \
  >"$M/plans/now-window.md"
run status pve1.example.com >"$TMP/out"
[ $? = 0 ] && ok || bad "status: a Downtime window covering now is active"
hasi "$TMP/out" "is inside its planned window" "status: names the window"
hasi "$TMP/out" "plan now-window" "status: names the plan"
drop_downtime
rm "$M/plans/now-window.md"

printf -- '- Downtime: %s 00:00-23:59 (plan gone-window)\n' "$TODAY" \
  >>"$M/machines/pve1.example.com/memory.md"
run status pve1.example.com >"$TMP/out"
[ $? = 1 ] && ok || bad "status: a window whose plan file is missing is left out"
drop_downtime

printf -- '- Downtime: %s 00:00-23:59 (plan past-window)\n' "$YESTERDAY" \
  >>"$M/machines/pve1.example.com/memory.md"
printf -- '# past window\n- Window: %s 00:00-23:59 %s\n' "$YESTERDAY" "$WTZ" \
  >"$M/plans/past-window.md"
run status pve1.example.com >"$TMP/out"
[ $? = 1 ] && ok || bad "status: a window that has already passed is not active"
drop_downtime
rm -f "$M/plans/past-window.md" "$M/machines/pve1.example.com/memory.md.bak"

# --- only in an operations checkout -----------------------------
rm "$M/.hostwarden-workspace"
run announce pve1.example.com reboot >/dev/null 2>&1
[ $? = 1 ] && ok || bad "announce: refuses outside an operations checkout"
: >"$M/.hostwarden-workspace"

echo "== presence.sh"

hook presence.sh PreToolUse sess1 Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ -d "$PRES" ] && [ -n "$(find "$PRES" -maxdepth 1 -name 'sess1+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: Pre makes a run entry for a foreground command"
[ -n "$(find "$PRES" -maxdepth 1 -name 'sess1+web1.example.com+[0-9]*' 2>/dev/null)" ] \
  && ok || bad "presence: Pre also touches the host"

hook presence.sh PostToolUse sess1 Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ -z "$(find "$PRES" -maxdepth 1 -name 'sess1+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: Post removes the run entry"

# -B bind_interface takes a value too; a parser missing it would
# read "eth0" as the destination instead of web1.example.com.
hook presence.sh PreToolUse sessb Bash \
  'ssh -B eth0 -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ -n "$(find "$PRES" -maxdepth 1 -name 'sessb+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: -B bind_interface is read as taking a value"
rm -rf "$PRES/sessb+web1.example.com+run" 2>/dev/null

hook presence.sh PreToolUse sess2 Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' true >/dev/null
[ -z "$(find "$PRES" -maxdepth 1 -name 'sess2+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: run_in_background never makes a run entry"

# Two concurrent foreground calls to the same host, same session —
# the same command text, even — each hold their own marker in the
# run entry: the first call's Post must not remove the second's
# while it is still in flight.
hook presence.sh PreToolUse sessc Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
hook presence.sh PreToolUse sessc Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
MARKS=$(find "$PRES/sessc+web1.example.com+run" -mindepth 1 -maxdepth 1 | wc -l)
[ "$MARKS" -eq 2 ] && ok \
  || bad "presence: two concurrent identical calls get two markers"
hook presence.sh PostToolUse sessc Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ -d "$PRES/sessc+web1.example.com+run" ] \
  && [ -n "$(find "$PRES/sessc+web1.example.com+run" -mindepth 1 -maxdepth 1 2>/dev/null)" ] \
  && ok || bad "presence: the second call's marker survives the first's Post"
hook presence.sh PostToolUse sessc Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ ! -e "$PRES/sessc+web1.example.com+run" ] \
  && ok || bad "presence: the run entry is gone once both calls end"

# Post removes the oldest marker, not an arbitrary one: a call that
# has held its marker open the longest is always the one trimmed
# first, so it can never strand only a stale marker behind while
# removing a fresher call's own — which would read as not live
# under hostwarden_coord_affected's age check (coord-lib.sh) while
# the fresher call is still genuinely running.
mkdir -p "$PRES/sessd+web1.example.com+run"
: >"$PRES/sessd+web1.example.com+run/old"
touch -t "$PAST" "$PRES/sessd+web1.example.com+run/old" 2>/dev/null
: >"$PRES/sessd+web1.example.com+run/new"
hook presence.sh PostToolUse sessd Bash \
  'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
[ ! -e "$PRES/sessd+web1.example.com+run/old" ] \
  && [ -e "$PRES/sessd+web1.example.com+run/new" ] \
  && ok || bad "presence: Post removes the oldest marker, keeping the newest"
rm -rf "$PRES/sessd+web1.example.com+run" 2>/dev/null

hook presence.sh PostToolUse sess3 Bash \
  'D=/tmp/hostwarden; ssh -F memory/ssh_config root@web1.example.com "mkdir -p \$D"' \
  >/dev/null
[ -n "$(find "$PRES" -maxdepth 1 -name 'sess3+web1.example.com+writer' 2>/dev/null)" ] \
  && ok || bad "presence: a register-shaped command sets a writer entry"

hook presence.sh PostToolUse sess3 Bash \
  'ssh -F memory/ssh_config root@web1.example.com "rmdir /tmp/hostwarden/x"' \
  >/dev/null
[ -z "$(find "$PRES" -maxdepth 1 -name 'sess3+web1.example.com+writer' 2>/dev/null)" ] \
  && ok || bad "presence: a deregister-shaped command clears it"

rm -rf "$PRES"
