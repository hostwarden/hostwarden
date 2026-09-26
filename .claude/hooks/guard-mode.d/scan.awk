# guard-mode.d/scan.awk — the command read word by word for the
# forms development.sh denies. Run by development.sh with -v
# tool=<tool name>; prints one verdict line, or the paths the
# command names.
  BEGIN {
    RS = "\001"
    T = "^(ssh|scp|sftp|mosh|sudo|sudoedit|doas|pkexec|ansible|ansible-playbook|ansible-pull|ansible-console|terraform|tofu)$"
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
    # A shell with -c runs the next word, its command string, as a
    # command; without -c the shell itself is the program.
    LA["sh"] = LA["bash"] = LA["dash"] = LA["ksh"] = LA["zsh"] = "oO"
  }
  function base(w) { sub(/^.*\//, "", w); return w }
  # cmdpos <words> <count> — the index of the program a segment
  # runs, or count + 1. Past a negation, assignments and the
  # keywords a command can follow (while true; do ssh ...), then
  # past the launchers in LA to the program they start, over their
  # options, the values those take and their operands: env
  # LC_ALL=C ssh, timeout -s KILL 5 ssh, setsid ssh, sh -c "ssh h".
  # In a cluster of short options the first that takes a value
  # takes the rest of the word, or the next word when it is last:
  # xargs -Is ssh s runs ssh. flock -c hands over the command as
  # its value; time takes a whole pipeline, negated too: time !
  # ssh. env -S puts the command it carries in its own place.
  function cmdpos(a, n,   i, k, c, p, x, s, sh, cf) {
    i = 1
    while (i <= n && (a[i] == "" || a[i] ~ /^(!|do|then|else|elif|if|while|until)$/ || a[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/)) i++
    while (i <= n) {
      c = a[i]
      gsub(/^["\047]+|["\047]+$/, "", c)
      if (!(base(c) in LA)) break
      c = base(c)
      p = LP[c]
      # A shell is a launcher only once -c stood in its options:
      # bash -s -- docker rm reads its script from stdin, and the
      # words after it are arguments to that script.
      s = i; sh = c ~ /^(sh|bash|dash|ksh|zsh)$/; cf = 0
      while (++i <= n) {
        x = a[i]
        if (sh && !cf && (x == "--" || x !~ /^-/)) return s
        if (sh && x ~ /^-[A-Za-z]*c/) cf = 1
        if (x == "--") { i++; break }
        if (c == "flock" && x ~ /^(-[A-Za-z]*c|--command)$/) { i++; break }
        if (c == "env" && x ~ /^(-[^-uCS]*S.|--split-string=)/) {
          sub(/^(-[^-uCS]*S|--split-string=)/, "", x)
          a[i] = x
          break
        }
        if (x ~ /^-/) {
          if (LA[c] != "" && x ~ ("^-[^-" LA[c] "]*[" LA[c] "]$") \
              || LL[c] != "" && x ~ ("^--(" LL[c] ")$")) i++
        }
        else if (c == "env" && x ~ /=/ || c == "time" && x == "!") ;
        else if (p-- < 1) break
      }
    }
    # find runs the word after its first -exec.
    c = a[i]
    gsub(/^["\047]+|["\047]+$/, "", c)
    if (i <= n && base(c) == "find")
      for (k = i + 1; k <= n; k++)
        if (a[k] ~ /^-(exec|execdir|ok|okdir)$/) return k + 1
    return i
  }
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
    j = cmdpos(u, nw)
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
    # orb runs anything that is not one of its subcommands in a VM.
    if (b == "orb" || b == "orbctl") {
      if (a == "") return b == "orb" ? "vm orb, a shell in a lab VM" : ""
      if (a ~ /^(-h|--help|list|ls|info|status|version|help|logs|doctor|docker|k8s)$/) return ""
      if (a == "start" && u[j + 2] == "") return ""
      if (a ~ /^(create|add|new)$/) return "vmnew " b " " a
      if (a ~ /^(clone|config|debug|default|delete|export|import|login|logout|rename|report|reset|restart|rm|serial|start|stop|top|update|usb)$/)
        return "vmchange " b " " a
      return "vm " b " " a ", a command in a lab VM"
    } else if (b == "limactl") {
      for (k = j + 1; k <= nw && u[k] ~ /^-/; k++) ;
      if (u[k] ~ /^(shell|copy|cp|tunnel)$/) return "vm limactl " u[k] ", in a lab VM"
      if (u[k] == "create") return "vmnew limactl create"
      if (k <= nw && u[k] !~ /^(list|ls|info|help|validate|template|completion)$/)
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
      i = cmdpos(v, nw)
      if (i > nw) continue
      w = v[i]
      c = w
      gsub(/^["\047]+|["\047]+$/, "", c)
      sub(/^.*\//, "", c)
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
  }
