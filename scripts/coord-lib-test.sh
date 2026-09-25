#!/bin/sh
# coord-lib-test.sh — the tokenizer matrix for
# .claude/hooks/coord-lib.sh's hostwarden_coord_dest,
# hostwarden_coord_is_reboot and hostwarden_coord_kind: every
# bypass shape hostwarden/hostwarden#313 collected against the two
# reverted hand-patches, plus the shapes found while building the
# shared tokenizer that replaced them (HOSTWARDEN_COORD_AWK). CI
# runs it through scripts/check.sh; an agent session leaves it to
# CI (.claude/rules/pull-requests.md → Checks).
#
# Calls the three functions directly — no fixture checkout, no
# hooks, no jq: they are pure text-in, text-out, and this is the
# fastest, most direct way to pin their behaviour down before
# impact-test.sh and coordination-test.sh's own (indirect, through
# the hooks) coverage runs on top of it.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

# shellcheck source=../.claude/hooks/coord-lib.sh
. "$REPO/.claude/hooks/coord-lib.sh"

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

# reboot <desc> <command> <yes|no> — hostwarden_coord_is_reboot's
# own verdict on <command>: exit 0 (a reboot) when <yes>, exit 1
# otherwise.
reboot() {
  hostwarden_coord_is_reboot "$2"
  rc=$?
  if [ "$3" = yes ]; then
    [ "$rc" -eq 0 ] && ok || bad "is_reboot: $1 (want reboot, got rc=$rc)"
  else
    [ "$rc" -eq 1 ] && ok || bad "is_reboot: $1 (want no reboot, got rc=$rc)"
  fi
}

# kind <desc> <segment> <expected> — hostwarden_coord_kind's own
# output on <segment>, compared line for line against <expected>
# (one kind per line, empty for none).
kind() {
  got=$(hostwarden_coord_kind "$2")
  if [ "$got" = "$3" ]; then ok; else
    bad "kind: $1"
    echo "--- expected"; printf '%s\n' "$3"
    echo "--- got"; printf '%s\n' "$got"
  fi
}

# dest <desc> <command> <expected> — hostwarden_coord_dest's own
# output on <command>, tab-separated lines compared verbatim.
dest() {
  got=$(hostwarden_coord_dest "$2" | tr '\t' '|')
  exp=$(printf '%s' "$3" | tr '\t' '|')
  if [ "$got" = "$exp" ]; then ok; else
    bad "dest: $1"
    echo "--- expected"; printf '%s\n' "$exp"
    echo "--- got"; printf '%s\n' "$got"
  fi
}

# =====================================================================
# hostwarden_coord_dest — regression coverage for the proven
# splitter/destination reader, now built on the shared tokenizer.
# =====================================================================

dest "plain ssh" \
  'ssh -F memory/ssh_config root@web1.example.com uptime' \
  "$(printf 'web1.example.com\tssh -F memory/ssh_config root@web1.example.com uptime')"

dest "two ssh calls, local ;" \
  'ssh root@lone.example.com uptime; ssh root@pve1.example.com reboot' \
  "$(printf 'lone.example.com\tssh root@lone.example.com uptime\npve1.example.com\tssh root@pve1.example.com reboot')"

dest "quoted remote command holds its own ; safely" \
  'ssh root@pve1.example.com "true && systemctl restart nginx"' \
  "$(printf 'pve1.example.com\tssh root@pve1.example.com "true && systemctl restart nginx"')"

dest "an escaped quote does not corrupt what follows" \
  'ssh root@lone.example.com "safe \" text" ; ssh root@pve1.example.com reboot' \
  "$(printf 'lone.example.com\tssh root@lone.example.com "safe \\" text"\npve1.example.com\tssh root@pve1.example.com reboot')"

dest "scp destination, user@host:path" \
  'scp /tmp/x.tar root@web1.example.com:/tmp/' \
  "$(printf 'web1.example.com\tscp /tmp/x.tar root@web1.example.com:/tmp/')"

dest "rsync over ssh, rsync:// URL" \
  'rsync -av rsync://root@web1.example.com/mod/ /tmp/' \
  "$(printf 'web1.example.com\trsync -av rsync://root@web1.example.com/mod/ /tmp/')"

