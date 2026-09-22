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
#     Containers are allowed, as bin/hostwarden-lab starts them:
#     docker, podman and nerdctl may read, pull, build, run and
#     create on the local engine; --context, --host and their
#     variables (DOCKER_HOST, CONTAINER_HOST) reach another one,
#     a server, and are denied. A run or create is denied with an
#     option that reaches past the container into this machine —
#     --privileged, a host path as a volume or mount, a host
#     namespace, a device, an added capability, a lifted security
#     profile, a namespace of the host or of another container, a
#     published port, a host file or a host variable
#     read into it (--env-file, --label-file, -e NAME without a
#     value) — and so are a build that writes its result here
#     (--output, --iidfile, --metadata-file) or reads a secret,
#     the SSH agent or a host path (podman build -v) from here, a
#     compose file, a kube play and a volume over a host device,
#     which the guard cannot read.
#     Every other verb is denied: exec
#     reaches whatever container it names, a privileged one of
#     another project included, and rm, stop, prune and the rest
#     change containers the lab does not own. The lab's exec and
#     down run inside bin/hostwarden-lab, where only its own label
#     is used. On Linux the engine runs as root; on macOS a bind
#     mount reaches $HOME.
#     A lab VM is a test server of an operations clone, so orb,
#     orbctl, limactl and lima are denied where they run a command
#     in one or copy to or from it. Reading their state passes.
#     Creating one is denied: bin/hostwarden-lab vm up creates it
#     without this machine's files mounted, which orb and Lima do
#     by default, and records it for vm down. Deleting, stopping or
#     changing a VM is denied, since it may not be the lab's, and
#     bin/hostwarden-lab vm down deletes only the ones it created.
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
#     parser for them never closes. The one exception is the
#     command word, which it follows past a fixed set of launchers
#     (env, timeout, setsid ...): the shim misses SSH.EXE, and
#     Monitor may have no shim at all. Nor does it look for a bare
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
# tool, command -p, a change to PATH, GIT_SSH_COMMAND, a container
# engine or a VM manager holds none of the forms this hook denies.
# That is nearly every call, and it ends here without a single
# process. A Monitor call is rare and
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
    *docker*|*podman*|*nerdctl*|*orbctl*|*limactl*) ;;
    *[!A-Za-z0-9_.-]orb[!A-Za-z0-9_.-]*|*\\[nt]orb[!A-Za-z0-9_.-]*) ;;
    *[!A-Za-z0-9_.-]lima[!A-Za-z0-9_.-]*|*\\[nt]lima[!A-Za-z0-9_.-]*) ;;
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
#     on the shell's separators, past a negation, variable
#     assignments, redirections and launchers such as env,
#     timeout or setsid), or anywhere else when it names an executable
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

