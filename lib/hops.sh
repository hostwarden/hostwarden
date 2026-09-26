# shellcheck shell=sh
# hops.sh — the jump hosts a connection passes through, read from
# its `ssh -G` output, defined once: bin/hostwarden-fleet-run's
# blacklist check and bin/hostwarden-impact's radius both use it
# (rules/access-control.md → Server Blacklist says how each line is
# read).
#
# Sourced, never executed, so it carries no shebang and tells
# ShellCheck its dialect with the directive above instead.
#
# Defines:
#   hostwarden_hops <name> <config>
#       — reads the `ssh -G` output for <name>, the name as given,
#         on stdin, and prints each hop as <config>|<user>|<host>,
#         and !|| where the path cannot be read. <config> is the
#         file the hop's own `ssh -G` reads, as its caller writes
#         it: <config> itself for a ProxyJump hop, the file an ssh
#         in a ProxyCommand names with -F (empty for none: the
#         user's own configuration), and = for a host reached other
#         than by an ssh from here — a proxy, or what a jump host
#         goes on to — which is looked up by name alone. <user> is
#         the one the hop names, empty where it names none.
#
# ssh -G prints the proxyjump and proxycommand lines with their
# tokens unexpanded; ssh expands them from the target's own lines
# when it connects, and so does this. A caller reads each hop's own
# `ssh -G` in turn for the hops behind it, up to five deep.