dest "a via-host guest names no destination" 'pct exec 105 -- reboot' ""

dest "local mode: no ssh/scp/rsync, no destination" 'uptime; df -h' ""

# =====================================================================
# hostwarden_coord_is_reboot — the five documented shapes plus the
# ones hunted while building the shared tokenizer.
# =====================================================================

reboot "bare reboot" 'ssh host reboot' yes
reboot "sudo reboot" 'ssh host "sudo reboot"' yes
reboot "sudo systemctl reboot" 'ssh host "sudo systemctl reboot"' yes
reboot "doas reboot" 'ssh host "doas reboot"' yes
reboot "doas shutdown -r" 'ssh host "doas shutdown -r now"' yes
reboot "sudo -h VALUE reboot (sudo's own value option)" \
  'ssh host "sudo -h ldaphost reboot"' yes
reboot "sudo -D VALUE reboot" 'ssh host "sudo -D /root reboot"' yes
reboot "a mere mention is not an invocation" 'ssh host "last reboot"' no
reboot "an unrelated command" 'ssh host uptime' no

# Shape 1 (#313): bash -c / sh -c / env -c wrapper needs a second
# unwrap level.
reboot "shape1: sudo bash -c '...&&reboot'" \
  "$(printf 'ssh host "sudo bash -c '\''apt upgrade -y && reboot'\''"')" \
  yes
reboot "shape1: env -c wrapper" \
  'ssh host "env -c \"reboot\""' yes
reboot "shape1: env VAR=val -c wrapper" \
  'ssh host "env FOO=bar -c \"true && reboot\""' yes
reboot "shape1: doubly-nested bash -c" \
  "$(printf 'ssh host "bash -c '\''sh -c \\"true && reboot\\"'\''"')" \
  yes

# Shape 2 (#313): adjacent quote-type switching with nothing
# unquoted in between. Fixed by hc_words never ending a word on a
# quote closing, only on real unquoted whitespace — verified against
# a well-formed remote command built the same way (a stray
# apostrophe's own quote-reopening on the remote side is a genuine
# shell ambiguity no tokenizer can resolve either way; real /bin/sh
# raises a syntax error on the issue's own literal example too, so
# it is not an executable bypass — only the boundary reconstruction
# is what this covers).
reboot "shape2: adjacent quote spans concatenate into one word" \
  "$(printf 'ssh host '\''true && '\''"reboot"')" yes
reboot "shape2: three adjacent spans, single+double+single" \
  "$(printf 'ssh host '\''sys'\''"temctl "'\''reboot'\''"')" yes

# Shape 3 (#313): several separately-quoted ssh argv words, joined
# by ssh itself with a single space (man ssh).
reboot "shape3: three separately-quoted argv words" \
  'ssh host "systemctl restart nginx" "&&" "reboot"' yes
reboot "shape3: two argv words, unquoted operator alone" \
  'ssh host "true" "&& reboot"' yes

# Shape 4 (#313): an unquoted wrapper word before the quoted
# command — the rules/first-connection.md sh -c/-s bundling idiom.
reboot "shape4: unquoted sh -c" \
  'ssh host sh -c "systemctl restart nginx && reboot"' yes
reboot "shape4: unquoted bash -c, flags before -c" \
  'ssh host bash -O extglob -c "true && reboot"' yes

# Hunted while building the tokenizer: exec, busybox and combined
# wrapper chains.
reboot "hunted: exec prefix does not hide it" 'ssh host "exec reboot"' yes
reboot "hunted: busybox applet prefix" \
  'ssh host "busybox reboot"' yes
reboot "hunted: sudo then ssh's own sh -c wrapper" \
  'ssh host "sudo sh -c '"'"'reboot'"'"'"' yes
reboot "hunted: bare env VAR=val cmd, no -c at all" \
  'ssh host "env FOO=bar reboot"' yes
reboot "hunted: qm/pct reboot behind sudo" 'ssh host "sudo qm reboot 101"' yes
reboot "hunted: kexec -e behind doas" 'ssh host "doas kexec -e"' yes
reboot "hunted: a script file (not -c) is unreadable, no false alarm" \
  'ssh host bash /opt/reboot-if-needed.sh' no
