#!/bin/sh
# guard-mode.sh — PreToolUse hook (matcher: Bash|Edit|Write|
# MultiEdit|NotebookEdit).
#
# Holds a session to the mode mode.sh determines:
#
#   development, worktree — ssh, scp, sftp, mosh, rsync to a
#     remote, sudo, sudoedit, doas and pkexec are denied wherever
#     they stand as a command, find -exec included. Local
#     administration counts: hostwarden's local mode is server
#     work too.
#   operations — Edit and Write are denied on any path inside
#     the checkout that git does not ignore, so memory/ and the
#     user's own files (.claude/settings.local.json) stay
#     writable. A local commit on main would also stop the
#     auto-update, which only fast-forwards.
#
# Unlike guard-taboos.sh, HOSTWARDEN_GUARD_DISABLE does not
# touch this one. That variable exists for installing an
# operating system, which is operations work and never needs
# either of the rules here.
#
# What it deliberately does NOT do:
#   - Stop a shell write in operations (sed -i, a redirect). The
#     set of shell writers cannot be closed; Edit and Write are
#     how an agent changes a file, and the prose in AGENTS.md
#     covers the rest.
#   - Treat a quoted argument as a command. Unlike the taboo
#     guard, which splits on quotes and so blocks grep 'fdisk',
#     this one reads quotes as the shell does: grep 'ssh' and a
#     commit message about sudo pass, because developing an SSH
#     tool means writing about ssh all day. The quoted forms
#     that do run something — bash -c, eval, $( ) inside double
#     quotes — are still read as commands.
#   - Look inside a variable or a script file. A backstop against
#     the everyday mistake, not a sandbox.
#
# It runs on every tool call, so it forks little: in development
# nothing at all unless the input names a blocked tool, and then
# one jq for the whole input and one awk for the command.
#
# Being blocked is EXPECTED behavior. Explain it to the user.
# Never rephrase, re-quote, or otherwise obfuscate a command to
# evade this guard.

ROOT=${0%/*}/../..
# shellcheck source=mode.sh
. "$ROOT/.claude/hooks/mode.sh"
hostwarden_mode "$ROOT"

INPUT=$(cat)

deny() {
  # JSON decision on stdout; blocks in all permission modes.
  # Reasons must stay plain ASCII without quotes/backslashes.
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
  printf '"permissionDecision":"deny",'
  printf '"permissionDecisionReason":"hostwarden mode guard: %s ' "$1"
  printf '(AGENTS.md - Development or Operations). Blocked in all '
  printf 'permission modes. Explain this to the user; do not '
  printf 'rephrase the command or pick another tool to evade the '
  printf 'guard."}}\n'
  exit 0
}

# Before anything is parsed: in development, input that names
# none of the blocked tools anywhere cannot invoke one. That is
# nearly every call, and it ends here without a single process.
if [ "$HOSTWARDEN_MODE" != operations ]; then
  case "$INPUT" in
  *ssh*|*scp*|*sftp*|*mosh*|*sudo*|*doas*|*pkexec*|*rsync*) ;;
  *) exit 0 ;;
  esac
fi

# Every field in one jq call, as shell assignments @sh has
# quoted. Without jq, sed reads the simple string fields — a
# JSON string without quotes or backslashes in it — and what it
# cannot read, the guard refuses rather than passes.
TOOL="" P="" WD="" CMD="" JQ=1
if command -v jq >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | jq -r '@sh "TOOL=\(.tool_name // "")
    P=\(.tool_input.file_path // .tool_input.notebook_path // "")
    WD=\(.cwd // "") CMD=\(.tool_input.command // "")"' 2>/dev/null)"
else
  JQ=
  # field <name> — the value of "name":"...", when it is simple.
  field() {
    printf '%s' "$INPUT" | tr '\n' ' ' | sed -n \
      "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\\([^\"\\\\]*\\)\".*/\\1/p"
  }
  TOOL=$(field tool_name)
  P=$(field file_path)
  [ -n "$P" ] || P=$(field notebook_path)
  WD=$(field cwd)
fi

