# guard-taboos.d/identity.awk — reads a command line for an SSH call
# that would log in with another key than Hostwarden's own identity.
# Run by guard-taboos.d/identity.sh on the whole command, as one
# record (RS is set to a byte no command holds); never on its own.
# cfg and cfg2 are this checkout's memory/ssh_config, by its physical
# and its logical path.
#
# Prints the first reason found, one word and the text it is about,
# and nothing for a command that passes:
#
#   key <path>      a private key file under .ssh named id_*
#   i               ssh, scp or sftp with -i
#   A               ssh, scp or sftp with -A
#   S               scp or sftp with -S, another program as ssh
#   opt <keyword>   -o IdentityFile, IdentityAgent, IdentitiesOnly, or
#                   ForwardAgent other than no
#   F <file>        no -F, or one that is not cfg ("-" for none)
#   rsync           rsync to a remote without -e or --rsh
#
# The words are read the way the shell splits them: quotes kept
# together and removed, a backslash escaping the next character,
# segments cut at an unquoted ; & | ( ) ` or line break. A program
# is found at the start of a segment, past assignments, the shell's
# reserved words and the wrappers below; a value that is itself a
# command line (rsync -e, ProxyCommand, sh -c, a $( ) inside a word)
# is read the same way. ssh takes options after its destination too,
# up to the first word of its remote command. That command, and the
# body of a here-document, run where their consumer sends them,
# mostly on the host, which uses its own keys: they are not read. A
# backstop, not a parser: eval, a variable, a script file or a local
# shell reading a here-document reach past it.

function deny(why) { print why; exit }

