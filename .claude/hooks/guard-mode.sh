#!/bin/sh
# guard-mode.sh — PreToolUse hook (matcher: Bash|Monitor|Edit|
# Write|MultiEdit|NotebookEdit).
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
#     changed PATH, rsync to a daemon (rsync:// or host::module,
#     which never starts ssh), and $GIT_SSH_COMMAND, git's
#     route to the real ssh (git-ssh.sh), used as a command. Local
#     administration counts: Hostwarden's local mode is server
#     work too. Under WSL the same goes for the Windows programs
#     the shim covers (ssh.exe, wsl.exe, powershell.exe and the
#     rest, shim.sh), in any spelling of their name: the drives
#     under /mnt ignore case, and the shim does not. A Monitor
#     command is a shell command and is read exactly as a Bash
#     one, and more: Claude Code documents the env file that
#     carries the shim for Bash only, so for Monitor this hook
#     also denies a blocked tool named without a path, where the
#     shim would have stood.
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
#   - Read quotes, wrappers or rsync operands over ssh. Every such case
#     reaches the tool through PATH, where the shim waits; a
#     parser for them never closes. Nor does it look for a bare
#     tool name in a Bash command, so grep ssh and a commit
#     message about sudo pass. Quotes are not masked: a commit
#     message that names /usr/bin/ssh, or changes PATH and
#     mentions ssh at all, is denied; either is rare.
#   - Look inside a variable or a script file. A backstop against
#     the everyday mistake, not a sandbox: eval $GIT_SSH_COMMAND
#     or a script that resets PATH still reaches ssh, and only
#     the prose in AGENTS.md stands against it. So does a bare
#     tool inside sh -c or a script that Monitor runs, wherever
#     the shim is not on its PATH.
#
# It runs on every tool call, so it forks little. In development
# nothing at all unless the input could hold one of the forms
# above, then one jq for the whole input and one awk for the
# command. In operations a Bash or Monitor call ends before jq;
# an edit runs one jq, and git only for a path outside memory/.
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
# permission modes. The message is escaped here, without jq, so it
# may carry a path or a piece of the command as it is; a control
# character, which JSON would need escaped too, becomes a space.
emit() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
  printf '"permissionDecision":"deny",'
  printf '"permissionDecisionReason":"%s Blocked in all ' \
    "$(printf '%s' "$1" | tr '\001-\037' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf 'permission modes. Explain this to the user; do not '
  printf 'rephrase the command or pick another tool to evade the '
  printf 'guard."}}\n'
  exit 0
}
deny() {
  emit "hostwarden mode guard: $1 (AGENTS.md - Development or Operations)."
}

# Before anything is parsed: in development only a Bash or Monitor
# call is read, and only its command, which cwd and the transcript
# path are not part of. A Bash command without a path to a blocked
# tool, command -p, a change to PATH or GIT_SSH_COMMAND holds none
# of the forms this hook denies. That is nearly every call, and it
# ends here without a single process. A Monitor call is rare and
# always goes on.
if [ "$HOSTWARDEN_MODE" != operations ]; then
  case "$INPUT" in
  *'"tool_name"'*'"Monitor"'*) ;;
  *'"tool_name"'*'"Bash"'*)
    case "${INPUT#*'"command"'}" in
    */ssh[!A-Za-z0-9_.-]*|*/scp[!A-Za-z0-9_.-]*|*/sftp[!A-Za-z0-9_.-]*) ;;
    */mosh[!A-Za-z0-9_.-]*|*/sudo[!A-Za-z0-9_.-]*|*/sudoedit[!A-Za-z0-9_.-]*) ;;
    */doas[!A-Za-z0-9_.-]*|*/pkexec[!A-Za-z0-9_.-]*|*command*-*p*) ;;
    # A Windows program, by path or by a spelling the shim misses.
    *.[Ee][Xx][Ee][!A-Za-z0-9_]*) ;;
    # In JSON a newline or tab before it is \n or \t, a letter too.
    *[!A-Za-z0-9_]PATH=*|*[!A-Za-z0-9_]path=*|*'unset PATH'*) ;;
    *\\[nt]PATH=*|*\\[nt]path=*) ;;
    *'env -'*|*rsync*::*|*rsync*'rsync://'*) ;;
    *GIT_SSH_COMMAND*) ;;
    *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
  esac