if [ "$HOSTWARDEN_MODE" = operations ]; then
  # --- Operations: the shipped files are read-only ----------
  case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  *) exit 0 ;;
  esac
  if [ -z "$P" ]; then
    [ -n "$JQ" ] && exit 0
    deny "without jq the path of this edit cannot be read, so it \
cannot be shown to stay inside memory/ - install jq"
  fi
  case "$P" in
  /*) ;;
  *) P="$WD/$P" ;;
  esac
  # Resolve both sides physically, so a symlinked checkout path
  # or a .. segment cannot walk around the comparison. A file
  # that does not exist yet is judged by the directory it would
  # be created in.
  ROOT=$(cd "$ROOT" && pwd -P)
  D=${P%/*} B=${P##*/}
  while [ ! -d "${D:-/}" ]; do
    B="${D##*/}/$B" D=${D%/*}
  done
  REAL="$(cd "${D:-/}" && pwd -P)/$B"
  # An existing link as the last component is followed too: an
  # edit writes through it, so memory/x -> ../rules/y is rules/y.
  # Bounded, so a loop of links cannot hold the hook.
  n=0
  while [ -L "$REAL" ] && [ $n -lt 10 ]; do
    L=$(readlink "$REAL")
    case "$L" in /*) ;; *) L="${REAL%/*}/$L" ;; esac
    D=${L%/*} B=${L##*/}
    REAL="$(cd "${D:-/}" 2>/dev/null && pwd -P)/$B"
    n=$((n + 1))
  done
  # A .. after a directory that does not exist stays unresolved,
  # and memory/nosuch/../../rules/x would pass for a path under
  # memory/. Inside the checkout, such a path counts as shipped.
  case "/$B/" in
  */../*)
    case "$REAL" in "$ROOT"/*) REAL="$ROOT/${B##*../}" ;; esac
    ;;
  esac
  case "$REAL" in
  "$ROOT"/memory/*) exit 0 ;;
  "$ROOT"/*) ;;
  *) exit 0 ;;
  esac
  REL=${REAL#"$ROOT"/}
  # Ignored means the user's own: local settings, history.
  # Everything else is what hostwarden ships.
  if git -C "$ROOT" check-ignore -q --no-index -- "$REL" 2>/dev/null
  then
    exit 0
  fi
  deny "this checkout operates servers, so the files hostwarden \
ships are read-only here - $REL is one of them. Only memory/ \
and other gitignored files may change. Make the change in a \
development checkout, a separate clone of hostwarden or of your \
fork, and send it as a pull request"
fi

# --- Development: no server is reached ------------------------
case "$TOOL" in
Bash|"") ;;
*) exit 0 ;;
esac
[ -n "$CMD" ] || CMD="$INPUT"
# Without jq the command is buried in JSON, and it names a
# blocked tool (the prefilter above). Refuse rather than guess.
[ -n "$JQ" ] || deny "without jq this command cannot be read, and \
it names a tool that reaches a server - install jq"

# A heredoc body handed to cat or tee is text being written, not
# commands: documentation about ssh is most of what this project
# writes. Only that consumer is recognized, the same boundary the
# taboo guard draws; ssh host bash -s <<EOF keeps its body.
case "$CMD" in
*'<<'*)
  CMD=$(printf '%s\n' "$CMD" | awk '
    NR == 1 {
      print
      # Only when the line does nothing else: cat <<EOF | bash
      # runs its body.
      if ($0 ~ /^[ \t]*(cat|tee)([ \t]|$)/ && $0 !~ /[|;&`]|\$\(/ && match($0, /<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
        d = substr($0, RSTART, RLENGTH)
        sub(/^<<-?[ \t]*["\047]?/, "", d)
        body = 1
      }
      next
    }
    body { t = $0; sub(/^\t+/, "", t); if (t == d) body = 0; next }
    { print }')
  ;;
esac

# Quoted text is an argument, and an argument is data: grep
# 'ssh' and git commit -m "sudo ..." reach nothing. It becomes a
# placeholder, with two exceptions that run it as a command: the
# argument of -c (bash -c "ssh host") or eval, and whatever
# follows $( or a backtick inside double quotes.
#
# Then one line per invocation — split on the shell's separators
# and on command substitution — and the command word of each,
# past a negation, variable assignments and wrappers that run
# their argument, path stripped. The first blocked one is
# printed.
BLOCKED=$(printf '%s' "$CMD" | awk '
  function lastword(t) {
    sub(/[ \t]+$/, "", t)
    return match(t, /[^ \t\n;&|(]*$/) ? substr(t, RSTART, RLENGTH) : ""
  }
  BEGIN {
    RS = "\001"; q = sprintf("%c", 39)
    # Options of a wrapper that take the next word as their value,
    # so that word is not mistaken for the wrapped command.
    # Short and long spellings; --opt=value is one word anyway.
    split("env -u|env --unset|env -C|env --chdir|env -S|env --split-string|timeout -s|timeout --signal|timeout -k|timeout --kill-after|stdbuf -i|stdbuf --input|stdbuf -o|stdbuf --output|stdbuf -e|stdbuf --error|nice -n|nice --adjustment|xargs -I|xargs -n|xargs --max-args|xargs -P|xargs --max-procs|xargs -L|xargs --max-lines|xargs -d|xargs --delimiter|xargs -E|xargs -s|xargs --max-chars|xargs -a|xargs --arg-file", a, "|")
    for (k in a) takes[a[k]] = 1
  }
  { s = s $0 }
  END {
    n = length(s); i = 1; out = ""
    while (i <= n) {
      ch = substr(s, i, 1)
      if (ch == "\\") { out = out substr(s, i, 2); i += 2; continue }
      if (ch != q && ch != "\"") { out = out ch; i++; continue }
      j = i + 1; body = ""
      while (j <= n) {
        c = substr(s, j, 1)
        if (ch == "\"" && c == "\\") { body = body substr(s, j, 2); j += 2; continue }
        if (c == ch) break
        body = body c; j++
      }
      w = lastword(out)
      # -c alone or ending a cluster of short options (sh -ec).
      if (w ~ /^-[A-Za-z]*c$/ || w == "eval") {
        out = out "\n" body "\n"
      } else {
        # The placeholder keeps what makes an rsync operand remote:
        # "host:/path" and "rsync://host/..." reach a server quoted
        # or not.
        if (body ~ /^rsync:\/\//) out = out "rsync://Q"
        else if (body ~ /^[^ \/:-][^ \/:]*::?/) out = out "Q:"
        else out = out "Q"
        if (ch == "\"") {
          k = index(body, "$(")
          if (!k) k = index(body, "`")
          if (k) out = out "\n" substr(body, k + 1) "\n"
        }
      }
      i = j + 1
    }
    gsub(/[;&|()`{}]/, "\n", out)
    nl = split(out, line, "\n")
    for (l = 1; l <= nl; l++) {
      nw = split(line[l], v, /[ \t]+/)
      i = 1
      while (i <= nw && v[i] == "") i++
      while (i <= nw) {
        x = v[i]
        if (x == "!" || x == "$" || x ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { i++; continue }
        if (x ~ /^(env|command|exec|nohup|time|nice|timeout|xargs|stdbuf|caffeinate|if|elif|while|until|then|do|else)$/) {
          i++
          # flags and numeric arguments of the wrapper itself,
          # and the value of a flag that takes one
          while (i <= nw && (v[i] ~ /^-/ || v[i] ~ /^[0-9.]+[smhd]?$/)) {
            if ((x " " v[i]) in takes) i++
            i++
          }
          continue
        }
        break
      }
      if (i > nw) continue
      c = v[i]
      sub(/^.*\//, "", c)
      if (c ~ /^(ssh|scp|sftp|mosh|sudo|sudoedit|doas|pkexec)$/) { print c; exit }
      # find runs the word after -exec and its kin as a command.
      if (c == "find") {
        for (j = i + 1; j < nw; j++) {
          if (v[j] ~ /^-(exec|execdir|ok|okdir)$/) {
            e = v[j + 1]; sub(/^.*\//, "", e)
            if (e ~ /^(ssh|scp|sftp|mosh|sudo|sudoedit|doas|pkexec|rsync)$/) { print e; exit }
          }
        }
      }
      # rsync is fine between local paths. It reaches a server
      # through a remote shell (-e, --rsh), a host:path operand
      # or an rsync:// URL.
      if (c == "rsync") {
        for (j = i + 1; j <= nw; j++) {
          if (v[j] ~ /^(-e|--rsh)/ || v[j] ~ /^[^\/:-][^\/:]*::?/ || v[j] ~ /^rsync:\/\//) {
            print "rsync to a remote"; exit
          }
        }
      }
    }
  }')

[ -n "$BLOCKED" ] || exit 0

if [ "$HOSTWARDEN_MODE" = worktree ]; then
  deny "$BLOCKED reaches a server, and this session runs in a \
linked git worktree. A worktree never carries memory/, so the \
access lists and the server memory are missing here. Server work \
runs only in the main checkout of an operations install"
fi
deny "$BLOCKED reaches a server, and this checkout develops \
hostwarden (memory/ holds no workspace). Server work runs in an \
operations checkout: a separate clone, set up once with \
bin/hostwarden-init. For a tool on this machine, run the command \
yourself outside the agent"