reboot "hunted: ssh with no remote command at all" 'ssh host' no
reboot "hunted: reboot only inside an unrelated argument" \
  'ssh host "touch /tmp/reboot-pending"' no

# Found by the own review's commands-focus pass: sudo's GNU long
# options (man sudo) take a separate-word value the same way the
# short ones do, not only the --name=value form a bare "starts
# with -" skip already covers.
reboot "found in review: sudo --user (separate value) reboot" \
  'ssh host "sudo --user root systemctl reboot"' yes
reboot "found in review: sudo --user=root (attached value) reboot" \
  'ssh host "sudo --user=root systemctl reboot"' yes
reboot "found in review: sudo --host, --chroot, --command-timeout" \
  'ssh host "sudo --host ldaphost --chroot /root --command-timeout 5 reboot"' \
  yes

# Found by the own review: env's real value-taking flags (env
# --help) — -S/--split-string re-tokenizes its value the same way
# -c does; -C/--chdir and -u/--unset take a value that is not a
# command and must only be skipped, not mistaken for the base word.
reboot "found in review: env -S re-tokenizes its value" \
  "$(cat <<'EOF'
ssh host "env -S 'sh -c reboot'"
EOF
)" yes
reboot "found in review: env --split-string=... (attached)" \
  "$(cat <<'EOF'
ssh host "env --split-string='sh -c reboot'"
EOF
)" yes
reboot "found in review: env -C value is skipped, not the base word" \
  'ssh host "env -C /tmp reboot"' yes
reboot "found in review: env -u NAME value is skipped" \
  'ssh host "env -u FOO reboot"' yes

# =====================================================================
# hostwarden_coord_kind — firewall, network, reboot precedence, and
# shape 5's restart:<unit> extraction (#313).
# =====================================================================

kind "firewall: ufw enable" 'ssh host "ufw enable"' firewall
kind "firewall: nft -f" 'ssh host "nft -f /etc/nftables.conf"' firewall
kind "firewall: read-only ufw status never matches" \
  'ssh host "ufw status verbose"' ""
kind "firewall: read-only firewall-cmd list never matches" \
  'ssh host "firewall-cmd --list-all"' ""
kind "firewall: read-only nft list never matches" \
  'ssh host "nft list ruleset"' ""
kind "hunted: firewall keyword split across adjacent quotes" \
  "$(printf 'ssh host "u"'\''fw'\''" enable"')" firewall
kind "hunted: firewall keyword behind an unrecognised wrapper" \
  'ssh host "watch -n1 '"'"'ufw enable'"'"'"' firewall

kind "network: netplan apply" 'ssh host "netplan apply"' network
kind "network: ip link set down" 'ssh host "ip link set eth0 down"' network

kind "reboot dominates: firewall check runs first, but a lone reboot still wins" \
  'ssh host reboot' reboot
kind "reboot behind a wrapper, as kind sees it too" \
  'ssh host "sudo bash -c '"'"'reboot'"'"'"' reboot

kind "restart: single unit, systemctl" \
  'ssh host "systemctl restart nginx"' 'restart:nginx'
kind "restart: single unit, service form" \
  'ssh host "service nginx restart"' 'restart:nginx'
kind "restart: reload-or-restart" \
  'ssh host "systemctl reload-or-restart nginx"' 'restart:nginx'
kind "shape5a: two units in one compound command, both reported" \
  'ssh host "service sshd restart && service nginx restart"' \
  "$(printf 'restart:sshd\nrestart:nginx')"
kind "shape5b: a quoted unit name is not lost" \
  "$(printf 'ssh host "systemctl restart '\''sshd'\''"')" \
  'restart:sshd'
kind "restart: launchctl kickstart, gui/uid form" \
  'ssh host "launchctl kickstart -k gui/501/exampleapp"' \
  'restart:exampleapp'
kind "restart: launchctl stop" 'ssh host "launchctl stop exampleapp"' \
  'restart:exampleapp'
kind "restart: same unit named twice is reported once" \
  'ssh host "systemctl restart nginx; systemctl restart nginx"' \
  'restart:nginx'
kind "restart: a unit behind a bash -c wrapper" \
  'ssh host "bash -c '"'"'systemctl restart nginx'"'"'"' 'restart:nginx'

