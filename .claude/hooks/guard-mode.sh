#!/bin/sh
# guard-mode.sh — PreToolUse hook (matcher: Bash|Edit|Write|
# MultiEdit|NotebookEdit).
#
# Holds a session to the mode mode.sh determines:
#
#   development, worktree — ssh, scp, sftp, mosh, sudo, sudoedit,
#     doas and pkexec are refused. The shim does most of it
#     (shim.sh): session-mode.sh puts it first on PATH, so the
#     tools refuse wherever they are started from, rsync's own
#     ssh included. This hook denies the forms that go past a
#     PATH lookup: a path to the real binary (/usr/bin/ssh, also
#     as rsync -e or a core.sshCommand value), command -p, a
#     changed PATH, and $GIT_SSH_COMMAND, git's
#     route to the real ssh (git-ssh.sh), used as a command. Local
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
#   - Read quotes, wrappers or rsync operands. Every such case
#     reaches the tool through PATH, where the shim waits; a
#     parser for them never closes. Nor does it look for a bare
#     tool name, so grep ssh and a commit message about sudo
#     pass. Quotes are not masked: a commit message that names
#     /usr/bin/ssh, or changes PATH and mentions ssh at all, is
#     denied; either is rare.
#   - Look inside a variable or a script file. A backstop against
#     the everyday mistake, not a sandbox: eval $GIT_SSH_COMMAND
#     or a script that resets PATH still reaches ssh, and only
#     the prose in AGENTS.md stands against it.
#
# It runs on every tool call, so it forks little. In development
# nothing at all unless the input could hold one of the forms
# above, then one jq for the whole input and one awk for the
# command. In operations a Bash call ends before jq; an edit runs
# one jq, and git only for a path outside memory/.
#
# Being blocked is EXPECTED behavior. Explain it to the user.
# Never rephrase, re-quote, or otherwise obfuscate a command to
# evade this guard.

ROOT=${0%/*}/../..
# shellcheck source=mode.sh
. "$ROOT/.claude/hooks/mode.sh"
hostwarden_mode "$ROOT"

INPUT=$(cat)

# emit <message> — the JSON decision on stdout; blocks in all
# permission modes. Messages stay plain ASCII without quotes or
# backslashes.
emit() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
  printf '"permissionDecision":"deny",'
  printf '"permissionDecisionReason":"%s Blocked in all ' "$1"
  printf 'permission modes. Explain this to the user; do not '
  printf 'rephrase the command or pick another tool to evade the '
  printf 'guard."}}\n'
  exit 0
}
deny() {
  emit "hostwarden mode guard: $1 (AGENTS.md - Development or Operations)."
}

# Before anything is parsed: in development only a Bash call is
# read, and only its command, which cwd and the transcript path
# are not part of. A command without a path to a blocked tool,
# command -p, a change to PATH or GIT_SSH_COMMAND holds none of the
# forms this hook denies. That is nearly every call, and it ends
# here without a single process.
if [ "$HOSTWARDEN_MODE" != operations ]; then
  case "$INPUT" in
  *'"tool_name"'*'"Bash"'*) ;;
  *) exit 0 ;;
  esac
  case "${INPUT#*'"command"'}" in
  */ssh[!A-Za-z0-9_.-]*|*/scp[!A-Za-z0-9_.-]*|*/sftp[!A-Za-z0-9_.-]*) ;;
  */mosh[!A-Za-z0-9_.-]*|*/sudo[!A-Za-z0-9_.-]*|*/sudoedit[!A-Za-z0-9_.-]*) ;;
  */doas[!A-Za-z0-9_.-]*|*/pkexec[!A-Za-z0-9_.-]*|*'command -p'*) ;;
  *[!A-Za-z0-9_]PATH=*|*[!A-Za-z0-9_]path=*|*'unset PATH'*) ;;
  *'-u PATH'*|*'env -i'*|*ignore-environment*) ;;
  *GIT_SSH_COMMAND*) ;;
  *) exit 0 ;;
  esac
