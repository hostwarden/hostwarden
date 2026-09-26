# tests/hooks/coordination/hooks-jq.sh — the impact hook's
# decisions, where jq is there to read them. Sourced by
# tests/hooks/coordination.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

if [ "$HAVE_JQ" = 1 ]; then
  echo "== impact.sh: origin"

  mkdir -p "$PRES/other3+web1.example.com+run"; : >"$PRES/other3+web1.example.com+run/1"

  # A mention of "reboot" is not an invocation of it.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "last reboot"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: last reboot is never denied"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com reboot' >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: an origin session gets denied with a live guest"
  hasi "$TMP/hookout" 'pve1.example.com reboot' "impact.sh: names the step"

  # A sudo or doas prefix is stripped before reading the command
  # word: AGENTS.md -> Remote mode makes sudo the default way a
  # non-root login runs anything, so these are the common case.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "sudo reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: sudo reboot over ssh is still confirmed"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "sudo systemctl reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: sudo systemctl reboot over ssh is still confirmed"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "doas reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: doas reboot over ssh is still confirmed"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "doas shutdown -r now"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: doas shutdown -r over ssh is still confirmed"

  # -h host (LDAP sudoers) and -D directory (sudo 1.9+) also take a
  # value: man sudo.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "sudo -h ldaphost reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: sudo -h ldaphost reboot over ssh is still confirmed"

  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config alice@pve1.example.com "sudo -D /root reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: sudo -D /root reboot over ssh is still confirmed"

  HOSTWARDEN_SESSION=mine run announce pve1.example.com reboot >"$TMP/out"
  unset HOSTWARDEN_SESSION
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com reboot' >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: passes once this session announced it"
  rm -rf "$PRES/other3+web1.example.com+run"
  HOSTWARDEN_SESSION=mine run 'done' "$(head -n1 "$TMP/out")"
  unset HOSTWARDEN_SESSION

  # A read-only audit command never denies, even with a live
  # session on the radius: the firewall/network patterns match a
  # write or reload verb, never the bare tool name.
  mkdir -p "$PRES/other3+web1.example.com+run"; : >"$PRES/other3+web1.example.com+run/1"
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "ufw status verbose"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a read-only firewall audit is never denied"
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "firewall-cmd --list-all"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: firewall-cmd --list-all is never denied"
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "nft list ruleset"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: nft list ruleset is never denied"

  # The raw-text "maybe" prefilter is read with every quote
  # character dropped, JSON's own \" escape included, not only the
  # command as coord-lib.sh finally reads it: a firewall keyword
  # split across adjacent quotes has to still fire the fast path,
  # not only the precise check a live "maybe" match unlocks.
  MQ_CMD=$(cat <<'MQEOF'
ssh -F memory/ssh_config root@pve1.example.com "u"'fw'" enable"
MQEOF
)
  hook impact.sh PreToolUse mine Bash "$MQ_CMD" >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a firewall keyword split across adjacent quotes is denied"

  # -P takes a value too (the same table hops.sh reads); a parser
  # missing it would read "tag" as the destination instead of pve1.
  hook impact.sh PreToolUse mine Bash \
    'ssh -P tag -F memory/ssh_config root@pve1.example.com reboot' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: -P tag is read as taking a value"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: -P tag still names pve1.example.com, not tag"

  # A second ssh call in the same command is checked too, not only
  # the first.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@lone.example.com uptime; ssh -F memory/ssh_config root@pve1.example.com reboot' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a second ssh call in the command is checked"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: the second call's own destination is named"

  # A newline ends a command as ; does: the second line's own ssh
  # is checked too.
  hook impact.sh PreToolUse mine Bash \
    "$(printf 'ssh -F memory/ssh_config root@lone.example.com uptime\nssh -F memory/ssh_config root@pve1.example.com reboot')" \
    >/dev/null
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: an ssh call on a second line is checked"

  # A printf piped into the far shell runs there, as a heredoc
  # body does.
  hook impact.sh PreToolUse mine Bash \
    "printf '%s\\n' 'export LC_ALL=C' 'systemctl reboot' | ssh -F memory/ssh_config root@pve1.example.com 'sh -s'" \
    >/dev/null
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: a reboot piped into the far shell is checked"

  # A harmless call's own destination is never charged with another
  # call's disruption kind: web1 has a live session (other3) and
  # would be wrongly denied as a reboot target under a single,
  # command-wide kind — its own segment is only "uptime".
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@web1.example.com uptime; ssh -F memory/ssh_config root@pve1.example.com reboot' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: still denies for the segment that is actually a reboot"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: names pve1, not web1, as the reboot target"
  lacks "$TMP/hookout" 'web1.example.com reboot' \
    "impact.sh: web1's own harmless segment is never named as a reboot"

  # A ; or && the remote command's own quotes hold is not a local
  # separator: splitting there would leave the actual disruptive
  # verb in a piece with no destination of its own, so it would
  # never be checked against any host's radius.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "true && reboot"' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a && inside the remote command's own quotes is not a separator"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: names pve1.example.com for the quoted && case"

  hook impact.sh PreToolUse mine Bash \
    "ssh -F memory/ssh_config root@pve1.example.com 'uptime; reboot'" \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a ; inside the remote command's own quotes is not a separator"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: names pve1.example.com for the quoted ; case"

  # A backslash-escaped quote of the kind already open must not
  # flip the scanner's open-quote state: that would read the rest
  # of the command, a second ssh call's own destination included,
  # as still quoted and drop it from the destinations found at all.
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@lone.example.com "safe \" text" ; ssh -F memory/ssh_config root@pve1.example.com reboot' \
    >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a second call survives an escaped quote earlier in the command"
  hasi "$TMP/hookout" 'pve1.example.com reboot' \
    "impact.sh: names pve1.example.com after the escaped-quote segment"

  # A run entry orphaned by a crashed or denied Bash call (its Post
  # never fires) is not read as live once its marker is older than
  # presence.sh's own sweep window for a run entry, six hours: a
  # reader never waits for the next sweep to see that. other3's
  # marker still exists on disk; it just no longer holds off pve1's
  # reboot.
  touch -t "$PAST" "$PRES/other3+web1.example.com+run/1" 2>/dev/null
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com reboot' >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a run marker past the sweep window no longer denies"

  # An announced kind only covers a later step of the same, or an
  # equally broad, kind (rules/coordination.md -> Blast radius):
  # restart:<unit> has a narrower radius than reboot, network or
  # firewall, so an earlier restart:nginx must not silently cover a
  # later reboot on the same host.
  mkdir -p "$PRES/other6+pve1.example.com+run"
  : >"$PRES/other6+pve1.example.com+run/1"
  HOSTWARDEN_SESSION=mine run announce pve1.example.com restart:nginx \
    >"$TMP/out"
  unset HOSTWARDEN_SESSION
  RID=$(head -n1 "$TMP/out")
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com reboot' >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a restart:nginx announcement does not cover a later reboot"
  HOSTWARDEN_SESSION=mine run 'done' "$RID"
  unset HOSTWARDEN_SESSION

  # An announcement of a kind that already takes the whole radius
  # (network, firewall, reboot, or a restart of a unit on the SSH,
  # firewall or network path) covers any other such kind: each
  # one's radius is the same "the host is entirely out" superset.
  HOSTWARDEN_SESSION=mine run announce pve1.example.com network \
    >"$TMP/out"
  unset HOSTWARDEN_SESSION
  RID=$(head -n1 "$TMP/out")
  hook impact.sh PreToolUse mine Bash \
    'ssh -F memory/ssh_config root@pve1.example.com "nft -f /etc/nftables.conf"' \
    >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a network announcement covers a later firewall change too"
  HOSTWARDEN_SESSION=mine run 'done' "$RID"
  unset HOSTWARDEN_SESSION
  rm -rf "$PRES/other6+pve1.example.com+run"

  rm -rf "$PRES/other3+web1.example.com+run"

  echo "== impact.sh: receiver"

  HOSTWARDEN_SESSION=origin1 run announce pve1.example.com reboot >"$TMP/out"
  unset HOSTWARDEN_SESSION
  RID=$(head -n1 "$TMP/out")
  hook impact.sh PreToolUse other4 Bash \
    'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
  hasi "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a receiver is refused once"
  hasi "$TMP/hookout" 'pve1.example.com reboot by origin1' \
    "impact.sh: the notice names the origin"
  hook impact.sh PreToolUse other4 Bash \
    'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: the retry goes through"
  HOSTWARDEN_SESSION=origin1 run 'done' "$RID"
  unset HOSTWARDEN_SESSION

  # An impact more than 30 minutes past its own window never denies
  # a receiver: it is as stale as a register entry that old.
  STALEDIR="$CACHE/impact/staleid+pve1.example.com+reboot+$(($(date +%s) - 3000))+origin2"
  mkdir -p "$STALEDIR/radius"
  : > "$STALEDIR/radius/web1.example.com+guest+pve1.example.com"
  hook impact.sh PreToolUse other5 Bash \
    'ssh -F memory/ssh_config root@web1.example.com uptime' >/dev/null
  lacks "$TMP/hookout" '"permissionDecision":"deny"' \
    "impact.sh: a stale impact never refuses a receiver"
  rm -rf "$STALEDIR"
else
  echo "  (jq missing — impact.sh skipped)"
fi