hostwarden_hops() {
  N=$1 C=$2 awk '
  function expand(s,  o, i, c) {
    o = ""
    while ((i = index(s, "%")) > 0) {
      o = o substr(s, 1, i - 1); c = substr(s, i + 1, 1)
      if (c == "r") o = o v["user"]; else if (c == "h") o = o v["hostname"]
      else if (c == "p") o = o v["port"]; else if (c == "n") o = o ENVIRON["N"]
      else if (c == "%") o = o "%"; else o = o "%" c
      s = substr(s, i + 2)
    }
    return o s
  }
  # tok(s) — the words the shell makes of s, into w[]: quotes and
  # backslashes undone, a leading ~ expanded. A $, a backquote or an
  # operator the shell would act on first makes the path opaque.
  function tok(s,  n, i, c, q, cur, inw) {
    n = 0; cur = ""; inw = 0; q = ""
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (q == "\047") { if (c == "\047") q = ""; else cur = cur c; continue }
      if (q == "\"") {
        if (c == "\"") q = ""
        else if (c == "\\" && i < length(s)) cur = cur substr(s, ++i, 1)
        else { if (c == "$" || c == "`") opaque = 1; cur = cur c }
        continue
      }
      if (c == " " || c == "\t") { if (inw) w[++n] = cur; cur = ""; inw = 0; continue }
      if (c == "~" && !inw && (i == length(s) || substr(s, i + 1, 1) == "/")) {
        cur = ENVIRON["HOME"]; inw = 1; continue
      }
      inw = 1
      if (c == "\047" || c == "\"") q = c
      else if (c == "\\" && i < length(s)) cur = cur substr(s, ++i, 1)
      else { if (index("$`;|&<>()", c)) opaque = 1; cur = cur c }
    }
    if (inw) w[++n] = cur
    return n
  }
  # host(spec) — the host of [ssh://][user@]host[:port], a v6
  # address bare or as [v6]:port, without the port.
  function host(s) {
    sub(/^ssh:\/\//, "", s); sub(/.*@/, "", s)
    if (s ~ /^\[/) { sub(/^\[/, "", s); sub(/\].*/, "", s) }
    else if (s !~ /:.*:/) sub(/:[^:]*$/, "", s)
    return s
  }
  # hop(cfg, spec, user) — prints the hop; its user is the one named
  # first, that of the spec where none was.
  function hop(cfg, s, u,  h) {
    h = host(s); sub(/^ssh:\/\//, "", s)
    if (u == "" && s ~ /@/) { u = s; sub(/@[^@]*$/, "", u) }
    if (h == "" || h == "none") return
    if (h ~ /^[A-Za-z0-9_.:-]+$/) print cfg "|" u "|" h; else opaque = 1
  }
  # far(spec) — a host the stream goes on to or through by other
  # means than an ssh from here: a hop by name, unless it is the
  # target.
  function far(s,  h) {
    h = host(s)
    if (h != v["hostname"] && h != ENVIRON["N"]) hop("=", s, "")
  }
  function jumps(cfg, s,  a, n, i) {
    n = split(s, a, ",")
    for (i = 1; i <= n; i++) hop(cfg, a[i], "")
  }
  # opt(o) — a -o option of an ssh: where it goes, and as whom.
  function opt(o,  k, val) {
    k = o; val = ""
    if (match(o, /[ \t=]/)) {
      k = substr(o, 1, RSTART - 1); val = substr(o, RSTART + 1)
      sub(/^[ \t=]+/, "", val)
    }
    k = tolower(k)
    if (k == "proxyjump") ojump = ojump "," val
    else if (k == "hostname") ohost = val
    else if (k == "user" && user == "" && dest !~ /@/) user = val
    else if (k == "proxycommand") opaque = 1
  }
  # cmd(s) — the hops of one command line: an ssh, a proxy client
  # (nc, ncat, socat, connect) or nothing readable.
  function cmd(s,  n, i, p, a, c, o, cfg, r, k, f, x) {
    n = tok(s); i = 1
    if (w[i] == "exec") i++
    prog = w[i]; sub(/.*\//, "", prog)
    if (prog == "ssh") {
      # Its destination, the address -o HostName gives it, its -J or
      # -o ProxyJump hops, read with the file its -F names, else the
      # user configuration; a host its -W names; its remote command,
      # read the same way. The user is the one -l, -o User or user@
      # names first; options end at the first argument after the
      # destination that is not one.
      cfg = ""; user = ""; dest = ""; ojump = ""; ohost = ""
      for (i++; i <= n; i++) {
        a = w[i]
        if (a == "--") { if (dest == "") dest = w[++i]; i++; break }
        if (a !~ /^-./) { if (dest != "") break; dest = a; continue }
        for (p = 2; p <= length(a); p++) {
          c = substr(a, p, 1)
          if (!index("BbcDEeFIiJLlmOoPpQRSWw", c)) continue
          o = substr(a, p + 1); if (o == "") o = w[++i]
          if (c == "F") cfg = o
          else if (c == "l" && user == "" && dest !~ /@/) user = o
          else if (c == "J") ojump = ojump "," o
          else if (c == "o") opt(o)
          else if (c == "W") far(o)
          break
        }
      }
      if (dest == "") { opaque = 1; return }
      # An ssh a jump host runs reads its own configuration there.
      if (j > 1) cfg = "="
      sub(/^ssh:\/\//, "", dest)
      if (user == "" && dest ~ /@/) { user = dest; sub(/@[^@]*$/, "", user) }
      hop(cfg, dest, user)
      if (ohost != "") hop(cfg, ohost, user)
      jumps(cfg, ojump)
      if (i <= n) {
        r = w[i]; for (i++; i <= n; i++) r = r " " w[i]
        if (nq < 4) q[++nq] = r; else opaque = 1
      }
      return
    }
    if (prog == "nc" || prog == "ncat" || prog == "netcat" || prog == "connect") {
      # The proxy its -x or --proxy, or for connect -S, -H or -T,
      # names, and the host of its closing host and port. Short
      # options are read as getopt does: in a cluster, a letter that
      # takes a value takes the rest of the word, or the next one. A
      # connect without a proxy option takes one from the
      # environment, which is not here to read.
      vf = prog == "connect" ? "pSHTwRP" : "IiMmOPpqsTVwxX"
      pf = prog == "connect" ? "SHT" : "x"; px = 0
      for (i++; i <= n; i++) {
        a = w[i]
        if (a == "--proxy") { far(w[++i]); px = 1; continue }
        if (a ~ /^--proxy=/) { far(substr(a, 9)); px = 1; continue }
        if (a !~ /^-[^-]/) continue
        for (p = 2; p <= length(a); p++) {
          c = substr(a, p, 1)
          if (!index(vf, c)) continue
          o = substr(a, p + 1); if (o == "") o = w[++i]
          if (index(pf, c)) { far(o); px = 1 }
          break
        }
      }
      if (prog == "connect" && !px) opaque = 1
      if (n > 2 && w[n] ~ /^[0-9]+$/ && w[n - 1] !~ /^-/) far(w[n - 1])
      else opaque = 1
      return
    }
    if (prog == "socat") {
      # Each address: a proxy and the host behind it, or a host.
      for (i++; i <= n; i++) {
        a = w[i]
        if (a ~ /^-/ || a ~ /^[0-9]+$/) continue
        f = a; sub(/,.*/, "", f); k = f; sub(/:.*/, "", k); k = toupper(k)
        if (k == "STDIO" || k == "STDIN" || k == "STDOUT") continue
        if (f ~ /\[/) { opaque = 1; continue }
        split(f, x, ":")
        if (k ~ /^(PROXY|SOCKS4A?|SOCKS5)$/) { far(x[2]); far(x[3]) }
        else if (k ~ /^(TCP[46]?|OPENSSL|SSL)$/) far(x[2])
        else opaque = 1
      }
      return
    }
    opaque = 1
  }
  { k = $1; v[k] = substr($0, length(k) + 2) }
  END {
    C = ENVIRON["C"]
    jumps(C, expand(v["proxyjump"]))
    s = expand(v["proxycommand"])
    if (s != "" && s != "none") {
      nq = 1; q[1] = s
      for (j = 1; j <= nq; j++) cmd(q[j])
    }
    if (opaque) print "!||"
  }'
}