else
  # Operations restricts edits only, so a Bash call ends here. Inside
  # the text of an edit every quote is escaped, so this pattern can
  # only match the tool name itself; anything else goes on to jq.
  case "$INPUT" in
  *'"tool_name":"Bash"'*) exit 0 ;;
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
  # Still a link after ten steps: a loop, or a chain long enough
  # to hide where it ends. Either way it cannot be shown to stay
  # in memory/.
  [ -L "$REAL" ] && deny "this edit goes through a chain of links \
that does not end, so it cannot be shown to stay inside memory/"
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
# A blocked tool named without a path is the shim's: it refuses
# wherever the tool is started from. This denies the ways past a
# PATH lookup:
#   - a path to a blocked tool as the first word of a segment (split
#     on the shell's separators, past a negation and variable
#     assignments), or anywhere else when it names an executable
#     file: rsync -e /usr/bin/ssh, core.sshCommand=/usr/bin/ssh;
#   - command -p, and $GIT_SSH_COMMAND, at the start of a segment;
#   - a command that changes PATH (PATH=, zsh path=, unset PATH,
#     env -i, env -u PATH) and names a blocked tool anywhere.
case "$TOOL" in
Bash|"") ;;
*) exit 0 ;;
esac
# Without jq the command is buried in JSON, and it names one of
# those forms (the prefilter above). Refuse rather than guess.
[ -n "$JQ" ] || deny "without jq this command cannot be read, and \
it may start a tool that reaches a server - install jq"
# jq could not parse the input: scan it raw, which can only
# over-block.
[ -n "$CMD" ] || CMD="$INPUT"

# One line: "deny <what>" for a verdict, or "path <p>" for a path
# elsewhere in the command, which counts once it is a program.
FOUND=$(printf '%s' "$CMD" | awk '
  BEGIN { RS = "\001"; T = "^(ssh|scp|sftp|mosh|sudo|sudoedit|doas|pkexec)$" }
  {
    s = $0
    # ${VAR} is a variable, not a brace group.
    gsub(/\$\{/, "$", s)
    gsub(/[;&|(){}`]/, "\n", s)
    n = split(s, seg, "\n")
    for (l = 1; l <= n; l++) {
      nw = split(seg[l], v, /[ \t]+/)
      for (i = 1; i <= nw; i++) {
        c = v[i]
        gsub(/^["\047]+|["\047]+$/, "", c)
        if (c ~ /^(PATH|path)=/ || c == "--ignore-environment" \
            || c == "-i" && v[i - 1] == "env" \
            || c == "PATH" && (v[i - 1] == "unset" || v[i - 1] == "-u"))
          setpath = 1
        sub(/^.*=/, "", c)
        b = c
        sub(/^.*\//, "", b)
        if (b ~ T) {
          if (named == "") named = b
          if (c ~ /\// && path == "") path = c
        }
      }
      i = 1
      while (i <= nw && (v[i] == "" || v[i] == "!" || v[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/)) i++
      if (i > nw) continue
      w = v[i]
      # The real ssh that git push is given.
      if (w ~ /^"?\$GIT_SSH_COMMAND/) { print "deny ssh through GIT_SSH_COMMAND"; exit }
      # command -p looks the tool up on a default PATH, never the shim.
      how = ""
      if (w == "command" || w == "exec") {
        p = w == "command"
        while (++i <= nw && v[i] ~ /^-/)
          if (p && v[i] ~ /p/ && v[i] !~ /[vV]/) how = "through command -p"
        if (i > nw) continue
        w = v[i]
      }
      c = w
      sub(/^.*\//, "", c)
      if (c !~ T) continue
      if (w ~ /\//) how = "by its path"
      if (how != "") { print "deny " c " " how; exit }
    }
    if (setpath && named != "") { print "deny " named " with PATH changed"; exit }
    if (path != "") print "path " path
  }')

case "$FOUND" in
"deny "*) BLOCKED=${FOUND#deny } ;;
# /etc/ssh is a directory, a path in a sentence names nothing, and
# the shim only refuses.
"path "*.claude/hooks/shim/*) ;;
"path "*) [ -f "${FOUND#path }" ] && [ -x "${FOUND#path }" ] &&
  BLOCKED="${FOUND##*/} by its path" ;;
esac
[ -n "${BLOCKED:-}" ] || exit 0
hostwarden_refusal "$BLOCKED"
emit "$HOSTWARDEN_REFUSAL"