else
  # Operations restricts edits only, so a Bash or Monitor call ends
  # here. Inside the text of an edit every quote is escaped, so
  # these patterns can only match the tool name itself; anything
  # else goes on to jq.
  case "$INPUT" in
  *'"tool_name":"Bash"'*|*'"tool_name":"Monitor"'*) exit 0 ;;
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
  # Everything else is what Hostwarden ships.
  if git -C "$ROOT" check-ignore -q --no-index -- "$REL" 2>/dev/null
  then
    exit 0
  fi
  deny "this checkout operates servers, so the files Hostwarden \
ships are read-only here - $REL is one of them. Only memory/ \
and other gitignored files may change. Make the change in a \
development checkout, a separate clone of Hostwarden or of your \
fork, and send it as a pull request"
fi

# --- Development: no server is reached ------------------------
# A blocked tool named without a path is the shim's: it refuses
# wherever the tool is started from. This denies the ways past a
# PATH lookup:
#   - a Windows program from shim.sh as the first word of a
#     segment in any spelling but the shim's own (SSH.exe);
#   - a path to a blocked tool as the first word of a segment (split
#     on the shell's separators, past a negation and variable
#     assignments), or anywhere else when it names an executable
#     file: rsync -e /usr/bin/ssh, core.sshCommand=/usr/bin/ssh.
#     A path to a Windows program counts wherever it stands,
#     file or not, since Program Files splits it in two;
#   - $GIT_SSH_COMMAND at the start of a segment;
#   - command -p, which ignores PATH, anywhere in a command that
#     names a blocked tool, inside sh -c and eval strings too;
#   - a command that changes PATH (PATH=, zsh path=, unset PATH,
#     env -i or -, env -u PATH in its spellings) and names a
#     blocked tool anywhere;
#   - rsync with an rsync:// or host::module operand, which talks
#     to the daemon itself and never starts ssh;
#   - for Monitor, a blocked tool as the first word of a segment
#     even without a path, since the shim may not be on its PATH.
case "$TOOL" in
Bash|"") ;;
Monitor)
  # A WebSocket watch has no command and starts no shell. Without
  # jq CMD is never read, so that call is refused below instead.
  [ -z "$CMD" ] && [ -n "$JQ" ] && exit 0
  ;;
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
FOUND=$(printf '%s' "$CMD" | awk -v tool="$TOOL" '
  BEGIN {
    RS = "\001"
    T = "^(ssh|scp|sftp|mosh|sudo|sudoedit|doas|pkexec)$"
    # Windows programs, matched on the lowercased name.
    W = "^(ssh|scp|sftp|sudo|runas|wsl|powershell|pwsh|cmd)[.]exe$"
  }
  {
    s = $0
    # ${VAR} is a variable, not a brace group.
    gsub(/\$\{/, "$", s)
    gsub(/[;&|(){}`]/, "\n", s)
    n = split(s, seg, "\n")
    for (l = 1; l <= n; l++) {
      nw = split(seg[l], v, /[ \t]+/)
      # env: 1 while the words are options of an env command, 2 when
      # the next word is the value of -u, -C or -S.
      env = rsync = daemon = 0
      pc = ""
      for (i = 1; i <= nw; i++) {
        c = v[i]
        gsub(/^["\047]+|["\047]+$/, "", c)
        # command -p looks tools up on a default PATH, never the
        # shim: wherever it stands, sh -c and eval strings included.
        if (pc == "command" && c ~ /^-[A-Za-z]*p[A-Za-z]*$/ && c !~ /[vV]/) cmdp = 1
        pc = c
        if (env == 2) env = 1
        else if (env && c !~ /^-/ && c !~ /=/) env = 0
        # env -i, -iv, a lone -, --ignore-environment; env -u PATH,
        # -uPATH, --unset PATH, --unset=PATH; unset PATH.
        if (c ~ /^(PATH|path)=/ \
            || env && (c == "-" || c ~ /^-[A-Za-z]*i[A-Za-z]*$/ || c ~ /^--ignore-env/) \
            || env && c ~ /^(-u|--unset=)PATH$/ \
            || c == "PATH" && (v[i - 1] == "unset" || env && v[i - 1] ~ /^(-u|--unset)$/))
          setpath = 1
        if (env && c ~ /^(-[uCS]|--unset|--chdir|--split-string)$/) env = 2
        # rsync reaches a daemon itself, no ssh on the way:
        # rsync://host/module and host::module.
        if (c ~ /^rsync:\/\// || c ~ /^[^\/:=-][^\/:=]*::/) daemon = 1
        if (c ~ /(^|\/)rsync$/) rsync = 1
        if (c ~ /(^|\/)env$/) env = 1
        sub(/^.*=/, "", c)
        b = tolower(c)
        sub(/^.*\//, "", b)
        if (b ~ T || b ~ W) {
          if (named == "") named = b
          if (c ~ /\//) paths = paths "path " c "\n"
          # A Windows path is split wherever it holds a space
          # (Program Files), so its tail is no file to test.
          if (b ~ W && c ~ /\// && c !~ /\.claude\/hooks\/shim\//) {
            print "deny " b " by its path"; exit
          }
        }
      }
      if (rsync && daemon) { print "deny rsync to a daemon"; exit }
      i = 1
      # Past a negation, assignments and the keywords a command
      # can follow: while true; do ssh ...
      while (i <= nw && (v[i] == "" || v[i] ~ /^(!|do|then|else|elif|if|while|until|time)$/ || v[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/)) i++
      if (i > nw) continue
      w = v[i]
      # The real ssh that git push is given.
      if (w ~ /^"?\$GIT_SSH_COMMAND/) { print "deny ssh through GIT_SSH_COMMAND"; exit }
      # Past command and exec to the tool they run.
      how = ""
      if (w == "command" || w == "exec") {
        while (++i <= nw && v[i] ~ /^-/) ;
        if (i > nw) continue
        w = v[i]
      }
      c = w
      gsub(/^["\047]+|["\047]+$/, "", c)
      sub(/^.*\//, "", c)
      lc = tolower(c)
      if (lc !~ T && lc !~ W) continue
      if (w ~ /\//) how = "by its path"
      # A word that only ends in a quote is the tail of a quoted
      # string split at a | inside it: grep -E "error|ssh".
      else if (tool == "Monitor" && (w !~ /["\047]$/ || w ~ /^["\047]/)) how = "through Monitor"
      else if (c != lc) how = "spelled " c
      c = lc
      if (how != "") { print "deny " c " " how; exit }
    }
    if (cmdp && named != "") { print "deny " named " through command -p"; exit }
    if (setpath && named != "") { print "deny " named " with PATH changed"; exit }
    printf "%s", paths
  }')

BLOCKED=
case "$FOUND" in
"deny "*) BLOCKED=${FOUND#deny } ;;
*)
  # /etc/ssh is a directory, a path in a sentence names nothing,
  # and the shim only refuses.
  while IFS= read -r p; do
    p=${p#path }
    case "$p" in *.claude/hooks/shim/*) continue ;; esac
    if [ -f "$p" ] && [ -x "$p" ]; then
      BLOCKED="${p##*/} by its path"
      break
    fi
  done <<EOF
$FOUND
EOF
  ;;
esac
[ -n "$BLOCKED" ] || exit 0
hostwarden_refusal "$BLOCKED"
emit "$HOSTWARDEN_REFUSAL"
