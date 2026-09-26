# tests/hooks/coordination/teams.sh — teams: impact entries on the
# radius hosts. Sourced by tests/hooks/coordination.sh, in the order
# its PARTS lists, into the one shell every part shares; never run
# on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# ================================================================
echo "== teams: impact entries on the radius hosts"

# Both hosts have their key in memory/known_hosts, so both may be
# reached (rules/coordination.md → Teams).
ssh-keygen -q -t ed25519 -N '' -f "$TMP/hostkey" >/dev/null 2>&1
KEY=$(cut -d' ' -f1,2 "$TMP/hostkey.pub")
printf 'pve1.example.com %s\nweb1.example.com %s\n' "$KEY" "$KEY" \
  >"$M/known_hosts"
rm -rf "$PRES"
: >"$TMP/sshcalls"

# Solo: one active person, one inactive — nothing goes to a host.
printf -- '- alice\n- bob (inactive since 2026-09-01)\n- ops1 (operations host)\n' \
  >"$M/operators.md"
run announce pve1.example.com reboot >"$TMP/out"
TID=$(head -n1 "$TMP/out")
lacks "$TMP/out" "team:" "announce: an inactive handle makes no team"
[ -s "$TMP/sshcalls" ] && bad "announce: solo wrote to a host" || ok
run 'done' "$TID"

# A team: two active people.
printf -- '- alice\n- bob\n' >"$M/operators.md"
printf 'Operator: alice\n' >>"$M/user.md"
run announce pve1.example.com reboot >"$TMP/out"
TID=$(head -n1 "$TMP/out")
hasi "$TMP/out" "team: register entry and journal line on 2 of 2 hosts" \
  "announce: a team tells both radius hosts"
hasi "$TMP/sshcalls" "== alice@pve1.example.com" "announce: calls the origin"
hasi "$TMP/sshcalls" "== alice@web1.example.com" "announce: calls the guest"
hasi "$TMP/sshcalls" "N=\"$TID+" "announce: the register entry carries the id"
hasi "$TMP/sshcalls" "+impact-reboot-pve1.example.com\"" \
  "announce: the register entry names the step"
hasi "$TMP/sshcalls" "[alice as \$(id -un)] impact $TID: reboot of pve1.example.com until" \
  "announce: the journal line's form"
TDIR=$(find "$CACHE/impact" -maxdepth 1 -name "$TID+*" | head -n1)
[ -e "$TDIR/remote/web1.example.com" ] && ok \
  || bad "announce: records the hosts that got an entry"
: >"$TMP/sshcalls"
run 'done' "$TID"
hasi "$TMP/sshcalls" "rmdir /tmp/hostwarden/$TID+*" \
  "done: removes the register entries it made"

# A host blacklisted after the announce gets no cleanup call.
run announce pve1.example.com reboot >"$TMP/out"
TID=$(head -n1 "$TMP/out")
printf -- '- web1.example.com\n' >"$M/blacklist.md"
: >"$TMP/sshcalls"
run 'done' "$TID" >"$TMP/out"
hasi "$TMP/out" "entry left: web1.example.com (blacklisted now" \
  "done: a host blacklisted since is left alone"
lacks "$TMP/sshcalls" "== alice@web1.example.com" \
  "done: no cleanup call to a blacklisted host"
rm -f "$M/blacklist.md"

# A read-only guest gets the journal line alone, an unreachable
# origin is named, and neither holds the step.
printf -- '- web1.example.com\n' >"$M/readonly.md"
echo UNREACHABLE >"$G/call-pve1.example.com"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
rc=$?
TID=$(head -n1 "$TMP/out")
[ "$rc" = 0 ] && ok || bad "announce: a host not reached does not fail it"
hasi "$TMP/out" "journal only: web1.example.com (read-only)" \
  "announce: a read-only host gets the journal line only"
hasi "$TMP/out" "no entry: pve1.example.com (not reached)" \
  "announce: a host not reached is named"
lacks "$TMP/sshcalls" 'mkdir "$N"' \
  "announce: no register entry on a read-only host"
run 'done' "$TID"
rm -f "$M/readonly.md" "$G/call-pve1.example.com"