function base(w,   b) { b = w; sub(/.*\//, "", b); sub(/\.exe$/, "", b); return b }

# skipbody(s, i, n) — s[i] is the line break after a line that opened
# here-documents: the index of the line break that ends the last of
# their bodies, or n + 1 where one has no closing line.
function skipbody(s, i, n, nh, hdelim, hdash,   h, e, line) {
  for (h = 1; h <= nh; h++) {
    for (;;) {
      if (i > n) return n + 1
      e = index(substr(s, i + 1), "\n")
      line = e ? substr(s, i + 1, e - 1) : substr(s, i + 1)
      i = e ? i + e : n + 1
      if (hdash[h]) sub(/^\t+/, "", line)
      if (line == hdelim[h]) break
    }
  }
  return i
}

# scan(s) — every segment of s, each split into words.
function scan(s,   n, i, c, q, w, inw, nw, W, j, d, nh, hdelim, hdash, e, depth, ch) {
  n = length(s); q = ""; w = ""; inw = 0; nw = 0; nh = 0
  for (i = 1; i <= n + 1; i++) {
    c = (i <= n) ? substr(s, i, 1) : "\n"
    if (q == "'") { if (c == "'") q = ""; else w = w c; continue }
    if (c == "\\" && i < n) {
      i++; c = substr(s, i, 1)
      if (c != "\n") { w = w c; inw = 1 }
      continue
    }
    if (q == "\"") {
      # A command substitution inside double quotes runs here: read
      # it as a command line of its own.
      if (c == "`") {
        e = index(substr(s, i + 1), "`")
        if (e) { scan(substr(s, i + 1, e - 1)); i += e; continue }
      } else if (c == "$" && substr(s, i + 1, 1) == "(") {
        depth = 1
        for (j = i + 2; j <= n; j++) {
          ch = substr(s, j, 1)
          if (ch == "(") depth++
          else if (ch == ")" && --depth == 0) break
        }
        scan(substr(s, i + 2, j - i - 2)); i = j; continue
      }
      if (c == "\"") q = ""; else w = w c
      continue
    }
    if (c == "'" || c == "\"") { q = c; inw = 1; continue }
    # A here-document: its delimiter, quotes taken off, and whether
    # <<- strips leading tabs from the closing line.
    if (c == "<" && substr(s, i, 2) == "<<" && substr(s, i, 3) != "<<<") {
      j = i + 2
      hdash[nh + 1] = (substr(s, j, 1) == "-")
      if (hdash[nh + 1]) j++
      while (substr(s, j, 1) ~ /[ \t]/) j++
      d = substr(s, j)
      if (match(d, /^[^ \t\n;&|()<>]+/)) {
        d = substr(d, 1, RLENGTH)
        i = j + length(d) - 1
        gsub(/["'\\]/, "", d)
        hdelim[++nh] = d
        continue
      }
    }
    if (c ~ /[ \t;&|()`\n]/) {
      if (inw) { W[++nw] = w; w = ""; inw = 0 }
      if (c ~ /[;&|()`\n]/ && nw) {
        segment(W, nw)
        for (j = 1; j <= nw; j++) delete W[j]
        nw = 0
      }
      if (c == "\n" && nh) { i = skipbody(s, i, n, nh, hdelim, hdash); nh = 0 }
      continue
    }
    w = w c; inw = 1
  }
}

function segment(W, n,   p, b, j, t) {
  p = 1
  while (p <= n) {
    b = base(W[p])
    if (W[p] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ ||
        W[p] ~ /^(!|\{|do|then|else|elif|if|while|until)$/) { p++; continue }
    if (b ~ /^(sudo|doas|env|nohup|exec|command|nice|time|stdbuf|xargs)$/) {
      p++
      while (p <= n && W[p] ~ /^-/)
        p += ((b ~ /^(sudo|doas)$/ && W[p] ~ /^-[ugCDhpRrTU]$/) ||
              (b == "xargs" && W[p] ~ /^-[IinPLdEsa]$/)) ? 2 : 1
      continue
    }
    if (b == "timeout") {
      p++
      while (p <= n && W[p] ~ /^-/) p++
      p++
      continue
    }
    break
  }
  if (p > n) return
  b = base(W[p])
  # A private key under .ssh, named id_* and not ending in .pub, which
  # covers id_*-cert.pub too, on a command that runs here. stat and ls
  # read the file's metadata, not the key. For ssh only a redirect
  # target counts: the words of its remote command run on the host.
  if (b != "stat" && b != "ls")
    for (j = p + 1; j <= n; j++) {
      t = W[j]
      if (b == "ssh") {
        if (t ~ /^<[^<]/) t = substr(t, 2)
        else if (j == 1 || W[j - 1] != "<") continue
      }
      if (match(t, /\.ssh\/+id_[^ \t]*/) &&
          substr(t, RSTART, RLENGTH) !~ /\.pub$/)
        deny("key " substr(t, RSTART, RLENGTH))
    }
  if (b == "ssh" || b == "scp" || b == "sftp") { sshcall(W, p + 1, n, b); return }
  if (b == "rsync") rsynccall(W, p + 1, n)
  else if (b ~ /^(sh|bash|dash|zsh|ksh)$/)
    for (j = p + 1; j < n; j++)
      if (W[j] ~ /^-[A-Za-z]*c[A-Za-z]*$/) { scan(W[j + 1]); break }
}

# checkopt(v) — the value of one -o.
function checkopt(v,   k, rest) {
  k = v; sub(/[ \t=].*/, "", k); k = tolower(k)
  rest = v; sub(/^[^ \t=]*[ \t=]*/, "", rest)
  if (k == "identityfile" || k == "identityagent" || k == "identitiesonly")
    deny("opt " k)
  if (k == "forwardagent" && tolower(rest) != "no") deny("opt " k)
  if (k == "proxycommand") scan(rest)
}

# isconfig(f) — f names this checkout's memory/ssh_config: by its
# physical or logical path, after a ~/ or $HOME/ the shell expands.
function isconfig(f,   h) {
  h = ENVIRON["HOME"]
  if (h != "") {
    if (substr(f, 1, 2) == "~/") f = h substr(f, 2)
    else if (substr(f, 1, 6) == "$HOME/") f = h substr(f, 6)
    else if (substr(f, 1, 8) == "${HOME}/") f = h substr(f, 8)
  }
  return f == cfg || f == cfg2
}

function sshcall(W, i, n, prog,   arg, w, k, c, val, hasF, fval, ctl, op, info, dest) {
  if (prog == "ssh") arg = "BbcDEeFIiJLlmOoPpQRSWw"
  else if (prog == "scp") arg = "cDFiJlmoPSX"
  else arg = "BbcDFiJloPRSsX"
  hasF = 0; fval = ""; ctl = 0; op = ""; info = 0; dest = 0
  for (; i <= n; i++) {
    w = W[i]
    if (w == "--") break
    if (w !~ /^-./) {
      # ssh reads options after its destination, up to its command.
      if (prog == "ssh" && !dest) { dest = 1; continue }
      break
    }
    for (k = 2; k <= length(w); k++) {
      c = substr(w, k, 1)
      if (c == "A") deny("A")
      if (prog == "ssh" && c ~ /[VGQ]/) info = 1
      if (index(arg, c)) {
        val = substr(w, k + 1)
        if (val == "" && i < n) val = W[++i]
        if (c == "i") deny("i")
        if (c == "o") checkopt(val)
        if (c == "F") { hasF = 1; fval = val }
        if (c == "S") { if (prog == "ssh") ctl = 1; else deny("S") }
        if (c == "O") op = val
        break
      }
    }
  }
  # -V, -G and -Q log in nowhere. The one call without this
  # checkout's file is a control command to a master by its socket,
  # which authenticates nothing (rules/ssh-config.md → Port
  # Forwardings).
  if (info) return
  if (hasF && isconfig(fval)) return
  if (prog == "ssh" && fval == "/dev/null" && ctl && op ~ /^(forward|cancel|check|exit)$/) return
  deny("F " (hasF ? fval : "-"))
}

function rsynccall(W, i, n,   w, v, remote) {
  remote = 0
  for (; i <= n; i++) {
    w = W[i]
    v = ""
    if (w == "-e" || w == "--rsh") { if (i < n) v = W[++i] }
    else if (w ~ /^--rsh=/) v = substr(w, 7)
    else if (w ~ /^-[A-Za-z0-9]*e$/) { if (i < n) v = W[++i] }
    else if (w !~ /^-/ && w !~ /^rsync:\/\// && w !~ /::/ && w ~ /^[^\/]*[^\/\\]:/) remote = 1
    if (v != "") { scan(v); return }
  }
  if (remote) deny("rsync")
}

{ scan($0) }
