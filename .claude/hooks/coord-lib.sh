# shellcheck shell=sh
# coord-lib.sh — the parts presence.sh, impact.sh and
# bin/hostwarden-impact's announce/wait/ack/done/status share
# (rules/coordination.md), defined once.
#
# Sourced, never executed, so it carries no shebang and tells
# ShellCheck its dialect with the directive above instead.
#
# Defines:
#   hostwarden_coord_dest <command>
#       prints one "<destination>\t<segment>" pair per line: the
#       lowercased name an ssh, sftp, scp or rsync in <command> was
#       given, any leading user@ stripped, and the ;/&/|-delimited
#       segment it came from — so a caller can judge what that one
#       call does without another call's text leaking in
#       (rules/coordination.md → The hooks). A caller that wants
#       only the destination cuts the first field. A via-host guest
#       (`pct exec 105`), a script, and a destination held in a
#       variable are not read: they print nothing, and count as no
#       destination (rules/coordination.md → Presence map → Limits).
#   hostwarden_coord_canon <idx> <name> [<root>]
#       prints the host <idx> (bin/hostwarden-impact's radius.idx)
#       knows <name> by; failing that, with <root> given, the host a
#       memory/servers/<name> DNS-alias symlink names
#       (rules/dns-aliases.md); failing that, <name> itself,
#       lowercased. Read-only, and the symlink read touches no
#       network: it never builds or rebuilds the index and never
#       runs `ssh -G`, so a presence or impact hook stays fast
#       whether or not `radius` has run yet in this session — the
#       cost of not resolving a personal `~/.ssh/config` alias the
#       index has not indexed yet either.
#   hostwarden_coord_beat <dir> <prefix>
#       renews the entry <dir>/<prefix>+<now> — the current time —
#       removing whichever one of <dir>/<prefix>+<digits> stood for
#       it before, or makes it fresh where none did. Only a
#       purely-numeric suffix counts, so a sibling entry sharing the
#       same <prefix> but a name of its own — presence.sh's own
#       +run+<token> and +writer — is never mistaken for it. <dir>
#       is created first, 0700. Used for a presence "touched" entry.
#   hostwarden_coord_sanitize <id>
#       prints <id> with every character outside A-Za-z0-9_- turned
#       into _, the form both a presence entry's own session field
#       and $HOSTWARDEN_SESSION are held to.
#   hostwarden_coord_hhmm <epoch>
#       prints that time, local, as HH:MM. Tries GNU date and then
#       BSD/macOS date, since this runs on the workstation, not the
#       host; <epoch> itself where neither reads it.
#   hostwarden_coord_radius <root> <hosts> <kind>
#       runs <root>/bin/hostwarden-impact radius <hosts> <kind> and
#       prints its output — the one place that calls it, so
#       announce and impact.sh's origin check read the radius the
#       same way.
#   hostwarden_coord_affected <cache> <hosts> <self>
#       one "<session> <host> run|writer|touched" line per live
#       presence.sh entry under <cache>/presence/ for another
#       session (any but <self>) on a host in <hosts>
#       (space- or newline-separated): a run entry counts while it
#       holds at least one file — presence.sh's own per-call marker,
#       so several concurrent calls, identical command text
#       included, each keep it non-empty until every one has ended,
#       and only presence.sh's own sweep (a crashed Bash call's Post
#       never fires) bounds how long an entry no command still holds
#       open can count — a writer counts while its own age is under
#       30 minutes, the same as a live register entry, and a touched
#       one while the epoch in its name is
#       (rules/coordination.md → Presence map).
#   hostwarden_coord_is_reboot <command>
#       true when <command> actually invokes a reboot: the word
#       `reboot` as a command, `shutdown` with a `-r` option,
#       `systemctl reboot` or `systemctl kexec`, `qm reboot` or
#       `pct reboot`, or `kexec` with `-e`/`--exec` — never a mere
#       mention such as `last reboot` (rules/busybox.md).
#   hostwarden_coord_kind <segment>
#       prints the disruptive kind <segment> — one ;/&/|-delimited
#       piece of a command, as hostwarden_coord_dest's second field
#       gives it — names: `reboot` (hostwarden_coord_is_reboot),
#       `firewall`, `network` or `restart:<unit>`, or nothing where
#       it names none (rules/coordination.md → The hooks → Origin).
#       Judged per segment, never on the whole command, so `ssh h1
#       uptime; ssh h2 reboot` names h2's segment reboot and h1's
#       segment nothing.

