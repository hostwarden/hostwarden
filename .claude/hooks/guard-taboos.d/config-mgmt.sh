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
# none of it is on the command line of ansible-playbook. So Hostwarden
# runs no playbook (rules/config-management.md: applying Ansible
# code is the user's step), except the forms that run no task at all:
# --syntax-check, --list-hosts, --list-tasks and --list-tags.
# ansible-pull applies a playbook from a repository in the same way,
# and ansible-console takes its commands from a prompt this hook
# never sees.
#
# An ad-hoc ansible call names its module and arguments, so it is
# judged like a shell command. The rules above have scanned its
# arguments already: -m shell -a "sed -i ... sshd_config" is a
# sed -i onto sshd_config wherever it runs. What they cannot see is
# the module itself:
#   - parted, filesystem, the Windows partition, format and
#     initialize modules, and shutdown, in any collection
#     (community.general.parted is parted);
#   - authorized_key and openssh_keypair, which write keys without
#     naming a key file, and generate_ssh_key with force (the user
#     module), which replaces the user's key;
#   - script, which runs a local file this hook cannot read, and
#     include_role, include_tasks, import_role and import_tasks,
#     which run tasks from files as a playbook does;
#   - any module but the ones that only read or run a command the
#     rules above have judged, once a key or sshd_config is named
#     in the invocation - outside --private-key, --key-file and
#     *private_key_file=, which only say how Ansible logs in.
# An invocation is a word whose last path component is ansible, to
# the end of its segment. Every word there that can name a module
# counts: the value of -m, of a run of short flags holding m (-bm
# parted, -mcopy), and of --module-name or an abbreviation of it.
# Ansible uses the last one, but the dequoted words cannot tell an
# -m of ansible from one inside -a, so judging all of them is the
# only reading that never passes a taboo module; grep -m1 inside
# -a counts as a module named 1, and --max-count reads the same.
# A value that is not a plain name, $MOD for one, counts as a
# writing module.
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
    if hit_without '(^|[^[:alnum:]_.-])ansible-playbook([^[:alnum:]_.-]|$)' \
      '^[^[:alnum:]]?ansible-playbook[^;&|]*[[:space:]]--(syntax-check|list-(hosts|tasks|tags))([[:space:]=]|$)'
    then
      deny "ansible-playbook applies whatever its tasks do, and this \
guard cannot read them - applying Ansible code is left to the \
user (rules/config-management.md); --syntax-check and --list-tasks, \
--list-hosts or --list-tags run nothing"
    fi
    if hit '(^|[^[:alnum:]_.-])ansible-(pull|console)([^[:alnum:]_.-]|$)'
    then
      deny "ansible-pull applies a playbook this guard cannot read, \
and ansible-console runs commands it never sees - the user runs \
them"
    fi
    # Per invocation, every module word without its collection
    # (command without one, unknown for a value that is not a
    # name), PATH when a key or sshd_config is named, and KEYGEN
    # for generate_ssh_key with force, which replaces the user's
    # key (the user module). The values of the --*-args options go
    # to ssh, sftp and scp, never to a module, and are cut while
    # their quotes still show where they end. Then the quotes go:
    # in ssh host 'ansible web -m parted' the quote is what stands
    # before ansible.
    AMODS=$(printf '%s\n' "${CMDQ:-${CMDJ:-$CMD}}" \
      | sed -E "s/--(ssh-common|ssh-extra|sftp-extra|scp-extra)-args(=|[[:space:]]+)(\"[^\"]*\"|'[^']*'|[^[:space:]]*)//g" \
      | tr -d "\"'" | tr ';&|`()' '\n' | K="$KEY|$SSHD" awk '
      {
        for (i = 1; i <= NF; i++) {
          t = $i; sub(/.*\//, "", t)
          if (t == "ansible") break
        }
        if (i > NF) next
        n = 0; rest = ""
        for (i++; i <= NF; i++) {
          w = $i; v = ""
          if (w ~ /^--(private-key|key-file)$/) { i++; continue }
          if (w ~ /^--(private-key|key-file)=/ || w ~ /private_key_file=/) continue
          if (w ~ /^--module-n[a-z-]*(=|$)/) {
            if (w ~ /=/) { v = w; sub(/^[^=]*=/, "", v) } else v = $(++i)
          } else if (w ~ /^-[A-Za-z]/ && index(w, "m")) {
            v = substr(w, index(w, "m") + 1); sub(/^=/, "", v)
            if (v == "") v = $(++i)
          } else { rest = rest " " w; continue }
          n++
          if (v !~ /^[A-Za-z0-9_.]+$/) v = "unknown"
          sub(/.*\./, "", v); print v
        }
        if (!n) print "command"
        if (rest ~ ENVIRON["K"]) print "PATH"
        # Ansible reads booleans in any case and from JSON too, so
        # force counts unless it is plainly false.
        lr = tolower(rest)
        if (lr ~ /generate_ssh_key/ && lr ~ /(^|[^a-z_])force([^a-z_]|$)/ \
            && lr !~ /(^|[^a-z_])force[[:space:]]*[=:][[:space:]]*(no|n|false|0|off)([^a-z0-9]|$)/)
          print "KEYGEN"
      }')
    AWRITE='' APATH=''
    for am in $AMODS; do
      case $am in
      PATH) APATH=1 ;;
      include_role|include_tasks|import_role|import_tasks)
        deny "this Ansible module runs tasks from files, which this \
guard cannot read - applying Ansible code is left to the user" ;;
      parted|filesystem|shutdown|win_partition|win_format|win_initialize_disk|win_shutdown)
        deny "this Ansible module writes a partition table, makes a \
filesystem or powers the host off" ;;
      authorized_key|openssh_keypair|KEYGEN)
        deny "this Ansible module writes SSH keys or authorized_keys, \
which is never allowed" ;;
      script)
        deny "the Ansible script module runs a local file this guard \
cannot read - run the commands through the shell or command module, \
where they are checked" ;;
      command|shell|raw|stat|find|slurp|setup|ping|win_command|win_shell|win_stat) ;;
      *) AWRITE=1 ;;
      esac
    done
    if [ -n "$AWRITE" ] && [ -n "$APATH" ]; then
      deny "an Ansible module that writes files, pointed at an SSH \
key or sshd_config, can replace it - read it with -m command \
and cat, or with -m stat"
    fi
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
