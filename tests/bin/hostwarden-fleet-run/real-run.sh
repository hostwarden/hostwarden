# tests/bin/hostwarden-fleet-run/real-run.sh — a real run, and every
# way one can end short. Sourced by
# tests/bin/hostwarden-fleet-run.sh, in the order its PARTS lists,
# into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

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
has "$M/machines/web1.example.com/changelog.log" \
  "[ops1 as root] read-only: housekeeping: 2 CRITICAL" "no changelog line"
has "$M/machines/down1.example.com/changelog.log" "not read (exit 255): ssh" \
  "the unreachable host has no changelog line"
case $(git -C "$M" log -1 --format=%s) in
  *"read-only: fleet housekeeping, 4 critical, 8 warning"*) ok ;;
  *) bad "the workspace commit is missing: $(git -C "$M" log -1 --format=%s)" ;;
esac
[ -z "$(git -C "$M" status --porcelain)" ] && ok \
  || bad "the run left uncommitted changes"
lacks "$M/machines/web1.example.com/memory.md" "Last connected" \
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

# --- a resolver that goes down after a clean miss ----------------
# A blacklist entry with no address, cleared at the host selection;
# by the check right before the connection the resolver is down, and
# that check fails closed rather than reusing the first answer.
rm -f "$TMP"/collect-* "$S/flip1-asked"
cp "$M/blacklist.md" "$TMP/blacklist.md"
printf -- '- flip1.example.com\n' >>"$M/blacklist.md"
run --dry-run --host web1.example.com
has "$TMP/out" \
  "WARN	web1.example.com	not read: blacklist unverifiable: resolver unreachable" \
  "a clean miss from the host selection cleared the blacklist in an outage"
[ -e "$TMP/collect-web1.example.com" ] \
  && bad "a host was reached while a blacklist entry could not be checked" \
  || ok
cp "$TMP/blacklist.md" "$M/blacklist.md"

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
