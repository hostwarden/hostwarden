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
#       given, any leading user@ stripped, and the
#       ;/&/|-delimited segment it came from — one such character
#       inside a matched single- or double-quote pair is the remote
#       command's own text, not a separator, so `ssh host "true &&
#       systemctl restart nginx"` is one segment, not two — so a
#       caller can judge what that one call does without another
#       call's text leaking in (rules/coordination.md → The hooks).
#       A caller that wants only the destination cuts the first
#       field. A via-host guest (`pct exec 105`), a script, and a
#       destination held in a variable are not read: they print
#       nothing, and count as no destination
#       (rules/coordination.md → Presence map → Limits). Built on
#       HOSTWARDEN_COORD_AWK's shared tokenizer (coord-tokenize.sh): a
#       segment's words are read by the same hc_segments/hc_clean/
#       hc_words hostwarden_coord_is_reboot and hostwarden_coord_kind
#       use, and a leading exec/busybox/sudo/doas is skipped the same
#       way (hc_skip_prefix) so `sudo ssh host reboot` is read the
#       same as `ssh host reboot` — impact.sh's whole check gates on
#       this function finding a destination at all, so a form it
#       cannot see past, unlike the other two, never reaches their
#       own, deeper reading of the remote text either. It does not
#       itself recurse into a wrapper's own remote or -c text for a
#       destination nested there — but a heredoc's own body stays
#       part of the segment field whole, an operator its own body
#       carries (`ssh host 'sh -s' <<EOS` with a body line `sleep 1
#       && systemctl restart nginx`) never splitting this function
#       own segment apart before hostwarden_coord_kind reads it in
#       turn (hc_segments' own hc_heredoc_span), its opening `<<`
#       never one of the redirections hc_clean drops, any embedded
#       newline turned into a `;` first, since a caller reads one
#       record per real newline and hostwarden_coord_kind reads a
#       `;` the same way it would that newline once it gets there.
#   hostwarden_coord_canon <idx> <name> [<root>]
#       prints the host <idx> (bin/hostwarden-impact's radius.idx)
#       knows <name> by; failing that, with <root> given, the host a
#       memory/machines/<name> DNS-alias symlink names
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
#       holds at least one file younger than
#       HOSTWARDEN_COORD_RUN_STALE_MIN — presence.sh's own sweep
#       window for a run entry — presence.sh's own per-call marker,
#       so several concurrent calls, identical
#       command text included, each keep it live until every one has
#       ended or aged past that window, which is how a crashed or
#       denied Bash call's marker (its Post never fires) stops
#       counting as live here, at read time, rather than only once
#       presence.sh's own sweep next runs and removes it — a writer
#       counts while its own age is under 30 minutes, the same as a
#       live register entry, and a touched one while the epoch in
#       its name is under that same 30 minutes
#       (rules/coordination.md → Presence map).
#   hostwarden_coord_is_reboot <command>
#       true when <command> actually invokes a reboot: the word
#       `reboot` as a command, `shutdown` with a `-r` option,
#       `systemctl reboot` or `systemctl kexec`, `qm reboot` or
#       `pct reboot`, or `kexec` with `-e`/`--exec` — never a mere
#       mention such as `last reboot` (rules/busybox.md). Reads
#       past a leading `exec`, `busybox`, `sudo` or `doas` (a GNU
#       long option of either, `sudo --user root …` included), an
#       `ssh`/`sftp` call's own destination (its remote command's
#       words rejoined with a single space, the way `ssh` itself
#       hands them to the far shell — `man ssh`), and a
#       `sh`/`bash`/`dash`/`ksh`/`zsh`/`ash -c`, `env … -c`,
#       `env … -S`/`--split-string` or bare `env VAR=val …`
#       wrapper's own script, and a heredoc's own body (`ssh …
#       host 'sh -s' <<'EOS'` — rules/ssh-connections.md's own
#       bundling idiom), one line judged as one command each, at
#       each level in turn, so `ssh host "sudo bash -c 'apt
#       upgrade -y && reboot'"` and `ssh host sh -c "systemctl
#       restart nginx && reboot"` are read the same as `ssh host
#       reboot` — built on HOSTWARDEN_COORD_AWK (coord-tokenize.sh), the
#       tokenizer hostwarden_coord_dest and hostwarden_coord_kind
#       share.
#   hostwarden_coord_kind <segment>
#       prints one line per disruptive kind <segment> — one
#       ;/&/|-delimited piece of a command, as
#       hostwarden_coord_dest's second field gives it — names:
#       `firewall`, `network`, `reboot`
#       (hostwarden_coord_is_reboot's own reading, past the same
#       wrappers), or one `restart:<unit>` line per distinct unit a
#       `systemctl`/`service`/`rc-service`/`launchctl` restart in
#       it names — a segment that restarts two units prints both,
#       never only the one a single capture would keep — or nothing
#       where it names none (rules/coordination.md → The hooks →
#       Origin). `firewall` and `network` are read twice: once
#       against <segment>'s own raw text, as before, and once
#       against every wrapper-unwrapped word list's words rejoined
#       with a single space, so a keyword the raw text only carries
#       in pieces — several adjacent quoted spans, or behind a
#       `bash -c`/`ssh` wrapper HOSTWARDEN_COORD_AWK's tokenizer
#       reads as one word or one rejoined command — is still read
#       whole; either reading alone is enough, so this only ever
#       adds a match, never takes one away. Judged per segment,
#       never on the whole command, so `ssh h1 uptime; ssh h2
#       reboot` names h2's segment reboot and h1's segment nothing.