# The journal line goes where the host's OS file writes one: QNAP's
# log_tool, none where memory records that logger does not land.
printf -- '- Appliance: QTS 5.2.1\n' >>"$M/machines/web1.example.com/memory.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/sshcalls" "/sbin/log_tool -t0" "announce: QNAP's journal line goes through log_tool"
run 'done' "$(head -n1 "$TMP/out")"
sed -i.bak '/^- Appliance: QTS/d' "$M/machines/web1.example.com/memory.md"
printf -- '- Journal: not written\n' >>"$M/machines/web1.example.com/memory.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "register only: web1.example.com (memory says its journal is not written)" \
  "announce: no journal line where memory says it does not land"
run 'done' "$(head -n1 "$TMP/out")"
printf -- '- web1.example.com\n' >"$M/readonly.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "no entry: web1.example.com (read-only, and memory says its journal is not written)" \
  "announce: a read-only host with nothing to write is named as such"
lacks "$TMP/sshcalls" "== alice@web1.example.com" \
  "announce: a host with nothing to write gets no call"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/readonly.md"
sed -i.bak '/^- Journal: not written/d' "$M/machines/web1.example.com/memory.md"
rm -f "$M/machines/web1.example.com/memory.md.bak"

# The read-only list's * makes every host read-only, and a host
# blacklisted by a DNS alias that resolves nowhere is not called.
printf -- '- *\n' >"$M/readonly.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "journal only: pve1.example.com (read-only)" \
  "announce: readonly.md's * covers every host"
lacks "$TMP/sshcalls" 'mkdir "$N"' "announce: no register entry under readonly.md's *"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/readonly.md"
ln -s web1.example.com "$M/machines/web1-old"
printf -- '- web1-old\n' >"$M/blacklist.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "no entry: web1.example.com (blacklisted" \
  "announce: a host blacklisted by its DNS alias is left out"
lacks "$TMP/sshcalls" "== alice@web1.example.com" \
  "announce: a host blacklisted by its DNS alias is not called"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/blacklist.md" "$M/machines/web1-old"
printf -- '- web1.example.com' >"$M/blacklist.md"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "no entry: web1.example.com (blacklisted" \
  "announce: a blacklist's last line without a newline still counts"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/blacklist.md"

# A blacklist.md entry the resolver could not check leaves every
# host unverifiable, not a clean miss (rules/access-control.md →
# Server Blacklist): "no entry", the same outcome as an actual
# match, since a team-telling call is a connection like any other.
printf -- '- unreachable-bl.example.com\n' >"$M/blacklist.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "no entry: pve1.example.com (blacklist unverifiable: resolver unreachable)" \
  "announce: an unresolvable blacklist.md entry does not pass a host through"
hasi "$TMP/out" "no entry: web1.example.com (blacklist unverifiable: resolver unreachable)" \
  "announce: an unresolvable blacklist.md entry does not pass a guest through"
lacks "$TMP/sshcalls" "== alice@pve1.example.com" \
  "announce: no call reaches a host the blacklist could not verify"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/blacklist.md"
# done's cleanup names the outage too, never "blacklisted now".
run announce pve1.example.com reboot >"$TMP/out"
TID=$(head -n1 "$TMP/out")
printf -- '- unreachable-bl.example.com\n' >"$M/blacklist.md"
run 'done' "$TID" >"$TMP/out"
hasi "$TMP/out" "entry left: web1.example.com (blacklist unverifiable: resolver unreachable;" \
  "done: a resolver outage is reported as one, not as a blacklist match"
rm -f "$M/blacklist.md"

# The same for readonly.md: an entry the resolver could not check
# defaults every host to the safe direction, read-only, rather than
# to registering a write it might not be allowed.
printf -- '- unreachable-ro.example.com\n' >"$M/readonly.md"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" \
  "journal only: web1.example.com (read-only status unverifiable: resolver unreachable)" \
  "announce: an unresolvable readonly.md entry does not default to registering"
lacks "$TMP/sshcalls" 'mkdir "$N"' \
  "announce: no register entry while readonly.md is unverifiable"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/readonly.md"

# A host without a key in memory/known_hosts is never called.
printf 'pve1.example.com %s\n' "$KEY" >"$M/known_hosts"
: >"$TMP/sshcalls"
run announce pve1.example.com reboot >"$TMP/out"
hasi "$TMP/out" "no entry: web1.example.com (no key in memory/known_hosts)" \
  "announce: a host without a known key is left out"
lacks "$TMP/sshcalls" "== alice@web1.example.com" \
  "announce: a host without a known key is not called"
run 'done' "$(head -n1 "$TMP/out")"
rm -f "$M/operators.md" "$M/known_hosts"
