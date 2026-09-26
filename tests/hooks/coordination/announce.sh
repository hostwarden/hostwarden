# tests/hooks/coordination/announce.sh — announce, wait, ack, done
# and status. Sourced by tests/hooks/coordination.sh, in the order
# its PARTS lists, into the one shell every part shares; never run
# on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# ================================================================
echo "== announce, wait, ack, done, status"

run announce pve1.example.com reboot >"$TMP/out"
ID=$(head -n1 "$TMP/out")
[ -n "$ID" ] && ok || bad "announce prints an id"
has "$TMP/out" "no live session on the radius; proceeding" \
  "announce: nothing affected" || sed -n '2,$p' "$TMP/out"
run 'done' "$ID"

# The cache directory this checkout used, found rather than
# recomputed: cksum's input is an implementation detail of
# hostwarden_cache_dir (mode.sh), not of this fixture.
CACHE=$(find "$HOME/.cache/hostwarden" -maxdepth 1 -type d -name 'ws-*' | head -n1)
[ -n "$CACHE" ] && ok || bad "announce: made a cache directory"
PRES="$CACHE/presence"
run status pve1.example.com >"$TMP/out"
exits=$?
[ "$exits" = 1 ] && ok || bad "status after done: no active impact"

# FreeBSD's network restart (rules/os/freebsd.md: service netif
# restart && service routing restart) takes the whole radius, the
# same as reboot, network and firewall.
run radius pve1.example.com restart:netif >"$TMP/out"
hasi "$TMP/out" "web1.example.com guest pve1.example.com" \
  "radius: restart:netif takes the whole radius"
run radius pve1.example.com restart:routing >"$TMP/out"
hasi "$TMP/out" "web1.example.com guest pve1.example.com" \
  "radius: restart:routing takes the whole radius"

# A DNS-alias symlink (rules/dns-aliases.md) resolves without the
# index or a connection, so a session that touches web1 by its
# alias before any radius has run is still seen under its canonical
# name.
ln -s web1.example.com "$M/machines/web1"
hook presence.sh PreToolUse sessalias Bash \
  'ssh -F memory/ssh_config root@web1 uptime' >/dev/null
[ -n "$(find "$PRES" -maxdepth 1 -name 'sessalias+web1.example.com+run' 2>/dev/null)" ] \
  && ok || bad "presence: a DNS-alias symlink resolves to its canonical host"
rm -rf "$PRES/sessalias+web1.example.com+"*
rm "$M/machines/web1"

# Another session's presence: a run entry on the guest.
mkdir -p "$PRES"
mkdir -p "$PRES/other1+web1.example.com+run"
: >"$PRES/other1+web1.example.com+run/1"
mkdir -p "$PRES/other1+web1.example.com+$(date +%s)"
run announce pve1.example.com reboot >"$TMP/out"
ID=$(head -n1 "$TMP/out")
hasi "$TMP/out" "other1 web1.example.com run" \
  "announce: an affected session, running"

if [ "$HAVE_JQ" = 1 ]; then
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  wex=$?
  [ "$wex" = 1 ] && ok || bad "wait: a live run entry is not safe"
  hasi "$TMP/out" "not all safe" "wait: reports not safe"

  rm -rf "$PRES/other1+web1.example.com+run"
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  [ $? = 0 ] && ok || bad "wait: safe once the run entry is gone"
  has "$TMP/out" "all safe" "wait: prints all safe"

  run status pve1.example.com >"$TMP/out"
  [ $? = 0 ] && ok || bad "status: an active impact covers pve1"
  hasi "$TMP/out" "pve1.example.com reboot by" "status: names the impact"
  hasi "$TMP/out" "pve1.example.com origin -" "status: the origin relation"

  run status web1.example.com >"$TMP/out"
  [ $? = 0 ] && ok || bad "status: covers a guest too"
  hasi "$TMP/out" "web1.example.com guest pve1.example.com" \
    "status: the guest relation"

  # A writer: unsafe until it acks safe.
  rm -rf "$PRES/other1+web1.example.com+"*
  mkdir -p "$PRES/other2+web1.example.com+writer"
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  [ $? = 1 ] && ok || bad "wait: an un-acked writer is not safe"
  hasi "$TMP/out" "no answer" "wait: an un-acked writer has no answer"

  run ack "$ID" busy still-mid-change >"$TMP/out"
  HOSTWARDEN_SESSION=other2 run ack "$ID" busy still-mid-change
  unset HOSTWARDEN_SESSION
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  [ $? = 1 ] && ok || bad "wait: a writer that acked busy is not safe"
  hasi "$TMP/out" "busy" "wait: reports busy"

  HOSTWARDEN_SESSION=other2 run ack "$ID" safe done-now
  unset HOSTWARDEN_SESSION
  HOSTWARDEN_IMPACT_WAIT_POLL=1 HOSTWARDEN_IMPACT_WAIT_MAX=1 \
    run wait "$ID" >"$TMP/out"
  [ $? = 0 ] && ok || bad "wait: a writer that acked safe is safe"

  run 'done' "$ID"
  run status pve1.example.com
  [ $? = 1 ] && ok || bad "status: done ends the impact"
else
  echo "  (jq missing — wait/ack/status against a live impact skipped)"
fi

# A run entry orphaned by a crashed or denied Bash call (its Post
# never fires) is not read as live once its marker is older than
# presence.sh's own sweep window for a run entry, six hours: a
# reader never waits for the next sweep to see that.
mkdir -p "$PRES/otherstale+web1.example.com+run"
: >"$PRES/otherstale+web1.example.com+run/1"
touch -t "$PAST" "$PRES/otherstale+web1.example.com+run/1" 2>/dev/null
run announce pve1.example.com reboot >"$TMP/out"
lacks "$TMP/out" "otherstale web1.example.com run" \
  "announce: a run marker past presence.sh's sweep window is not live"
run 'done' "$(head -n1 "$TMP/out")" >/dev/null 2>&1
rm -rf "$PRES/otherstale+web1.example.com+run"
