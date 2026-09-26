# shellcheck shell=sh
# coord-tokenize.sh — HOSTWARDEN_COORD_AWK, the awk tokenizer
# coord-lib.sh's readers of a command line share.
#
# Sourced, never executed, and always before coord-lib.sh, which
# refuses to load without it. Kept apart because it is the part of
# the coordination code that changes on its own: a new wrapper, a
# new quoting form, a new way to hide a segment boundary.
# Its matrix is tests/lib/coord-lib.sh.

# HOSTWARDEN_COORD_AWK — one tokenizer, shared, textually, by every
# awk program below that needs to read a command's words: awk has
# no way to link a function library across separate `awk '...'`
# invocations, so each of hostwarden_coord_dest,
# hostwarden_coord_is_reboot and hostwarden_coord_kind's own awk
# program is this text with its own BEGIN/main block appended,
# rather than three parsers hand-kept in sync (the fate `awk
# hops.sh`'s own SSHVAL comment already names, and the one issue
# #313 collects five bypass shapes against). Two passes, always
# together:
#
#   hc_segments(s, RAW) is hostwarden_coord_dest's own proven
#     splitter: s cut on an unquoted ;/&/|/(/)/{/}/`, with a
#     backslash escaping the very next character everywhere but
#     inside a single-quoted run, and an unquoted newline cut the
#     same way only when the caller sets HC_NL_SEP first — never
#     hostwarden_coord_dest's own top-level call, whose segment has
#     to stay whole, embedded newline and all, for a heredoc body to
#     still be there once hostwarden_coord_kind reads it in turn;
#     always hc_expand's own calls, where a multi-line remote
#     command — a heredoc's own body among them — is read the same
#     one-command-per-line way `;` already is. An unquoted << that
#     really opens a heredoc (hc_heredoc_span, matched the same
#     loose way hc_heredocs matches one) is never split on either,
#     whatever operator its own body carries, at every call — this
#     is what keeps a heredoc's body part of hostwarden_coord_dest's
#     own segment in the first place. An & right next to a < or >
#     (2>&1, >&2, bash's own &>file) duplicates or redirects a file
#     descriptor and is never a separator there, only a bare & (a
#     real background operator) is. RAW[1..n] keeps each
#     segment's own source text, quotes and all; hc_clean() (a
#     redirection and its target dropped, quote-aware — never inside
#     a quoted span, and never a << that might open a heredoc,
#     hc_dropredir — the ends trimmed) is what a caller reads or
#     hands to hc_words().
#
#   hc_words(s, W) is the real word reader hc_segments never was: a
#     single-quoted run is literal to its close; a double-quoted
#     run is literal except a backslash escapes the very next
#     character; a single quote inside a double-quoted run is an
#     ordinary character, never a quote of its own — the very thing
#     `sudo bash -c '…'` sent through an outer double-quoted ssh
#     argument needs; and two quoted spans with nothing between
#     them concatenate into the one word the shell would make of
#     them ('it'"'"'s' is "it's", never two words), because a word
#     only ends on real unquoted whitespace, never on a quote
#     closing.
#
# hc_skip_prefix(W, i, nw) reads past a leading `exec`, `busybox`,
# `sudo` or `doas` — a short value-taking option (SUCLASS's own
# letter, attached or its own separate word, hc_sudoadv) or a GNU
# long one of the same seven (SULONGVAL: --user, --group, --host,
# --chroot, --close-from, --command-timeout, --prompt, `man sudo`)
# skipped with its own separate value word, not only the
# `--name=value` form a bare "starts with -" skip already handles.
# hostwarden_coord_dest calls it too, since impact.sh's
# whole check gates on it finding a destination at all: `sudo ssh
# host reboot` is read the same as `ssh host reboot` there, not
# only by hc_classify.
#
# hc_classify(W, i, nw, depth) is what neither pass alone was: past
# hc_skip_prefix, for the word left:
#   - `ssh`/`sftp`: past its own destination-consuming options
#     (SSHVAL, hops.sh's own set, one place now), the remaining
#     words rejoined with a single space — the exact way `ssh`
#     itself hands several trailing arguments to the far shell
#     (`man ssh`) — and read again, one level deeper;
#   - `sh`/`bash`/`dash`/`ksh`/`zsh`/`ash -c`, `env`'s own
#     `-S`/`--split-string` (`env --help`: re-tokenizes its own
#     value the same way `-c` does), or `env`'s `VAR=val…`
#     assignments, `-C`/`--chdir` and `-u`/`--unset` (each skipped
#     with its own value word) to a `-c`/`-S` or a bare command: the
#     wrapped word (already the one dequoted word hc_words made of
#     it, whatever quoting carried it, or the text after
#     `--split-string=`) read again, one level deeper; a bare
#     command after `env` is read in place, no deeper;
#   - anything else: the words left are one clause, recorded for
#     hostwarden_coord_is_reboot's trig() and
#     hostwarden_coord_kind's own reading to judge.
# hc_expand(s, depth) is the loop: hc_segments then hc_clean then
# hc_words then hc_classify, on s, at depth; hc_classify calls it
# again on an ssh's rejoined remainder or a wrapper's own wrapped
# word, one depth deeper, up to MAXDEPTH — a generous eight, since
# a leading sudo/doas/exec/busybox chain of any length costs no
# depth of its own (hc_skip_prefix runs in a loop, not by
# recursing). Past MAXDEPTH the words still in hand, past one more
# hc_skip_prefix, are recorded as a clause rather than expanded
# further: a pathologically deep wrap chain is read shallow, its
# own outer wrapper words judged rather than nothing at all, but a
# disruptive command nested past the cap is not found — the same
# open limit a real, mechanical cap always leaves, and the reason
# `rules/coordination.md` → The hooks calls the prose in AGENTS.md
# the backstop a mechanical check cannot be. CLC/CLW/CLN are where
# record_clause() puts what hc_classify found; a caller resets CLC
# to 0, calls hc_expand once, then reads CLC clauses' worth of
# CLW[cl,1..CLN[cl]].
# shellcheck disable=SC2034 # read by coord-lib.sh
HOSTWARDEN_COORD_AWK='
function base(w) { sub(/^.*\//, "", w); return w }

# hc_heredoc_span(s, i) — s[i] is a < that opens <<[-]DELIM: the
# number of characters, from i, a real heredoc there spans through
# its own closing line, inclusive; 0 when no line below matches
# DELIM on its own, so it never was one. DELIM matched the same
# loose way hc_heredocs matches one.
function hc_heredoc_span(s, i,
    rest, mm, dd, ddash, nlpos, bodystart, brest, blen, p, nl2, lineend, line2, tline2) {
  rest = substr(s, i)
  if (!match(rest, "^<<-?[ \t]*[\047\"]?[A-Za-z_][A-Za-z0-9_]*")) return 0
  mm = substr(rest, RSTART, RLENGTH)
  dd = mm
  sub(/^<<-?[ \t]*/, "", dd)
  gsub("^[\047\"]|[\047\"]$", "", dd)
  ddash = (mm ~ /^<<-/)
  nlpos = index(rest, "\n")
  if (nlpos == 0) return 0
  bodystart = nlpos + 1
  brest = substr(rest, bodystart)
  blen = length(brest); p = 1
  while (p <= blen) {
    nl2 = index(substr(brest, p), "\n")
    if (nl2 > 0) { lineend = p + nl2 - 1; line2 = substr(brest, p, nl2 - 1) }
    else { lineend = blen; line2 = substr(brest, p) }
    tline2 = line2
    if (ddash) sub(/^\t+/, "", tline2)
    if (tline2 == dd) return bodystart - 1 + lineend
    if (nl2 == 0) break
    p = p + nl2
  }
  return 0
}

function hc_segments(s, RAW,
    i, c, qc, esc, cur, n, slen, span) {
  n = 1; cur = ""; qc = ""; esc = 0; slen = length(s)
  for (i = 1; i <= slen; i++) {
    c = substr(s, i, 1)
    if (esc) { cur = cur c; esc = 0; continue }
    if (c == "\\" && qc != "\047") { cur = cur c; esc = 1; continue }
    if (qc != "") {
      cur = cur c
      if (c == qc) qc = ""
      continue
    }
    if (c == "\"" || c == "\047") { qc = c; cur = cur c; continue }
    # An unquoted heredoc opener, real or (the safe, over-matching
    # direction) merely shaped like one: the whole span through its
    # own closing line is never split on an operator its own body
    # carries — it is not this segment own text to read that way,
    # only a caller that later recurses into it (hc_expand, its own
    # HC_NL_SEP set) reads its lines as commands of their own. Never
    # found means it was never a real one, and this < is read as
    # any other character; the next one gets its own, independent
    # look.
    if (c == "<" && substr(s, i, 2) == "<<" && substr(s, i, 3) != "<<<") {
      span = hc_heredoc_span(s, i)
      if (span > 0) { cur = cur substr(s, i, span); i += span - 1; continue }
    }
    # An & right next to a < or > (2>&1, >&2, &>file) duplicates or
    # redirects a file descriptor; it is never a separator there,
    # only the & that stands alone (a background job, a real
    # operator) is.
    if (c == "&" && ((length(cur) > 0 && substr(cur, length(cur), 1) ~ /[<>]/) \
        || substr(s, i + 1, 1) == ">")) {
      cur = cur c
      continue
    }
    if (index(";&|(){}`", c) > 0 || (c == "\n" && HC_NL_SEP)) {
      RAW[n] = cur; n++; cur = ""; continue
    }
    cur = cur c
  }
  RAW[n] = cur
  return n
}

function hc_dropredir(s,
    out, rest, matched) {
  # An optional & on either side of the </> run itself: >&2, 2>&1,
  # and bash own &>file/&>>file, on top of the plain 2>file every
  # redirection already reads as one dropped construct with hc_
  # segments own & exception keeping the whole thing one word to
  # find here in the first place. A match starting << is never one
  # of them: hc_heredocs, further down the same pipeline (called
  # before hc_segments in hc_expand, and hostwarden_coord_dest own
  # segment text is what hc_expand later reads too, through
  # impact.sh), is the only place that gets to decide whether it
  # opens a real heredoc — dropping it here first would hand that
  # function nothing to find, whether its own delimiter word
  # follows in this same unquoted span or, the documented quoted-
  # delimiter form, is about to open a quote of its own the caller
  # has not appended here yet.
  out = ""
  while (length(s) > 0) {
    if (!match(s, /[0-9]*&?[<>]+&?[ \t]*[^ \t<>]*/)) { out = out s; s = ""; break }
    out = out substr(s, 1, RSTART - 1)
    matched = substr(s, RSTART, RLENGTH)
    out = out (matched ~ /^<</ ? matched : " ")
    s = substr(s, RSTART + RLENGTH)
  }
  return out
}

# hc_clean(seg) drops a redirection and its target the same way it
# always has, but never inside a quoted span: a real heredoc body
# or an ordinary quoted argument can itself hold a < or > (a
# comparison, an arithmetic shift, redirection text meant for the
# far shell, not this local read) with no redirection meaning here
# at all, and hc_dropredir applied to it blindly would eat part of
# what a caller needs to read whole. Walks seg the same quote-aware
# way hc_segments does, running hc_dropredir on each unquoted span
# only; a quoted span is copied through untouched, quote characters
# and all, for hc_words to read afterwards. Its own quote/escape
# reading is a second copy of hc_segments own state machine, not a
# shared call — awk gives a function no way to walk a string and
# hand two different destinations back to its caller one character
# at a time — so a change to what hc_segments treats as a quote or
# an escape belongs here too, kept in sync by hand the same way
# hc_skip_prefix already names for SSHVAL and hops.sh.
function hc_clean(seg,
    out, i, c, qc, esc, slen, unq) {
  out = ""; unq = ""; qc = ""; esc = 0; slen = length(seg)
  for (i = 1; i <= slen; i++) {
    c = substr(seg, i, 1)
    if (esc) {
      if (qc == "") unq = unq c; else out = out c
      esc = 0; continue
    }
    if (c == "\\" && qc != "\047") {
      if (qc == "") unq = unq c; else out = out c
      esc = 1; continue
    }
    if (qc != "") {
      out = out c
      if (c == qc) qc = ""
      continue
    }
    if (c == "\"" || c == "\047") {
      out = out hc_dropredir(unq) c
      unq = ""
      qc = c
      continue
    }
    unq = unq c
  }
  out = out hc_dropredir(unq)
  gsub(/^[ \t]+|[ \t]+$/, "", out)
  return out
}

function hc_words(s, W,
    i, c, qc, cur, inw, n, slen) {
  n = 0; cur = ""; inw = 0; qc = ""; slen = length(s)
  for (i = 1; i <= slen; i++) {
    c = substr(s, i, 1)
    if (qc == "\047") {
      if (c == "\047") qc = ""
      else cur = cur c
      continue
    }
    if (qc == "\"") {
      if (c == "\"") qc = ""
      else if (c == "\\" && i < slen) { i++; cur = cur substr(s, i, 1) }
      else cur = cur c
      continue
    }
    if (c == "\\" && i < slen) { i++; cur = cur substr(s, i, 1); inw = 1; continue }
    if (c == "\047" || c == "\"") { qc = c; inw = 1; continue }
    if (c == " " || c == "\t") {
      if (inw) { n++; W[n] = cur; cur = ""; inw = 0 }
      continue
    }
    cur = cur c; inw = 1
  }
  if (inw) { n++; W[n] = cur }
  return n
}

function record_clause(W, i, nw,   k) {
  CLC++
  CLN[CLC] = nw - i + 1
  for (k = i; k <= nw; k++) CLW[CLC, k - i + 1] = W[k]
}

function joinw(w, i, n,    s, k) {
  s = w[i]
  for (k = i + 1; k <= n; k++) s = s " " w[k]
  return s
}

# hc_heredocs(s, depth) — s with every <<[-]DELIM…body…DELIM span
# (the rules/ssh-connections.md own `sh -s` bundling idiom — `ssh …
# host` then a quoted `sh -s`, then a quoted `<<EOS` heredoc marker
# — a whole multi-line here document as one Bash tool call) read
# out and each body handed to
# hc_expand in its own right, one depth deeper, so `systemctl
# restart nginx` inside it is read the same as it would be on an
# ordinary command line. Returns s with each such span collapsed to
# one space, for hc_segments to read what is left the usual way.
# DELIM is matched loosely — an identifier-shaped word, quoted or
# not, is enough, the exact quoting a real shell would need for it
# is not read — over-matching (the safe direction) at worst treats
# an ordinary "<<" mid-line (an arithmetic shift, a banner) as the
# start of one: it either finds a real terminator line further down
# (harmless: its body still gets read too) or none at all, and only
# then is this read back as never having been a heredoc to begin
# with — every line kept exactly as it was, not one of them lost,
# since losing everything past a false match would be a far worse
# fail-open than reading one construct wrong ever is. A <<< here-
# string is never mistaken for one: it never has an identifier-
# shaped word starting right at its own two <, only one line
# further in.
function hc_heredocs(s, depth,
    LN, nlines, i, line, pos, m, dashed, delim, pre, post, body, tline, j, found, out, qc) {
  # A single or double quote around DELIM, matched via a dynamic
  # (string-built) regex throughout this function rather than a
  # /.../ literal, since a literal quote character in the awk
  # source here would close the single-quoted shell string
  # HOSTWARDEN_COORD_AWK itself is written as.
  qc = "[\047\"]"
  nlines = split(s, LN, "\n")
  out = ""
  for (i = 1; i <= nlines; i++) {
    line = LN[i]
    pos = index(line, "<<")
    if (pos > 0 && substr(line, pos, 3) != "<<<" \
        && match(substr(line, pos), "^<<-?[ \t]*" qc "?[A-Za-z_][A-Za-z0-9_]*")) {
      m = substr(line, pos, RLENGTH)
      dashed = (m ~ /^<<-/)
      delim = m
      sub(/^<<-?[ \t]*/, "", delim)
      gsub("^" qc "|" qc "$", "", delim)
      pre = substr(line, 1, pos - 1)
      post = substr(line, pos + RLENGTH)
      gsub("^" qc "|" qc "$", "", post)
      body = ""; found = 0
      for (j = i + 1; j <= nlines; j++) {
        tline = LN[j]
        if (dashed) sub(/^\t+/, "", tline)
        if (tline == delim) { found = 1; break }
        body = body LN[j] "\n"
      }
      # No line below matches DELIM on its own: this was never a
      # real heredoc (an ordinary << in the text, arithmetic or
      # otherwise, with nothing to close it) — never assume it
      # swallowed the rest of the command, which is what actually
      # happened once and is a worse loss than misreading a single
      # word ever is. Every line, this one included, is left
      # exactly as it is, and the scan carries on from the next one
      # as if this line had never matched at all.
      if (found) {
        hc_expand(body, depth + 1)
        i = j
        out = out pre " " post "\n"
        continue
      }
    }
    out = out line "\n"
  }
  return out
}

function hc_expand(s, depth,    RAW2, nseg2, si2, cleaned2, W2, nw2, s2) {
  s2 = (index(s, "<<") > 0) ? hc_heredocs(s, depth) : s
  nseg2 = hc_segments(s2, RAW2)
  for (si2 = 1; si2 <= nseg2; si2++) {
    cleaned2 = hc_clean(RAW2[si2])
    if (cleaned2 == "") continue
    nw2 = hc_words(cleaned2, W2)
    if (nw2 < 1) continue
    hc_classify(W2, 1, nw2, depth)
  }
}

function hc_sudoadv(w,   n, k, ch) {
  # sudo lets a boolean short option cluster in front of a
  # value-taking one, man sudo own synopsis brackets them
  # together (sudo -nu root reboot really runs as root, -n and -u
  # clustered): the first SUCLASS letter (u,g,p,C,R,r,t,T,h,D) at
  # any position in w, not only the second, is the one that takes a
  # value — real getopt clustering never puts a second option after
  # one that already claimed the rest of the word as its own value.
  # Everything past that letter in the same word is its value (1,
  # attached); at the word own end, the value is the next word (2).
  # A word with no such letter anywhere takes no value at all (0) —
  # unlike a plain "ends in the class" match (SSHVAL own kind, →
  # hostwarden_coord_dest, left as it is: shared with hops.sh
  # identical pattern, a fix here alone would only add a second,
  # differently-behaving copy).
  n = length(w)
  for (k = 2; k <= n; k++) {
    ch = substr(w, k, 1)
    if (index(SUCLASS, ch) > 0) return (k == n) ? 2 : 1
  }
  return 0
}

# hc_skip_prefix(W, i, nw) — i, advanced past a leading `exec` or
# `busybox` (hops.sh own `cmd()` skips `exec` the same way) and a
# leading `sudo`/`doas` with its own options, value-taking ones
# (hc_sudoadv) skipped with their value, attached or separate:
# `sudo --user root reboot`, `sudo -u root reboot` and
# `sudo -uroot reboot` are all read the same as `sudo reboot`.
# Shared by hostwarden_coord_dest, which needs to see past this same
# prefix to find the ssh/sftp/scp/rsync call it wraps, and
# hc_classify, which reads on from there.
function hc_skip_prefix(W, i, nw,   c, changed, adv) {
  changed = 1
  while (changed && i <= nw) {
    changed = 0
    c = base(W[i])
    if (c == "exec" || c == "busybox") { i++; changed = 1; continue }
    if (c == "sudo" || c == "doas") {
      i++
      while (i <= nw && W[i] ~ /^-/) {
        if (W[i] ~ /^--[A-Za-z-]+=/) { i++; continue }
        if (W[i] ~ SULONGVAL) { i += 2; continue }
        adv = hc_sudoadv(W[i])
        if (adv > 0) { i += adv; continue }
        i++
      }
      changed = 1
      continue
    }
  }
  return i
}

function hc_classify(W, i, nw, depth,
    c, j, k, remote, envphase, foundc, script) {
  i = hc_skip_prefix(W, i, nw)
  if (i > nw) return
  if (depth > MAXDEPTH) { record_clause(W, i, nw); return }
  c = base(W[i])
  if (c == "ssh" || c == "sftp") {
    j = i + 1
    while (j <= nw) {
      if (W[j] == "--") { j++; break }
      if (W[j] ~ /^-/) { if (W[j] ~ SSHVAL) j += 2; else j++; continue }
      break
    }
    if (j > nw) return
    j++
    if (j > nw) return
    if (depth + 1 > MAXDEPTH) { record_clause(W, j, nw); return }
    remote = joinw(W, j, nw)
    hc_expand(remote, depth + 1)
    return
  }
  if (c == "sh" || c == "bash" || c == "dash" || c == "ksh" || c == "zsh" || c == "ash" || c == "env") {
    k = i + 1
    envphase = (c == "env")
    foundc = 0
    script = ""
    while (k <= nw) {
      if (envphase && W[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { k++; continue }
      if (W[k] == "-c" && k + 1 <= nw) { foundc = 1; script = W[k + 1]; break }
      # env own -S/--split-string re-tokenizes its value into a
      # wrapped command the same way -c does (`env --help`); -C and
      # -u (--chdir, --unset) take a value that is not a command
      # and is only skipped.
      if (envphase && (W[k] == "-S" || W[k] == "--split-string") && k + 1 <= nw) {
        foundc = 1; script = W[k + 1]; break
      }
      if (envphase && W[k] ~ /^--split-string=/) {
        foundc = 1; script = substr(W[k], 16); break
      }
      if (envphase && (W[k] == "-C" || W[k] == "--chdir" \
          || W[k] == "-u" || W[k] == "--unset")) { k += 2; continue }
      if (envphase && W[k] ~ /^(--chdir=|--unset=)/) { k++; continue }
      if (W[k] ~ /^-./) { k++; continue }
      break
    }
    if (foundc) {
      if (depth + 1 > MAXDEPTH) record_clause(W, k, nw)
      else hc_expand(script, depth + 1)
      return
    }
    if (envphase && k <= nw) { hc_classify(W, k, nw, depth); return }
  }
  record_clause(W, i, nw)
}

function trig(c, w, nw,   i) {
  if (c == "reboot") return 1
  if (c == "shutdown") {
    for (i = 2; i <= nw; i++) if (w[i] ~ /^-[A-Za-z]*r/) return 1
    return 0
  }
  if (c == "systemctl") return nw >= 2 && (w[2] == "reboot" || w[2] == "kexec")
  if (c == "qm" || c == "pct") return nw >= 2 && w[2] == "reboot"
  if (c == "kexec") {
    for (i = 2; i <= nw; i++) if (w[i] == "-e" || w[i] == "--exec") return 1
    return 0
  }
  return 0
}

function fw_match(s) {
  if (s ~ /nft -f /) return 1
  if (s ~ /nft flush ruleset/) return 1
  if (s ~ /nft delete table/) return 1
  if (s ~ /firewall-cmd.*-reload/) return 1
  if (s ~ /ufw enable/) return 1
  if (s ~ /ufw disable/) return 1
  if (s ~ /ufw reload/) return 1
  if (s ~ /pve-firewall.*restart/) return 1
  if (s ~ /pve-firewall compile/) return 1
  if (s ~ /netfilter-persistent/) return 1
  if (s ~ /iptables-restore/) return 1
  if (s ~ /ip6tables-restore/) return 1
  if (s ~ /pfctl -f /) return 1
  if (s ~ /pfctl -e/) return 1
  if (s ~ /pfctl -d/) return 1
  return 0
}

function net_match(s) {
  if (s ~ /ifreload/) return 1
  if (s ~ /netplan apply/) return 1
  if (s ~ /ifdown /) return 1
  if (s ~ /ifup /) return 1
  if (s ~ /ip link set.*down/) return 1
  if (s ~ /\/etc\/init\.d\/networking.*restart/) return 1
  if (s ~ /service networking.*restart/) return 1
  return 0
}

# restart_unit(w, nw, out) — the units w[1..nw] restarts, filling
# out[1..n] and returning n. `systemctl restart nginx postgresql`
# (systemctl(1): RESTART takes one or more units) fills out with
# both, never only the first; a global option before the verb
# (`systemctl --user restart nginx`, `-q`, `--no-ask-password`, …)
# is skipped the same way, rather than making the whole match miss.
function restart_unit(w, nw, out,   c0, i, j, n, u) {
  c0 = base(w[1])
  n = 0
  if (c0 == "systemctl") {
    i = 2
    while (i <= nw && w[i] ~ /^-/) i++
    if (i <= nw && (w[i] == "restart" || w[i] == "reload-or-restart")) {
      for (j = i + 1; j <= nw; j++) {
        if (w[j] ~ /^-/) continue
        n++; out[n] = w[j]
      }
    }
    return n
  }
  if (c0 == "service" && nw >= 3 && w[3] == "restart") { out[1] = w[2]; return 1 }
  if (c0 == "rc-service" && nw >= 3 && w[3] == "restart") { out[1] = w[2]; return 1 }
  if (c0 == "launchctl" && nw >= 2 && w[2] == "kickstart") {
    for (i = 3; i <= nw; i++) {
      if (w[i] ~ /^(gui\/[0-9]+|system)\//) {
        u = w[i]; sub(/^.*\//, "", u); out[1] = u; return 1
      }
    }
    return 0
  }
  if (c0 == "launchctl" && nw >= 3 && (w[2] == "stop" || w[2] == "start")) {
    out[1] = w[3]; return 1
  }
  return 0
}
'
