# shellcheck shell=sh
# coord-rest.sh — what the taboo guard still judges when its off
# switch names one host. Sourced, never executed, by
# .claude/hooks/guard-taboos.d/off.sh, after coord-tokenize.sh and
# coord-lib.sh, whose tokenizer and HOSTWARDEN_COORD_DEST_AWK it
# reads. Its matrix is tests/lib/coord-rest.sh.
#
# hostwarden_coord_rest <command> <names> <reach> <local>
#   prints what of <command> the taboo guard still judges when
#   its off switch names one host (guard-taboos.d/off.sh): each
#   ;/&/|-delimited segment as written, one per line, except an
#   ssh or sftp segment whose one destination is among <names>
#   (space-separated, lowercased), which leaves only its local
#   redirections behind, one `true <redirection>` line each.
#   Such a segment stays whole when, read at every depth the
#   tokenizer unwraps, it runs a second ssh, names an ssh:// URL
#   or a host option (-H, --host, -M, --machine, bundled too),
#   a Windows host by its UNC name, a Proxmox node other than the
#   named host, or names a
#   command the ERE <reach> matches, as its
#   command word or as a plain word of any command that runs
#   commands (a newline ends a command there too); or when a
#   redirection target is quoted. A heredoc body is
#   the far side's and adds no redirection. With <local> 1, a
#   segment with no destination that <reach> does not match goes
#   as well: localhost's own work. What hostwarden_coord_dest
#   cannot read stays in, so the guard judges it: the safe
#   direction.

: "${HOSTWARDEN_COORD_DEST_AWK:?coord-rest.sh needs coord-lib.sh sourced first}"

hostwarden_coord_rest() {
  # hostwarden_coord_rest <command> <names> <reach> <local> — see
  # the header.
  printf '%s' "$1" | HC_REACH=$3 awk -v names=" $2 " -v loc="$4" \
    "$HOSTWARDEN_COORD_AWK$HOSTWARDEN_COORD_DEST_AWK"'
    BEGIN {
      RS = "\001"
      MAXDEPTH = 8
      # A newline ends a command, in the command itself and in a
      # remote command or heredoc body read again.
      HC_NL_SEP = 1
      HC_DATA_SKIP = 1
      reach = ENVIRON["HC_REACH"]
      # A command whose arguments are names, never a command it runs.
      NAMES = "^(systemctl|service|rc-service|rc-update|apt|apt-get|dnf|yum|zypper|apk|pkg|pacman|brew|emerge|echo|printf|type|which|grep|man)$"
      # A program called by its path.
      PROG = "^/(usr/)?(local/)?s?bin/"
    }
    # s without its heredoc bodies: each opener line stays, its body
    # and closing line go, so a redirection in a body, which runs on
    # the far side, is never read as a local one.
    function nobody(s,    out, i, c, qc, esc, span, head) {
      out = ""; qc = ""; esc = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (esc) { out = out c; esc = 0; continue }
        if (c == "\\" && qc != "\047") { out = out c; esc = 1; continue }
        if (qc != "") { out = out c; if (c == qc) qc = ""; continue }
        if (c == "\"" || c == "\047") { qc = c; out = out c; continue }
        if (c == "<" && substr(s, i, 2) == "<<" && substr(s, i, 3) != "<<<") {
          span = hc_heredoc_span(s, i)
          if (span > 0) {
            head = substr(s, i, span)
            out = out substr(head, 1, index(head, "\n"))
            i += span - 1
            continue
          }
        }
        out = out c
      }
      return out
    }
    # Whether ssh segment t, read at every depth, reaches on from
    # the host: a second ssh, an ssh:// URL, a host option (-H,
    # --host, -M, --machine), a UNC host, another Proxmox node, or
    # a command <reach>
    # names — as a command word, or as any plain word or program
    # path behind an assignment, sudo, su, sshpass, a shell keyword
    # and the like, except where the clause runs a command in NAMES.
    # A word that holds a blank or a newline is a command string,
    # read in turn; a heredoc body cat or tee writes is data.
    function onward(t,    cl, k, w, nn) {
      HC_SSHN = 0; CLC = 0
      hc_expand(t, 0)
      if (HC_SSHN > 1) return 1
      for (cl = 1; cl <= CLC; cl++) {
        # Past the cap the rest is not read: kept, never dropped.
        if (cl > 500) return 1
        for (k = 1; k <= CLN[cl]; k++) {
          w = CLW[cl, k]
          if (w ~ /ssh:\/\//) return 1
          # A host or machine option (systemctl -H, ipmitool -H,
          # machinectl -M) points the command elsewhere, whatever
          # the command is.
          if (k > 1 && \
              w ~ /^(-[A-Za-z]*[HM]|--host|--machine)(=|$)/)
            return 1
          # A Windows host by its UNC name (shutdown /m \\db1), with
          # however many backslashes the quoting left.
          if (w ~ /^\\+[A-Za-z0-9]/) return 1
          # A Proxmox API path on another node than the named host.
          if (w ~ /^\/nodes\/[^\/]+/) {
            nn = w; sub(/^\/nodes\//, "", nn); sub(/\/.*/, "", nn)
            if (!index(names, " " tolower(nn) " ") \
                && !index(names, " " tolower(nn) ".")) return 1
          }
          if (k > 1 && w ~ /[ \t\n]/) { hc_expand(w, 1); continue }
          if (reach == "") continue
          if (k == 1 && " " base(w) " " ~ reach) return 1
          if (k > 1 && (w !~ /\// || w ~ PROG) \
              && base(CLW[cl, 1]) !~ NAMES \
              && " " base(w) " " ~ reach) return 1
        }
      }
      return HC_SSHN > 1
    }
    {
      n = hc_segments($0, RAW)
      for (si = 1; si <= n; si++) {
        t = hc_clean(RAW[si])
        nw = hc_words(t, v)
        if (nw < 1) continue
        i0 = hc_skip_prefix(v, 1, nw)
        nd = i0 > nw ? 0 : hc_dest(v, i0, nw, D)
        # Local: no destination, and nothing in it that reaches past
        # this machine.
        if (loc == 1 && nd == 0 && RAW[si] !~ reach) continue
        if (nd == 1 && HC_AT > 0 && index(names, " " D[1] " ") > 0) {
          # Toward the named host: what stays is what the segment
          # writes on this machine, unless it reaches on from there,
          # or a redirection target is quoted.
          if (!onward(t)) {
            HC_REDIRS = ""; HC_REDIR_OPEN = 0
            hc_clean(nobody(RAW[si]))
            if (!HC_REDIR_OPEN) { printf "%s", HC_REDIRS; continue }
          }
        }
        print RAW[si]
      }
    }'
}
