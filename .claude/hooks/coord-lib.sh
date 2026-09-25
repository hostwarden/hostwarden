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
#       HOSTWARDEN_COORD_AWK's shared tokenizer (→ below): a
#       segment's words are read by the same hc_segments/hc_clean/
#       hc_words hostwarden_coord_is_reboot and hostwarden_coord_kind
#       use, and a leading exec/busybox/sudo/doas is skipped the same
#       way (hc_skip_prefix) so `sudo ssh host reboot` is read the
#       same as `ssh host reboot` — impact.sh's whole check gates on
#       this function finding a destination at all, so a form it
#       cannot see past, unlike the other two, never reaches their
#       own, deeper reading of the remote text either. It does not
#       itself recurse into a wrapper's own remote or -c text for a
#       destination nested there; only hostwarden_coord_is_reboot and
#       hostwarden_coord_kind do that.
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
#       reboot` — built on HOSTWARDEN_COORD_AWK (→ below), the
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
#     splitter, unchanged: s cut on an unquoted ;/&/|/(/)/{/}/`,
#     with a backslash escaping the very next character everywhere
#     but inside a single-quoted run. RAW[1..n] keeps each
#     segment's own source text, quotes and all; hc_clean() (also
#     unchanged: a redirection and its target dropped, the ends
#     trimmed) is what a caller reads or hands to hc_words().
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
HOSTWARDEN_COORD_AWK='
function base(w) { sub(/^.*\//, "", w); return w }

function hc_segments(s, RAW,
    i, c, qc, esc, cur, n, slen) {
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
    # An & right next to a < or > (2>&1, >&2, &>file) duplicates or
    # redirects a file descriptor; it is never a separator there,
    # only the & that stands alone (a background job, a real
    # operator) is.
    if (c == "&" && ((length(cur) > 0 && substr(cur, length(cur), 1) ~ /[<>]/) \
        || substr(s, i + 1, 1) == ">")) {
      cur = cur c
      continue
    }
    # An unquoted newline ends a command the same way ; does (a
    # heredoc body, hc_heredocs own extracted text, is a script,
    # one command per line, not one long one); one right after a
    # backslash was already folded into the escaped character
    # above and never reaches here.
    if (index(";&|(){}`\n", c) > 0) { RAW[n] = cur; n++; cur = ""; continue }
    cur = cur c
  }
  RAW[n] = cur
  return n
}

function hc_dropredir(s) {
  # An optional & on either side of the </> run itself: >&2, 2>&1,
  # and bash own &>file/&>>file, on top of the plain 2>file every
  # redirection already reads as one dropped construct with hc_
  # segments own & exception keeping the whole thing one word to
  # find here in the first place.
  gsub(/[0-9]*&?[<>]+&?[ \t]*[^ \t<>]*/, " ", s)
  return s
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

hostwarden_coord_dest() {
  printf '%s' "$1" | awk "$HOSTWARDEN_COORD_AWK"'
    BEGIN {
      RS = "\001"
      # ssh/sftp short options that take a value of their own,
      # unless it is attached to the option letter — the exact set
      # .claude/hooks/hops.sh reads an ssh command line for, kept in
      # sync with it by hand: BbcDEeFIiJLlmOoPpQRSWw.
      SSHVAL = "^-[A-Za-z]*[BbcDEeFIiJLlmOoPpQRSWw]$"
      SUCLASS = "uUgpCRrtThD"
      SULONGVAL = "^--(user|group|host|chroot|close-from|command-timeout|prompt)$"
    }
    {
      n = hc_segments($0, RAW)
      for (si = 1; si <= n; si++) {
        t = hc_clean(RAW[si])
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