# Found by the own review: a global systemctl option before the
# verb (systemctl(1)) must not blind the match, and systemctl
# restart takes one or more units in a single invocation — both
# must be reported, not only the first a positional w[3] read kept.
kind "found in review: a global option before the verb" \
  'ssh host "systemctl --user restart myapp"' 'restart:myapp'
kind "found in review: a short global option before the verb" \
  'ssh host "systemctl -q restart nginx"' 'restart:nginx'
kind "found in review: two units in one systemctl invocation" \
  'ssh host "systemctl restart nginx postgresql"' \
  "$(printf 'restart:nginx\nrestart:postgresql')"

# Found by the own review: hostwarden_coord_dest must see past a
# local sudo the same way hc_classify does, since impact.sh's whole
# check gates on it finding a destination at all.
dest "found in review: dest sees past a local sudo" \
  'sudo ssh root@pve1.example.com reboot' \
  "$(printf 'pve1.example.com\tsudo ssh root@pve1.example.com reboot')"
dest "found in review: dest sees past sudo --user (long option)" \
  'sudo --user root ssh root@pve1.example.com reboot' \
  "$(printf 'pve1.example.com\tsudo --user root ssh root@pve1.example.com reboot')"

# Found in the fix pass's own verification round: sudo's short
# value-taking options were still misread when the value was
# attached without a space (sudo -uroot), the exact same
# bare-flag/attached-value ambiguity SSHVAL has, but this one has
# no hops.sh copy to keep in sync with, so it is fixed rather than
# deferred.
reboot "found in verification: sudo -uroot (attached, no space)" \
  'ssh host "sudo -uroot reboot"' yes
reboot "found in verification: sudo -Dlogdir does not overreach" \
  'ssh host "sudo -Dlogdir echo hi"' no

# Found in the fix pass's own verification round: an & right next
# to a < or > duplicates or redirects a file descriptor and is
# never a separator; only a bare & (a real background operator) is.
reboot "found in verification: leading 2>&1 does not hide reboot" \
  'ssh host "2>&1 reboot"' yes
reboot "found in verification: trailing 2>&1 does not hide reboot" \
  'ssh host "reboot 2>&1"' yes
kind "found in verification: 2>&1 does not hide a restart" \
  'ssh host "2>&1 systemctl restart nginx"' 'restart:nginx'
dest "found in verification: a real background job still splits" \
  'ssh host1 uptime & ssh host2 reboot' \
  "$(printf 'host1\tssh host1 uptime\nhost2\tssh host2 reboot')"

# Found in the fix pass's own verification round: the rules/ssh-
# connections.md own `sh -s` heredoc-bundling idiom sent the whole
# script over stdin, invisible to a classifier that only reads the
# command's own words — until the heredoc body itself is read as
# more command text, one depth deeper.
reboot "found in verification: sh -s heredoc, reboot in the body" \
  "$(cat <<'EOF'
ssh host 'sh -s' <<'EOS'
uptime
reboot
EOS
EOF
)" yes
kind "found in verification: sh -s heredoc, restart in the body" \
  "$(cat <<'EOF'
ssh host 'sh -s' <<'EOS'
systemctl restart nginx
EOS
EOF
)" 'restart:nginx'
kind "found in verification: sh -s heredoc, a harmless body" \
  "$(cat <<'EOF'
ssh host 'sh -s' <<'EOS'
uptime
EOS
EOF
)" ""
kind "found in verification: unquoted heredoc delimiter" \
  "$(cat <<'EOF'
ssh host sh -s <<EOS2
systemctl restart nginx
EOS2
EOF
)" 'restart:nginx'
kind "found in verification: <<- dashed form, tab-indented terminator" \
  "$(printf 'ssh host '\''sh -s'\'' <<-EOS\n\tsystemctl restart nginx\n\tEOS\n')" \
  'restart:nginx'
kind "found in verification: a here-string is not a heredoc" \
  'cat <<<"hello restart world"' ""
reboot "found in verification: heredoc combined with a trailing redirect" \
  "$(cat <<'EOF'
ssh host 'sh -s' <<'EOS' 2>&1
reboot
EOS
EOF
)" yes

kind "one segment, no destination, names nothing" 'uptime' ""
kind "a plain, harmless remote command names nothing" \
  'ssh host uptime' ""

echo "coord-lib: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