hostwarden_coord_dest() {
  printf '%s' "$1" | awk '
    function base(w) { sub(/^.*\//, "", w); return w }
    BEGIN {
      RS = "\001"
      # ssh/sftp short options that take a value of their own,
      # unless it is attached to the option letter — the exact set
      # .claude/hooks/hops.sh reads an ssh command line for, kept in
      # sync with it by hand: BbcDEeFIiJLlmOoPpQRSWw.
      SSHVAL = "^-[A-Za-z]*[BbcDEeFIiJLlmOoPpQRSWw]$"
    }
    {
      s = $0
      gsub(/\$\{/, "$", s)
      gsub(/>&/, ">", s); gsub(/<&/, "<", s)
      gsub(/[;&|(){}`]/, "\n", s)
      n = split(s, seg, "\n")
      for (l = 1; l <= n; l++) {
        gsub(/[0-9]*[<>]+[ \t]*[^ \t<>]*/, " ", seg[l])
        gsub(/^[ \t]+|[ \t]+$/, "", seg[l])
        t = seg[l]
        nw = split(seg[l], v, /[ \t]+/)
        if (nw < 1) continue
        for (k = 1; k <= nw; k++) gsub(/^["\047]+|["\047]+$/, "", v[k])
        c = base(v[1])
        if (c == "ssh" || c == "sftp") {
          i = 2
          while (i <= nw) {
            w = v[i]
            if (w == "--") { i++; break }
            if (w ~ /^-/) { if (w ~ SSHVAL) i += 2; else i++; continue }
            break
          }
          if (i <= nw) {
            d = v[i]
            # [ssh://][user@]host[:port], a v6 address bare or as
            # [v6]:port, without the port — the same reading
            # hops.sh gives the destination line ssh -G prints, in
            # its own host() function.
            sub(/^ssh:\/\//, "", d)
            sub(/^[^@]*@/, "", d)
            if (d ~ /^\[/) { sub(/^\[/, "", d); sub(/\].*/, "", d) }
            else if (d !~ /:.*:/) sub(/:[^:]*$/, "", d)
            if (d != "" && d !~ /[$`]/) print tolower(d) "\t" t
          }
          continue
        }
        if (c == "scp" || c == "rsync") {
          for (i = 2; i <= nw; i++) {
            w = v[i]
            if (w ~ /^-/) continue
            d = ""
            if (w ~ /^(rsync:\/\/)/) {
              # rsync://[user@]host[:port]/path.
              d = w
              sub(/^rsync:\/\//, "", d); sub(/\/.*/, "", d)
              sub(/^[^@]*@/, "", d)
              if (d ~ /^\[/) { sub(/^\[/, "", d); sub(/\].*/, "", d) }
              else sub(/:[0-9]+$/, "", d)
            } else if (w ~ /^([A-Za-z0-9_.-]+@)?\[[0-9A-Fa-f:]+\]:/) {
              # [user@][v6]:path — the bracket form a bare v6 host
              # needs, since a path already has a colon of its own.
              d = w
              sub(/^[^@]*@/, "", d)
              sub(/^\[/, "", d); sub(/\].*/, "", d)
            } else if (w ~ /^[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+:/ \
                || w ~ /^[A-Za-z][A-Za-z0-9_.-]+:[^\\\/]/) {
              # [user@]host:path, or host::module (an rsync daemon).
              # A single letter before the colon is a Windows drive,
              # never a host.
              d = w
              sub(/:.*/, "", d); sub(/^[^@]*@/, "", d)
            }
            if (d != "" && d !~ /[$`]/) print tolower(d) "\t" t
          }
        }
      }
    }'
}

hostwarden_coord_canon() {
  hcc_idx=$1 hcc_n=$2 hcc_root=${3:-}
  if [ -s "$hcc_idx" ]; then
    hcc_h=$(awk -F '\t' -v n="$hcc_n" '
      BEGIN { n = tolower(n) }
      $1 == "N" && $2 == n { print $3; f = 1; exit }
      $1 == "K" && $3 == n { k[$2] = 1 }
      END { if (!f) { c = 0; for (x in k) { c++; y = x }
            if (c == 1) print y } }' "$hcc_idx")
    [ -n "$hcc_h" ] && { printf '%s\n' "$hcc_h"; return; }
  fi
  hcc_lc=$(printf '%s' "$hcc_n" | tr '[:upper:]' '[:lower:]')
  if [ -n "$hcc_root" ] && [ -L "$hcc_root/memory/servers/$hcc_lc" ]; then
    hcc_l=$(readlink "$hcc_root/memory/servers/$hcc_lc")
    hcc_l=${hcc_l%/} hcc_l=${hcc_l##*/}
    if [ -n "$hcc_l" ]; then
      printf '%s\n' "$hcc_l" | tr '[:upper:]' '[:lower:]'
      return
    fi
  fi
  printf '%s\n' "$hcc_lc"
}

hostwarden_coord_beat() {
  hcb_dir=$1 hcb_prefix=$2
  # shellcheck disable=SC2174
  mkdir -p -m 700 "$hcb_dir" 2>/dev/null
  hcb_new="$hcb_dir/$hcb_prefix+$(date +%s)"
  for hcb_old in "$hcb_dir/$hcb_prefix+"[0-9]*; do
    [ -e "$hcb_old" ] || continue
    # Renewed within the same second: already exactly the name a
    # rename would give it.
    [ "$hcb_old" = "$hcb_new" ] && return
    mv "$hcb_old" "$hcb_new" 2>/dev/null && return
  done
  mkdir "$hcb_new" 2>/dev/null
}

hostwarden_coord_sanitize() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '_'
}

hostwarden_coord_hhmm() {
  date -d "@$1" +%H:%M 2>/dev/null || date -r "$1" +%H:%M 2>/dev/null \
    || printf '%s\n' "$1"
}

hostwarden_coord_radius() {
  hcr_root=$1 hcr_hosts=$2 hcr_kind=$3
  # shellcheck disable=SC2086 # each host is its own argument
  sh "$hcr_root/bin/hostwarden-impact" radius $hcr_hosts "$hcr_kind"
}

hostwarden_coord_affected() {
  hca_cache=$1 hca_now=$(date +%s) hca_self=$3
  for hca_h in $2; do
    for hca_e in "$hca_cache/presence/"*"+$hca_h+"*; do
      [ -e "$hca_e" ] || continue
      hca_b=${hca_e##*/}
      case $hca_b in
        *"+$hca_h+run") hca_s=${hca_b%"+$hca_h+run"} hca_k=run ;;
        *"+$hca_h+writer") hca_s=${hca_b%"+$hca_h+writer"} hca_k=writer ;;
        *)
          hca_r=${hca_b##*"+$hca_h+"}
          case $hca_r in *[!0-9]* | '') continue ;; esac
          [ $((hca_now - hca_r)) -le 1800 ] || continue
          hca_s=${hca_b%"+$hca_h+$hca_r"} hca_k=touched ;;
      esac
      [ "$hca_s" = "$hca_self" ] && continue
      # A run entry counts while it holds at least one of
      # presence.sh's own per-call markers — its own age is never
      # asked, since a single long-running command (a large
      # transfer, an upgrade) holds it open for however long that
      # takes, and a crashed Bash call's orphaned entry is bounded
      # by presence.sh's own sweep instead, not a read-time check
      # here. A writer's own age is only as fresh as its last
      # register renewal (rules/parallel-sessions.md → Register, and
      # renew), so the same window a live register entry uses
      # applies to it.
      if [ "$hca_k" = writer ]; then
        [ -n "$(find "$hca_e" -maxdepth 0 -mmin -30 2>/dev/null)" ] \
          || continue
      elif [ "$hca_k" = run ]; then
        hca_live=
        for hca_m in "$hca_e"/*; do
          [ -e "$hca_m" ] && { hca_live=1; break; }
        done
        [ -n "$hca_live" ] || continue
      fi
      printf '%s %s %s\n' "$hca_s" "$hca_h" "$hca_k"
    done
  done
}

hostwarden_coord_is_reboot() {
  printf '%s' "$1" | awk '
    function base(w) { sub(/^.*\//, "", w); return w }
    # trig(c, w, nw) — whether the command whose first word base is
    # c, and whose words are w[1..nw], invokes a reboot.
    function trig(c, w, nw,   i) {
      if (c == "reboot") return 1
      if (c == "shutdown") {
        for (i = 2; i <= nw; i++) if (w[i] ~ /^-[A-Za-z]*r/) return 1
        return 0
      }
      if (c == "systemctl") return nw >= 2 && (w[2] == "reboot" || w[2] == "kexec")
      if (c == "qm" || c == "pct") return nw >= 2 && w[2] == "reboot"
      if (c == "kexec") {
        for (i = 2; i <= nw; i++)
          if (w[i] == "-e" || w[i] == "--exec") return 1
        return 0
      }
      return 0
    }
    # judge(w, nw) — whether the command in w[1..nw] invokes a
    # reboot, past a leading sudo or doas: AGENTS.md -> Remote mode
    # makes sudo the default way a non-root login runs anything, so
    # `sudo reboot` and `sudo systemctl reboot` are the ordinary
    # case, not an edge one. SUVAL are the short options of either
    # that take a value of their own.
    function judge(w, nw,    i, c) {
      i = 1
      c = base(w[1])
      if (c == "sudo" || c == "doas") {
        for (i = 2; i <= nw; i++) {
          if (w[i] !~ /^-/) break
          if (w[i] ~ SUVAL) i++
        }
      }
      if (i > nw) return 0
      for (j = i; j <= nw; j++) cw[j - i + 1] = w[j]
      return trig(base(cw[1]), cw, nw - i + 1)
    }
    BEGIN {
      RS = "\001"; rc = 1
      SSHVAL = "^-[A-Za-z]*[BbcDEeFIiJLlmOoPpQRSWw]$"
      SUVAL = "^-[A-Za-z]*[uUgpCRrtThD]$"
    }
    {
      s = $0
      gsub(/\$\{/, "$", s)
      gsub(/[;&|(){}`]/, "\n", s)
      n = split(s, seg, "\n")
      for (l = 1; l <= n; l++) {
        t = seg[l]
        gsub(/^[ \t]+|[ \t]+$/, "", t)
        nw = split(t, v, /[ \t]+/)
        if (nw < 1) continue
        for (k = 1; k <= nw; k++) gsub(/^["\047]+|["\047]+$/, "", v[k])
        if (judge(v, nw)) { rc = 0; exit }
        c = base(v[1])
        # An ssh or sftp call: the same option-skip
        # hostwarden_coord_dest uses to find the destination, then
        # one more word — the remote command starts there, and is
        # judged the same way in turn: `ssh host reboot`, `ssh host
        # "sudo reboot"`, quoted or not.
        if (c == "ssh" || c == "sftp") {
          i = 2
          while (i <= nw) {
            w = v[i]
            if (w == "--") { i++; break }
            if (w ~ /^-/) { if (w ~ SSHVAL) i += 2; else i++; continue }
            break
          }
          i++
          if (i <= nw) {
            rnw = 0
            for (j = i; j <= nw; j++) rw[++rnw] = v[j]
            if (judge(rw, rnw)) { rc = 0; exit }
          }
        }
      }
    }
    END { exit rc }'
}

hostwarden_coord_kind() {
  hck_s=$1
  case "$hck_s" in
  *'nft -f '* | *'nft flush ruleset'* | *'nft delete table'* \
    | *'firewall-cmd'*'-reload'* \
    | *'ufw enable'* | *'ufw disable'* | *'ufw reload'* \
    | *'pve-firewall'*'restart'* | *'pve-firewall compile'* \
    | *'netfilter-persistent'* \
    | *'iptables-restore'* | *'ip6tables-restore'* \
    | *'pfctl -f '* | *'pfctl -e'* | *'pfctl -d'*)
    printf 'firewall\n'
    return ;;
  esac
  case "$hck_s" in
  *'ifreload'* | *'netplan apply'* | *'ifdown '* | *'ifup '* \
    | *'ip link set'*'down'* | *'/etc/init.d/networking'*'restart'* \
    | *'service networking'*'restart'*)
    printf 'network\n'
    return ;;
  esac
  if hostwarden_coord_is_reboot "$hck_s"; then
    printf 'reboot\n'
    return
  fi
  case "$hck_s" in
  *'systemctl restart'* | *'systemctl reload-or-restart'* \
    | *'service '*'restart'* | *'rc-service'*'restart'* \
    | *'launchctl kickstart'* | *'launchctl stop'* \
    | *'launchctl start'*)
    hck_u=$(printf '%s' "$hck_s" | sed -n \
      -e 's/.*systemctl \(restart\|reload-or-restart\) \([A-Za-z0-9@._-]*\).*/\2/p' \
      -e 's/.*service \([A-Za-z0-9@._-]*\) restart.*/\1/p' \
      -e 's/.*rc-service \([A-Za-z0-9@._-]*\) restart.*/\1/p' \
      -e 's#.*launchctl kickstart.*[ /]\(gui/[0-9]*\|system\)/\([A-Za-z0-9._-]*\).*#\2#p' \
      -e 's/.*launchctl \(stop\|start\) \([A-Za-z0-9._-]*\).*/\2/p' \
      | head -n1)
    [ -n "$hck_u" ] && printf 'restart:%s\n' "$hck_u"
    return ;;
  esac
}

# hostwarden_coord_kind_whole <kind> — true when <kind>
# (hostwarden_coord_kind's own vocabulary: reboot, network,
# firewall or restart:<unit>) takes the whole radius rather than a
# service's own dependents (rules/coordination.md → Blast radius):
# reboot, network and firewall outright, or a restart of a unit on
# the SSH path, or the firewall's or the network's own manager —
# the same list `bin/hostwarden-impact`'s radius computation reads,
# so the two can never drift apart. An announcement's own kind
# passes through here too (impact.sh's already-announced check),
# since being fully out is a superset of any single service's own
# dependents.
hostwarden_coord_kind_whole() {
  hckw_k=$1
  case $hckw_k in
  reboot | network | firewall) return 0 ;;
  restart:*)
    hckw_u=${hckw_k#restart:}
    hckw_u=${hckw_u%.service}
    hckw_u=${hckw_u%.socket}
    case $hckw_u in
    ssh | sshd | dropbear | com.openssh.sshd | tailscaled | netbird \
      | zerotier-one | nebula \
      | wg-quick@* | wireguard | openvpn* | strongswan* | ipsec \
      | nftables | firewalld | ufw | pve-firewall | netfilter-persistent \
      | iptables | ip6tables | pf | ipfw | shorewall* | com.apple.alf* \
      | networking | network | NetworkManager | systemd-networkd | wicked \
      | netplan* | netif | routing) return 0 ;;
    esac
    ;;
  esac
  return 1
}
