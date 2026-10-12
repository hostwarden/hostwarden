# guard-taboos.d/config-mgmt.sh — configuration management tools.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh

# --- Configuration management tools ---------------------------
# A playbook reaches every taboo above through modules whose names
# and arguments never spell a shell command: parted and filesystem
# write the partition table and make filesystems, lineinfile and
# template rewrite sshd_config, authorized_key replaces keys, and
# none of it is on the command line of ansible-playbook. What this
# hook can read is where the playbook comes from. One in the
# workspace, memory/ of this checkout, is the user's own code, read
# by the session before it runs (rules/workspace-playbook.md), so
# ansible-playbook runs there and nowhere else: every playbook —
# each positional word, whatever its name, since ansible-playbook
# takes any number of them — and every inventory (-i, --inventory)
# an absolute path under memory/, without a .. segment, and at
# least one of each. A word after an option that takes a value
# (PBVAL below, the list of `ansible-playbook --help`) is that
# value, not a playbook; an option this list does not know makes
# its value count as a playbook, which denies rather than passes.
# The path is compared as given and as the file system resolves
# the checkout (pwd -P), since a hook under /var/folders is the
# same hook under /private/var/folders. A word is cut at
# whitespace, so a checkout whose own path carries a space is
# denied here, Hostwarden's has none, and so is a quoted -e value
# with a space in it, whose second word reads as a playbook: one -e
# per variable passes. --check is not a condition:
# a task with check_mode: false runs in check mode too, and the
# rule has the session read for those first. The forms that run no
# task at all pass from anywhere: --syntax-check, --list-hosts,
# --list-tasks and --list-tags. ansible-pull applies a playbook
# from a repository this hook cannot read, and ansible-console
# takes its commands from a prompt it never sees.
#
# An ad-hoc ansible call names its module and arguments. ping and
# setup read; every other module changes the host outside the
# playbook the rule reads first, or runs what the rules above have
# scanned only in part, so an ad-hoc change goes into a playbook.
# The modules that reach a taboo say which, since the reason there
# is the effect, not the form: parted, filesystem, the Windows
# partition, format and initialize modules and the power-off
# module, in any collection (community.general.parted is parted);
# authorized_key and openssh_keypair, which write keys without
# naming a key file; script, which runs a local file this hook
# cannot read; include_role, include_tasks, import_role and
# import_tasks, which run tasks from files as a playbook does.
# An invocation is a word whose last path component is ansible, to
# the end of its segment, with a module (-m) or arguments (-a) for
# the command module: without both nothing runs, and the word is
# prose, a man page or a path. Each of the three tools as the last
# word of its segment runs nothing either (command -v, man, ls),
# nor with --help or --version. Every word that can name a module
# counts: the value of -m, of a run of short flags holding m (-bm
# parted, -mcopy), and of --module-name or an abbreviation of it.
# Ansible uses the last one, but the dequoted words cannot tell an
# -m of ansible from one inside -a, so judging all of them is the
# only reading that never passes a taboo module; grep -m1 inside
# -a counts as a module named 1, and --max-count reads the same.
# A value that is not a plain name, $MOD for one, counts as an
# unknown module.
#
# -e and --extra-vars put their value into argv, where ps, the
# journal and shell history read it (rules/secrets.md → Never Pass
# Secrets on the Command Line): in an ansible or ansible-playbook
# invocation, a value naming a password, a secret, a token or a
# key= is denied. The dequoted words of a value with spaces are
# read up to the next option, so a quoted value counts whole; a
# -e of grep or sed in a command that merely mentions ansible is
# outside any invocation and never read.
#
# ansible-galaxy collection install fetches code. With -r naming a
# requirements file in the workspace and -p (--collections-path) a
# directory under that file's own, what it fetches is what the
# pinned file says and lands beside the playbook, never in the
# user's home; any other install, and ansible-galaxy role install,
# is denied. collection list and the rest of ansible-galaxy read.
# ansible-inventory and ansible-doc read too, and so does
# ansible-lint with --offline, which the rule gives it: without
# that flag it installs every requirements.yml it finds. No rule
# here names them.
#
# terraform and tofu apply and destroy can replace or delete the
# server itself (rules/config-management.md), and Hostwarden never
# runs them, by any path. plan, show and state list only read.
#
# Full scope only: a development session reaches none of these
# tools (the shim refuses them), and this repository names them in
# rules, tests and commit messages all day.
case "$TEXT" in
*ansible*)
  if full; then
    if hit '(^|[^[:alnum:]_.-])ansible-(pull|console)([^[:alnum:]_.-]|$)'
    then
      deny "ansible-pull applies a playbook this guard cannot read, \
and ansible-console runs commands it never sees - the user runs \
them"
    fi
    # The workspace a playbook may come from, by the path this
    # checkout is reached under and by the one the file system
    # resolves it to; pwd and pwd -P are builtins, so one subshell
    # answers both, and only the two tools that read it pay it.
    GUARD_WS='' GUARD_WSP=''
    case "$TEXT" in
    *ansible-playbook*|*ansible-galaxy*)
      GUARD_ROOTS=$(cd "$HOOKDIR/../.." 2>/dev/null && pwd && pwd -P)
      GUARD_WS=${GUARD_ROOTS%%
*}/memory
      GUARD_WSP=${GUARD_ROOTS#*
}/memory
      ;;
    esac
    # Per invocation of ansible, ansible-playbook or ansible-galaxy,
    # one verdict word a line: SECRET for a -e value above; for
    # ansible every module word without its collection (command
    # without one, unknown for a value that is not a name); PB for
    # an ansible-playbook run the workspace condition above does
    # not hold for; GALAXY for an ansible-galaxy install that is
    # not a pinned requirements file from the workspace into the
    # playbook's own directory. The values of the --*-args options
    # go to ssh, sftp and scp, never to a module, and are cut while
    # their quotes still show where they end. Then the quotes go:
    # in a remote command 'ansible web -m parted' the quote is what
    # stands before ansible.
    AMODS=$(printf '%s\n' "${CMDQ:-${CMDJ:-$CMD}}" \
      | sed -E "s/--(ssh-common|ssh-extra|sftp-extra|scp-extra)-args(=|[[:space:]]+)(\"[^\"]*\"|'[^']*'|[^[:space:]]*)//g" \
      | tr -d "\"'" | tr ';&|`()' '\n' \
      | WS="$GUARD_WS" WSP="$GUARD_WSP" awk '
      BEGIN {
        ws = ENVIRON["WS"] "/"; wsp = ENVIRON["WSP"] "/"
        # The options of ansible-playbook that take the next word as
        # their value (ansible-playbook --help); -e and -i are read
        # on their own above them.
        PBVAL = "^(-[ltfucTM]|--(limit|tags|skip-tags|vault-id|vault-pass(word)?-file|conn(ection)?-pass(word)?-file|become-pass(word)?-file|start-at-task|forks|user|become-user|become-method|connection|timeout|module-path|private-key|key-file|(ssh-common|ssh-extra|sftp-extra|scp-extra)-args))$"
      }
      function inws(p) {
        return p ~ /^\// && p !~ /(^|\/)\.\.?(\/|$)/ \
          && (index(p, ws) == 1 || index(p, wsp) == 1)
      }
      function dir(p) { sub(/\/[^\/]*$/, "", p); return p }
      function secret(s) {
        return tolower(s) ~ /(pass(word|wd|phrase)?|secret|token)[^[:space:]=:]*[=:]|key=/
      }
      # evars(i) — $i is -e, --extra-vars or --extra-vars=...: SECRET
      # when its value, every word up to the next option, names one.
      function evars(i,   j, v) {
        if ($i ~ /^--extra-vars=/) { v = $i; sub(/^[^=]*=/, "", v); if (secret(v)) print "SECRET" }
        for (j = i + 1; j <= NF && $j !~ /^-/; j++) if (secret($j)) { print "SECRET"; break }
      }
      {
        for (i = 1; i <= NF; i++) {
          t = $i; sub(/.*\//, "", t)
          if (t ~ /^ansible(-playbook|-galaxy)?$/) break
        }
        if (i > NF) next
        cmd = t
        # The tool as the last word runs nothing: command -v, man,
        # ls, which. Neither do --help and --version, read up to
        # the first -a or -e, whose value can carry a -h of its own
        # (df -h) that Ansible never sees as an option.
        if (i == NF) next
        for (j = i + 1; j <= NF; j++) {
          if ($j ~ /^(-a|--args|-e|--extra-vars)(=|$)/ || ($j ~ /^-[A-Za-z]/ && $j !~ /^--/ && index($j, "a"))) break
          if ($j ~ /^(-h|--help|--version)$/) next
        }
        if (cmd == "ansible-playbook") {
          pb = 0; inv = 0; ok = 1
          for (i++; i <= NF; i++) {
            w = $i; v = ""
            # A redirection belongs to the shell, not a playbook: the
            # operator with its target attached, or the target as
            # the next word.
            if (w ~ /^[0-9]*[<>]/) { if (w ~ /^[0-9]*[<>]+$/) i++; continue }
            if (w ~ /^--(syntax-check|list-(hosts|tasks|tags))$/) { pb = -1; break }
            if (w == "-e" || w == "--extra-vars") { evars(i); i++; continue }
            if (w ~ /^--extra-vars=/) { evars(i); continue }
            if (w == "-i" || w ~ /^--inventory(-file)?$/) v = $(++i)
            else if (w ~ /^--inventory(-file)?=/) { v = w; sub(/^[^=]*=/, "", v) }
            else if (w ~ /^-i./) v = substr(w, 3)
            else if (w ~ PBVAL) { i++; continue }
            else if (w ~ /^-/) continue
            else { pb++; if (!inws(w)) ok = 0; continue }
            inv++; if (!inws(v)) ok = 0
          }
          if (pb >= 0 && (pb == 0 || inv == 0 || !ok)) print "PB"
          next
        }
        if (cmd == "ansible-galaxy") {
          sub1 = $(i + 1); sub2 = $(i + 2)
          if (sub1 == "install" || (sub1 == "role" && sub2 == "install")) { print "GALAXY"; next }
          if (sub1 != "collection" || sub2 != "install") next
          r = ""; p = ""; ok = 1
          for (i += 3; i <= NF; i++) {
            w = $i
            if (w ~ /^[0-9]*[<>]/) { if (w ~ /^[0-9]*[<>]+$/) i++; continue }
            if (w == "-r" || w == "--requirements-file") r = $(++i)
            else if (w ~ /^--requirements-file=/) { r = w; sub(/^[^=]*=/, "", r) }
            else if (w == "-p" || w == "--collections-path") p = $(++i)
            else if (w ~ /^--collections-path=/) { p = w; sub(/^[^=]*=/, "", p) }
            else if (w ~ /^-p./) p = substr(w, 3)
            else if (w !~ /^-/) ok = 0
          }
          if (!ok || !inws(r) || !inws(p) || index(p, dir(r) "/") != 1) print "GALAXY"
          next
        }
        n = 0; args = 0
        for (i++; i <= NF; i++) {
          w = $i; v = ""
          if (w == "-e" || w == "--extra-vars" || w ~ /^--extra-vars=/) { evars(i); continue }
          if (w ~ /^(-a|--args)(=|$)/ || (w ~ /^-[A-Za-z]/ && w !~ /^--/ && index(w, "a"))) args = 1
          if (w ~ /^--module-n[a-z-]*(=|$)/) {
            if (w ~ /=/) { v = w; sub(/^[^=]*=/, "", v) } else v = $(++i)
          } else if (w ~ /^-[A-Za-z]/ && index(w, "m")) {
            v = substr(w, index(w, "m") + 1); sub(/^=/, "", v)
            if (v == "") v = $(++i)
          } else continue
          n++
          if (v !~ /^[A-Za-z0-9_.]+$/) v = "unknown"
          sub(/.*\./, "", v); print v
        }
        # Without -m, -a names the arguments of the command module;
        # without both, nothing runs (Ansible refuses an empty
        # command), and the word ansible is a word: man ansible,
        # command -v ansible, a journal line that names it.
        if (!n && args) print "command"
      }')
    for am in $AMODS; do
      case $am in
      SECRET)
        deny "a password, secret, token or key in -e or --extra-vars \
goes into argv, which ps, the journal and shell history read - put \
it in a vars file or a vault the playbook reads \
(rules/secrets.md - Never Pass Secrets on the Command Line)" ;;
      PB)
        deny "ansible-playbook runs only a playbook from the workspace: \
each playbook and the inventory (-i) an absolute path under \
$GUARD_WS without a .. segment, and a word after an option this \
guard does not know counts as a playbook \
(rules/workspace-playbook.md); --syntax-check, --list-hosts, \
--list-tasks and --list-tags run nothing and pass from anywhere" ;;
      GALAXY)
        deny "ansible-galaxy installs only collections a pinned \
requirements file in the workspace names: collection install \
-r <file under $GUARD_WS> -p <directory under that file's>, nothing \
else on the line; a role install, and a collection named on the \
command line, fetch code this guard cannot read \
(rules/workspace-playbook.md)" ;;
      include_role|include_tasks|import_role|import_tasks)
        deny "this Ansible module runs tasks from files, which this \
guard cannot read - a playbook from the workspace is read first \
(rules/workspace-playbook.md)" ;;
      parted|filesystem|shutdown|win_partition|win_format|win_initialize_disk|win_shutdown)
        deny "this Ansible module writes a partition table, makes a \
filesystem or powers the host off" ;;
      authorized_key|openssh_keypair)
        deny "this Ansible module writes SSH keys or authorized_keys, \
which is never allowed" ;;
      script)
        deny "the Ansible script module runs a local file this guard \
cannot read - put the steps into a playbook in the workspace" ;;
      ping|setup) ;;
      *)
        deny "an ad-hoc ansible call runs only ping and setup; $am goes \
into a playbook in the workspace (rules/workspace-playbook.md)" ;;
      esac
    done
  fi
  ;;
esac
case "$TEXT" in
*terraform*|*tofu*)
  # The verb is the first word after the global options, whose value
  # may be quoted (-chdir="my infra"): terraform output apply only
  # reads an output named apply.
  TFOPT='-[^[:space:]"'\'']*("[^"]*"|'\''[^'\'']*'\'')?[^[:space:]]*'
  if full && hit "(^|[^[:alnum:]_.-])(terraform|tofu)([[:space:]]+$TFOPT)*[[:space:]]+(apply|destroy)([^[:alnum:]_-]|\$)"
  then
    deny "terraform and tofu apply and destroy can replace or \
delete the server itself - the user runs them \
(rules/config-management.md)"
  fi
  ;;
esac