# One line: "deny <what>" for a verdict, "engine", "compose" or
# "vm <what>" for a container or lab VM, or "path <p>" for a path
# elsewhere in the command, which counts once it is a program.
#
# Containers and lab VMs: a container engine, orb, orbctl, limactl
# and lima count as the first word of a segment only, past the
# wrappers lab() names, sh -c among them, so grep orb docs/ and a
# commit message about docker rm are not. An engine's options are
# read to the end of that segment, where the words after the image
# are the container's command and can only over-block.
FOUND=$(printf '%s' "$CMD" | awk -v tool="$TOOL" '
  BEGIN {
    RS = "\001"
    T = "^(ssh|scp|sftp|mosh|sudo|sudoedit|doas|pkexec)$"
    # Windows programs, matched on the lowercased name.
    W = "^(ssh|scp|sftp|sudo|runas|wsl|powershell|pwsh|cmd)[.]exe$"
    # Launchers that run the rest of their line as a command. LA
    # holds the short options that take the next word as a value,
    # LL the long ones, LP how many operands come before the
    # command: the duration of timeout, the priority of chrt, the
    # mask of taskset, the lock file of flock. env -S is left out:
    # it takes the command itself, which the parse below then
    # reads as the next word, or as the rest of the word when it
    # is attached (-S"ssh h", --split-string=...). flock -c does
    # the same and is read the same way, wherever it stands.
    # builtin runs exec or command, which follow as launchers.
    LA["env"] = "uC"; LL["env"] = "unset|chdir"
    LA["nice"] = "n"; LL["nice"] = "adjustment"
    LA["timeout"] = "sk"; LL["timeout"] = "signal|kill-after"
    LP["timeout"] = 1
    LA["stdbuf"] = "ioe"; LL["stdbuf"] = "input|output|error"
    LA["time"] = "fo"; LL["time"] = "format|output"
    LA["caffeinate"] = "tw"
    # Only the long options whose value is required may stand apart
    # from it; --replace, --eof and --max-lines take theirs with =.
    LA["xargs"] = "adEIJLnPRSs"
    LL["xargs"] = "arg-file|delimiter|max-args|max-procs|max-chars|process-slot-var"
    LA["ionice"] = "cnpPu"; LL["ionice"] = "class|classdata|pid|pgid|uid"
    LA["chrt"] = "TPD"; LP["chrt"] = 1
    LL["chrt"] = "sched-runtime|sched-period|sched-deadline"
    LA["taskset"] = ""; LP["taskset"] = 1
    LA["flock"] = "wE"; LL["flock"] = "wait|timeout|conflict-exit-code"
    LP["flock"] = 1
    LA["exec"] = "a"
    LA["command"] = LA["nohup"] = LA["setsid"] = LA["builtin"] = ""
    LA["busybox"] = LA["unbuffer"] = LA["chronic"] = ""
    LA["ssh-agent"] = "aEOPt"
    LA["watch"] = "nq"; LL["watch"] = "interval|equexit"
  }
  function base(w) { sub(/^.*\//, "", w); return w }
  function priv(w) { return w ~ /^--privileged/ && w != "--privileged=false" }
  # The value of option u[k]: after its =, or the next word.
  function val(k,   x) {
    if (u[k] !~ /^--[^=]*=/) return u[k + 1]
    x = u[k]
    sub(/^[^=]*=/, "", x)
    return x
  }
  # A volume source that is a path: /x, ./x, ~/x, $HOME, a/b. A
  # plain name is a named volume, one without a colon anonymous. A
  # $ or nothing at all is a variable or a $(...) the segment split
  # cut off, which can be any path.
  function hostvol(x) {
    if (x == "" || x ~ /\$/) return 1
    if (x !~ /:/) return 0
    sub(/:.*/, "", x)
    return x ~ /^[\/.~$]/ || x ~ /\//
  }
  # run <prefix> <from> — what in the options of a run or create
  # reaches past the container, or "".
  function run(p, k,   w, o, x) {
    for (; k <= nw; k++) {
      w = u[k]
      o = w
      sub(/=.*/, "", o)
      if (priv(w)) return p "--privileged"
      if (o ~ /^--(pid|net|network|ipc|userns|uts|cgroupns)$/ && val(k) ~ /^(host$|container:|ns:)/)
        return p o " " val(k)
      if (o ~ /^--(device|cap-add|volumes-from|rootfs)/) return p o
      if (o ~ /^--publish/ || w ~ /^-[dit]*[pP]/ && w !~ /^--/) return p "publishing a port"
      # A host file or a host variable read into the container,
      # where printing the environment shows it.
      if (o ~ /^--(env-file|label-file|cidfile)$/) return p o
      if ((o == "--env" || w == "-e") && val(k) !~ /=/) return p o " " val(k) " without a value"
      if (w ~ /^-e[A-Za-z_]/ && w !~ /=/) return p w " without a value"
      if (o == "--security-opt" && val(k) ~ /unconfined|disable/)
        return p "--security-opt " val(k)
      if (o == "--mount" && (val(k) == "" || val(k) ~ /type=bind|volume-opt|bind-|\$/))
        return p "--mount with a host path"
      if (o == "--volume" && hostvol(val(k))) return p "--volume " val(k)
      # -v, alone or after -d, -i, -t, -P in one word.
      if (w ~ /^-[ditP]*v/ && w !~ /^--/) {
        x = w
        sub(/^-[ditP]*v/, "", x)
        if (x == "") x = u[k + 1]
        if (hostvol(x)) return p "-v " x
      }
    }
    return ""
  }
  # engine <tool> <from> — the verdict on what follows docker,
  # podman or nerdctl, category first, or "". Reading, pulling,
  # building, running and creating pass; everything else is denied.
  function engine(t, k,   w, n, g) {
    for (; k <= nw; k++) {
      w = u[k]
      if (w ~ /^(-H|--host|-c|--context|--connection|--url|--remote)(=|$)/ || w ~ /^-H./)
        return "remote " t " " w
      if (w ~ /^(--config|-l|--log-level)$/) { k++; continue }
      if (w ~ /^-/) continue
      # A management group names its verb in the next word.
      g = ""
      if (w ~ /^(container|image|volume|network|system|context|builder|buildx|manifest|machine|pod|secret|plugin|compose|kube|play)$/) {
        g = w
        for (k++; k <= nw && u[k] ~ /^-/; k++) ;
        w = u[k]
      }
      n = g == "" ? t " " w : t " " g " " w
      if (w == "run" || w == "create") {
        if (g == "compose") return "compose " n
        if (g == "volume") {
          for (k++; k <= nw; k++)
            if (u[k] ~ /device=|o=bind/) return "engine " n " over a host path"
          return ""
        }
        if (g != "" && g != "container") return "change " n
        w = run(n " ", k + 1)
        return w == "" ? "" : "engine " w
      }
      if (g == "compose" && w ~ /^(up|start|restart)$/ || g ~ /^(kube|play)$/ && w ~ /^(play|kube)$/)
        return "compose " n
      # A build may leave its result in the image store only.
      if (w == "build")
        for (k++; k <= nw; k++)
          if (u[k] ~ /^(-o|--output)(=|$)/ || u[k] ~ /^-o./ || u[k] ~ /^--cache-to/ && (u[k] ~ /type=local/ || u[k + 1] ~ /type=local/))
            return "engine " n " --output, a result written to this machine"
          else if (u[k] ~ /^--(iidfile|metadata-file)(=|$)/)
            return "engine " n " " u[k] ", a file written to this machine"
          else if (u[k] ~ /^--(secret|ssh)(=|$)/)
            return "engine " n " " u[k] ", a secret of this machine"
          else if (u[k] ~ /^--volume(=|$)/ && hostvol(val(k)) || u[k] ~ /^-v/ && hostvol(u[k] == "-v" ? u[k + 1] : substr(u[k], 3)))
            return "engine " n " -v, a host path mounted into the build"
      if (w == "" && g == "" || w ~ /^(ps|ls|list|images|inspect|logs|version|info|search|stats|top|port|diff|history|events|df|show|config|help|pull|build)$/)
        return ""
      return "change " n
    }
    return ""
  }
  # lab — the verdict on this segment for containers and lab VMs.
  function lab(   i, j, k, b, a, r) {
    # Another engine by variable: set in one segment, used in the
    # next (export DOCKER_HOST=...; docker ps).
    for (i = 1; i <= nw; i++)
      if (u[i] ~ /^(DOCKER_HOST|DOCKER_CONTEXT|CONTAINER_HOST|CONTAINER_CONNECTION)=/) engvar = u[i]
    # The first word, past a negation, the keywords a command can
    # follow, assignments and the wrappers that run the next one,
    # with their options and a number they take: sh -c, timeout 60.
    j = 1
    while (j <= nw && (u[j] == "" || u[j] ~ /^(!|do|then|else|elif|if|while|until)$/ \
        || u[j] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ \
        || base(u[j]) ~ /^(command|exec|env|time|nohup|nice|setsid|timeout|xargs|watch|sh|bash|dash|ksh|zsh)$/ \
        || j > 1 && (u[j] ~ /^-/ || u[j] ~ /^[0-9][0-9.]*[smhd]?$/))) j++
    if (j > nw) return ""
    b = base(u[j])
    a = u[j + 1]
    if (b ~ /^(docker|podman|nerdctl)(-compose)?$/) engnamed = b
    if (engvar != "" && engnamed != "") return "remote " engnamed " with " engvar
    if (b ~ /^(docker|podman)-compose$/) {
      for (k = j + 1; k <= nw && u[k] ~ /^-/; k++)
        if (u[k] ~ /^(-f|--file|-p|--project-name|--profile|--env-file|--project-directory|--ansi|--parallel|--progress)$/) k++
      if (u[k] ~ /^(up|start|restart|run|create)$/) return "compose " b " " u[k]
      if (k <= nw && u[k] !~ /^(ps|ls|images|logs|version|config|top|port|events|pull|build|help)$/)
        return "change " b " " u[k]
      return ""
    }
    if (b ~ /^(docker|podman|nerdctl)$/) return engine(b, j + 1)
    # orb runs anything that is not one of its subcommands in a VM;
    # of those, only reading state passes.
    if (b == "orb" || b == "orbctl") {
      if (a == "") return b == "orb" ? "vm orb, a shell in a lab VM" : ""
      if (a ~ /^(-h|--help|list|ls|info|status|version|help|logs|doctor|start|docker|k8s)$/) return ""
      if (a ~ /^(create|add|new)$/) return "vmnew " b " " a
      if (a ~ /^(clone|config|debug|default|delete|export|import|login|logout|rename|report|reset|restart|rm|serial|stop|top|update|usb)$/)
        return "vmchange " b " " a
      return "vm " b " " a ", a command in a lab VM"
    } else if (b == "limactl") {
      for (k = j + 1; k <= nw && u[k] ~ /^-/; k++) ;
      if (u[k] ~ /^(shell|copy|cp|tunnel)$/) return "vm limactl " u[k] ", in a lab VM"
      if (u[k] == "create") return "vmnew limactl create"
      if (k <= nw && u[k] !~ /^(start|list|ls|info|help|validate|template|completion)$/)
        return "vmchange limactl " u[k]
    } else if (b == "lima" && a != "-h" && a != "--help") {
      return "vm lima, a command in a lab VM"
    }
    return ""
  }
  {
    s = $0
    # ${VAR} is a variable, not a brace group, and 2>&1 one
    # redirection, not two commands.
    gsub(/\$\{/, "$", s)
    gsub(/>&/, ">", s)
    gsub(/<&/, "<", s)
    gsub(/[;&|(){}`]/, "\n", s)
    n = split(s, seg, "\n")
    for (l = 1; l <= n; l++) {
      # A redirection and its target name no program, attached or
      # not: SSH.EXE>out runs SSH.EXE, 2> log ssh runs ssh.
      gsub(/[0-9]*[<>]+[ \t]*[^ \t<>]*/, " ", seg[l])
      nw = split(seg[l], v, /[ \t]+/)
      split("", u)
      for (i = 1; i <= nw; i++) { u[i] = v[i]; gsub(/^["\047]+|["\047]+$/, "", u[i]) }
      r = lab()
      if (r != "") { print r; exit }
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
      while (i <= nw && (v[i] == "" || v[i] ~ /^(!|do|then|else|elif|if|while|until)$/ || v[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/)) i++
      if (i > nw) continue
      w = v[i]
      # Past the launchers in LA to the program they start, over
      # their options, the values those take and their operands:
      # env LC_ALL=C ssh, timeout -s KILL 5 ssh, setsid ssh. In a
      # cluster of short options the first that takes a value takes
      # the rest of the word, or the next word when it is last:
      # xargs -Is ssh s runs ssh. flock -c hands over the command
      # as its value; time takes a whole pipeline, negated too:
      # time ! ssh.
      for (;;) {
        c = w
        gsub(/^["\047]+|["\047]+$/, "", c)
        sub(/^.*\//, "", c)
        if (!(c in LA)) break
        p = LP[c]
        while (++i <= nw) {
          x = v[i]
          if (x == "--") { i++; break }
          if (c == "flock" && x ~ /^(-[A-Za-z]*c|--command)$/) { i++; break }
          if (c == "env" && x ~ /^(-[^-uCS]*S.|--split-string=)/) {
            sub(/^(-[^-uCS]*S|--split-string=)/, "", x)
            v[i] = x
            break
          }
          if (x ~ /^-/) {
            if (LA[c] != "" && x ~ ("^-[^-" LA[c] "]*[" LA[c] "]$") \
                || LL[c] != "" && x ~ ("^--(" LL[c] ")$")) i++
          }
          else if (c == "env" && x ~ /=/ || c == "time" && x == "!") ;
          else if (p-- < 1) break
        }
        if (i > nw) break
        w = v[i]
      }
      if (i > nw) continue
      # The real ssh that git push is given.
      if (w ~ /^"?\$GIT_SSH_COMMAND/) { print "deny ssh through GIT_SSH_COMMAND"; exit }
      how = ""
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
"engine "*)
  deny "${FOUND#engine } reaches past the container into this \
machine. A development session runs containers without host \
access; bin/hostwarden-lab up <family> starts one that way" ;;
"remote "*)
  hostwarden_refusal "${FOUND#remote }, another container engine,"
  emit "$HOSTWARDEN_REFUSAL" ;;
"vmnew "*)
  deny "${FOUND#vmnew } creates a VM outside bin/hostwarden-lab vm up, \
which creates it without this machine's files mounted and records \
it, so vm down can delete it: bin/hostwarden-lab vm up <family> \
--ops <test clone>" ;;
"vmchange "*)
  deny "${FOUND#vmchange } deletes, stops or changes a VM that may \
not be the lab's. bin/hostwarden-lab vm down deletes only the VMs \
this worktree created" ;;
"change "*)
  deny "${FOUND#change } reaches or changes a container, image or \
volume the lab may not own. A development session reads, pulls, \
builds, runs and creates; bin/hostwarden-lab exec and down reach \
and remove only the lab's own containers" ;;
"compose "*)
  deny "${FOUND#compose } starts what a file says, which this guard \
cannot read; bin/hostwarden-lab up <family> starts a container \
without host access" ;;
"vm "*)
  deny "${FOUND#vm } - a lab VM is a test server of the operations \
clone it was created for, never used from a development session. \
Next step: hand the question to a session in that clone, which \
bin/hostwarden-lab list names; how: rules/server-check-handoff.md" ;;
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