# How stale, in minutes, a presence "run" marker (presence.sh's own
# per-call file under a <session>+<host>+run/ entry) has to be
# before it stops counting as live: presence.sh's own periodic sweep
# (its own -mmin +$HOSTWARDEN_COORD_RUN_STALE_MIN) and
# hostwarden_coord_affected's read-time check below (its own -mmin
# -$HOSTWARDEN_COORD_RUN_STALE_MIN) both read it, so a marker that
# age or older is gone from either side alike, one place to change
# it if it is ever retuned.
HOSTWARDEN_COORD_RUN_STALE_MIN=360

# HOSTWARDEN_COORD_AWK, the tokenizer the readers below build on,
# lives in coord-tokenize.sh, which the caller sources first.
: "${HOSTWARDEN_COORD_AWK:?coord-lib.sh needs coord-tokenize.sh sourced first}"

hostwarden_coord_dest() {
  printf '%s' "$1" | awk "$HOSTWARDEN_COORD_AWK"'
    BEGIN {
      RS = "\001"
      # ssh/sftp short options that take a value of their own,
      # unless it is attached to the option letter — the exact set
      # lib/hops.sh reads an ssh command line for, kept in
      # sync with it by hand: BbcDEeFIiJLlmOoPpQRSWw.
      SSHVAL = "^-[A-Za-z]*[BbcDEeFIiJLlmOoPpQRSWw]$"
      SUCLASS = "uUgpCRrtThD"
      SULONGVAL = "^--(user|group|host|chroot|close-from|command-timeout|prompt)$"
    }
    {
      n = hc_segments($0, RAW)
      for (si = 1; si <= n; si++) {
        t = hc_clean(RAW[si])
        # A heredoc body, or any other embedded newline hc_clean
        # left alone, is turned into a ; before this is printed: a
        # caller reads one "<dest>\t<segment>" record per line, so
        # a real newline inside the segment field itself would read
        # as more than one record. hostwarden_coord_kind already
        # reads a ; the same way it would this newline once it gets
        # there, so nothing about what it sees changes, only how it
        # survives the trip.
        gsub(/\n/, ";", t)
        nw = hc_words(t, v)
        if (nw < 1) continue
        i0 = hc_skip_prefix(v, 1, nw)
        if (i0 > nw) continue
        c = base(v[i0])
        if (c == "ssh" || c == "sftp") {
          i = i0 + 1
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
          for (i = i0 + 1; i <= nw; i++) {
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
  if [ -n "$hcc_root" ] && [ -L "$hcc_root/memory/machines/$hcc_lc" ]; then
    hcc_l=$(readlink "$hcc_root/memory/machines/$hcc_lc")
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
      # presence.sh's own per-call markers younger than
      # HOSTWARDEN_COORD_RUN_STALE_MIN, presence.sh's own sweep
      # window for a run entry: nothing renews a marker while its
      # command runs (presence.sh writes it once, at Pre), so a
      # single command that is genuinely still running past that
      # window is, from here, indistinguishable from one whose Post
      # never fired at all — the same ceiling presence.sh's own sweep
      # already puts on a lone marker's directory, just read here
      # deterministically instead of waiting for that sweep to next
      # run and physically remove it. A writer's own age is only as
      # fresh as its last register renewal
      # (rules/parallel-sessions.md → Register, and renew), so the
      # same window a live register entry uses applies to it.
      if [ "$hca_k" = writer ]; then
        [ -n "$(find "$hca_e" -maxdepth 0 -mmin -30 2>/dev/null)" ] \
          || continue
      elif [ "$hca_k" = run ]; then
        [ -n "$(find "$hca_e" -mindepth 1 -maxdepth 1 \
          -mmin "-$HOSTWARDEN_COORD_RUN_STALE_MIN" \
          -print -quit 2>/dev/null)" ] || continue
      fi
      printf '%s %s %s\n' "$hca_s" "$hca_h" "$hca_k"
    done
  done
}

hostwarden_coord_is_reboot() {
  printf '%s' "$1" | awk "$HOSTWARDEN_COORD_AWK"'
    BEGIN {
      RS = "\001"
      SSHVAL = "^-[A-Za-z]*[BbcDEeFIiJLlmOoPpQRSWw]$"
      # sudo/doas short options that take a value of their own:
      # AGENTS.md → Remote mode makes sudo the default way a
      # non-root login runs anything, so `sudo reboot` and `sudo
      # systemctl reboot` are the ordinary case, not an edge one.
      SUCLASS = "uUgpCRrtThD"
      SULONGVAL = "^--(user|group|host|chroot|close-from|command-timeout|prompt)$"
      MAXDEPTH = 8
      HC_NL_SEP = 1
    }
    {
      CLC = 0
      hc_expand($0, 0)
      rc = 1
      for (cl = 1; cl <= CLC; cl++) {
        n = CLN[cl]
        for (k = 1; k <= n; k++) w[k] = CLW[cl, k]
        if (trig(base(w[1]), w, n)) { rc = 0; break }
      }
      exit rc
    }'
}

hostwarden_coord_kind() {
  printf '%s' "$1" | awk "$HOSTWARDEN_COORD_AWK"'
    BEGIN {
      RS = "\001"
      SSHVAL = "^-[A-Za-z]*[BbcDEeFIiJLlmOoPpQRSWw]$"
      SUCLASS = "uUgpCRrtThD"
      SULONGVAL = "^--(user|group|host|chroot|close-from|command-timeout|prompt)$"
      MAXDEPTH = 8
      HC_NL_SEP = 1
    }
    {
      CLC = 0
      hc_expand($0, 0)
      if (fw_match($0)) { print "firewall"; exit }
      for (cl = 1; cl <= CLC; cl++) {
        n = CLN[cl]
        for (k = 1; k <= n; k++) w[k] = CLW[cl, k]
        if (fw_match(joinw(w, 1, n))) { print "firewall"; exit }
      }
      if (net_match($0)) { print "network"; exit }
      for (cl = 1; cl <= CLC; cl++) {
        n = CLN[cl]
        for (k = 1; k <= n; k++) w[k] = CLW[cl, k]
        if (net_match(joinw(w, 1, n))) { print "network"; exit }
      }
      for (cl = 1; cl <= CLC; cl++) {
        n = CLN[cl]
        for (k = 1; k <= n; k++) w[k] = CLW[cl, k]
        if (trig(base(w[1]), w, n)) { print "reboot"; exit }
      }
      seen = SUBSEP
      for (cl = 1; cl <= CLC; cl++) {
        n = CLN[cl]
        for (k = 1; k <= n; k++) w[k] = CLW[cl, k]
        rn = restart_unit(w, n, ru)
        for (r = 1; r <= rn; r++) {
          u = ru[r]
          if (u == "") continue
          if (index(seen, SUBSEP u SUBSEP) > 0) continue
          seen = seen u SUBSEP
          print "restart:" u
        }
      }
    }'
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
