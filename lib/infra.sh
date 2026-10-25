# shellcheck shell=sh disable=SC2034 # read by the two programs
# infra.sh — what bin/hostwarden-tofu and bin/hostwarden-ansible
# share: where a tree of infrastructure code is, what its
# hostwarden.md says, and how its credentials reach the tool
# without passing through the session (rules/infra-code.md).
#
# Sourced, never executed. Expects INFRA_ROOT, the checkout, and
# INFRA_PROG, the program name messages carry. Defines:
#
#   infra_say <text…>      — a line on stdout, prefixed
#   infra_die <text…>      — the same on stderr, exit 1
#   infra_refuse <text…>   — a refusal on stderr, exit 3: the user
#                            runs it, never this program
#   infra_operations       — dies unless this checkout is for
#                            operations (lib/mode.sh)
#   infra_path             — what mise installed first on PATH, the
#                            shim of a development checkout taken off
#   infra_tree <kind> <name>
#                          — resolves a tree: INFRA_TREE its directory
#                            (pwd -P), INFRA_TREE_NAME, INFRA_TREE_WHERE
#                            workspace or external; dies when none
#   infra_conf <key>       — the value of `- <Key>: <value>` in the
#                            tree's hostwarden.md, or nothing
#   infra_inside <path>    — true when <path> resolves under INFRA_TREE
#   infra_secret_word <word>
#                          — true when a word names a password, secret,
#                            token or key= (rules/secrets.md); with
#                            INFRA_SECRET_NOKEY set, the bare name
#                            key= does not count, for a value where
#                            key names a path; access_key= still does
#   infra_refuse_secret_args <short> <long> <args…>
#                          — exits 3 when the value of the option
#                            spelled <short> or <long>, attached or
#                            as the next word, names a secret: argv is
#                            read by ps and the shell history
#   infra_run <command…>   — the command in INFRA_TREE with the tree's
#                            credentials in its environment, as
#                            → Credentials below says
#
# A tree is the user's own code: one under the workspace,
# memory/infra/, or one memory/user.md names under
# `# Infrastructure code`, a line per tree:
#
#   - ansible <name>: /absolute/path
#   - opentofu <name>: /absolute/path
#
# The workspace is shared and the file personal, so an external
# tree is registered per machine, by the user. The Ansible tree
# memory/infra/ansible/ needs no name; an OpenTofu stack is
# memory/infra/opentofu/<name>/, one root module and one state each.
#
# Credentials never stand in the tree in the clear, and never pass
# through this shell's output. Three sources, each optional, all
# applied where present:
#
#   <tree>/secrets.env              shared: VAR=op://vault/item/field
#                                   lines only, which `op run` resolves
#                                   through the service account whose
#                                   token bin/hostwarden-password token
#                                   1password stored, a token that sees
#                                   one vault (lib/passwords.sh); or
#                                   one `bws-project: <id>` line, which
#                                   `bws run` serves the same way
#   ~/hostwarden-keys/infra/<kind>/<name>/env
#                                   personal, mode 600: VAR=value lines,
#                                   exported to the tool alone
#   ~/hostwarden-keys/infra/ansible/<name>/vault-password
#                                   the Ansible vault's password file,
#                                   which bin/hostwarden-ansible names
#
# A line of secrets.env with any other value is a secret in a shared
# repository, and the run stops there.

infra_say() { echo "$INFRA_PROG: $*"; }
infra_die() { echo "$INFRA_PROG: $*" >&2; exit 1; }
infra_refuse() { echo "$INFRA_PROG: $* - the user runs it, never this program." >&2; exit 3; }

infra_operations() {
  hostwarden_mode "$INFRA_ROOT"
  [ "$HOSTWARDEN_MODE" = operations ] ||
    infra_die "only an operations checkout runs infrastructure code;" \
      "this is $HOSTWARDEN_MODE (AGENTS.md - Development or Operations)"
}

infra_path() {
  hostwarden_path_without_shim
  PATH=$HOSTWARDEN_PATH
  hostwarden_mise_bins "$INFRA_ROOT"
  [ -z "$HOSTWARDEN_MISE_BINS" ] || PATH=$HOSTWARDEN_MISE_BINS:$PATH
  export PATH
}

# infra_user_tree <kind> <name> — the path memory/user.md records,
# on stdout; nothing when it records none. A line the Markdown
# wrap broke goes on indented and is read back as one.
infra_user_tree() {
  [ -f "$INFRA_ROOT/memory/user.md" ] || return 1
  awk -v want="$1 $2" '
    found && /^[ \t]+[^ \t]/ { sub(/^[ \t]+/, ""); v = v " " $0; next }
    found { exit }
    /^# / { on = ($0 == "# Infrastructure code"); next }
    on && /^- (ansible|opentofu) [^ ]+: / {
      k = $2 " " substr($3, 1, length($3) - 1)
      if (k == want) { sub(/^- [^ ]+ [^ ]+: +/, ""); v = $0; found = 1 }
    }
    END { sub(/[ \t]+$/, "", v); if (found) print v; exit !found }
  ' "$INFRA_ROOT/memory/user.md"
}

infra_tree() {
  it_kind=$1 it_name=$2
  case $it_name in
    ''|*/*|.*|*[!A-Za-z0-9_.-]*)
      [ "$it_kind" = ansible ] && [ -z "$it_name" ] ||
        infra_die "a tree is named by one word of letters, digits," \
          "dots, dashes and underscores: $it_name" ;;
  esac
  INFRA_TREE_WHERE=workspace
  case $it_kind in
    ansible)
      INFRA_TREE_NAME=${it_name:-ansible}
      it_dir=$INFRA_ROOT/memory/infra/$INFRA_TREE_NAME ;;
    opentofu)
      INFRA_TREE_NAME=$it_name
      it_dir=$INFRA_ROOT/memory/infra/opentofu/$it_name ;;
    *) infra_die "no such kind of tree: $it_kind" ;;
  esac
  if [ ! -d "$it_dir" ]; then
    it_ext=$(infra_user_tree "$it_kind" "$INFRA_TREE_NAME") || it_ext=''
    case $it_ext in
      /*) INFRA_TREE_WHERE=external it_dir=$it_ext ;;
      '') infra_die "no $it_kind tree $INFRA_TREE_NAME: none under" \
        "memory/infra/, and memory/user.md names none under" \
        "'# Infrastructure code' (rules/infra-code.md)" ;;
      *) infra_die "memory/user.md names the $it_kind tree" \
        "$INFRA_TREE_NAME by a path that is not absolute: $it_ext" ;;
    esac
    [ -d "$it_dir" ] || infra_die "the $it_kind tree $INFRA_TREE_NAME" \
      "is recorded at $it_dir, which is not a directory"
  fi
  INFRA_TREE=$(cd "$it_dir" && pwd -P) || infra_die "cannot enter $it_dir"
  INFRA_KIND=$it_kind
}

infra_conf() {
  [ -f "$INFRA_TREE/hostwarden.md" ] || return 1
  awk -v want="$1" '
    found && /^[ \t]+[^ \t]/ { sub(/^[ \t]+/, ""); v = v " " $0; next }
    found { exit }
    /^- [^:]+: / {
      k = $0; sub(/^- /, "", k); sub(/: .*/, "", k)
      if (tolower(k) == tolower(want)) { v = $0; sub(/^- [^:]+: +/, "", v); found = 1 }
    }
    END { sub(/[ \t]+$/, "", v); if (found) print v; exit !found }
  ' "$INFRA_TREE/hostwarden.md"
}

infra_inside() {
  ii_p=$1
  case $ii_p in /*) ;; *) ii_p=$INFRA_TREE/$ii_p ;; esac
  if [ -d "$ii_p" ]; then
    ii_r=$(cd "$ii_p" 2>/dev/null && pwd -P) || return 1
  else
    ii_d=$(cd "${ii_p%/*}" 2>/dev/null && pwd -P) || return 1
    ii_r=$ii_d/${ii_p##*/}
  fi
  case $ii_r in "$INFRA_TREE"|"$INFRA_TREE"/*) return 0 ;; esac
  return 1
}

infra_secret_word() {
  isw_re='(pass(word|wd|phrase)?|secret|token)[^[:space:]=:]*[=:]'
  # With INFRA_SECRET_NOKEY the bare name key is a path, the S3
  # backend's; access_key, sse_customer_key and every other *key
  # stay secrets.
  if [ -n "${INFRA_SECRET_NOKEY:-}" ]; then isw_re="$isw_re|.key="; else isw_re="$isw_re|key="; fi
  printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' | grep -Eq "$isw_re"
}

infra_refuse_secret_args() {
  irs_s=$1 irs_l=$2
  shift 2
  irs_next=''
  for irs_a; do
    irs_v=''
    if [ -n "$irs_next" ]; then
      irs_v=$irs_a irs_next=''
    else
      case $irs_a in
        "$irs_s"|"$irs_l") irs_next=1 ;;
        "$irs_l"=*|-"$irs_l"=*) irs_v=${irs_a#*=} ;;
        "$irs_s"?*) irs_v=${irs_a#"$irs_s"}; irs_v=${irs_v#=} ;;
      esac
    fi
    [ -z "$irs_v" ] || ! infra_secret_word "$irs_v" ||
      infra_refuse "a secret in $irs_s goes into argv, which ps and the" \
        "shell history read; put it in a vars file or the vault" \
        "(rules/secrets.md - Never Pass Secrets on the Command Line)"
  done
  return 0
}

# --- Credentials -----------------------------------------------

# infra_env_local — exports the lines of the personal env file,
# checked for mode 600 and this user first. `export "VAR=value"`
# expands nothing in the value.
infra_env_local() {
  iel_f=$HOME/hostwarden-keys/infra/$INFRA_KIND/$INFRA_TREE_NAME/env
  [ -f "$iel_f" ] || return 0
  infra_mode600 "$iel_f"
  while IFS= read -r iel_l || [ -n "$iel_l" ]; do
    case $iel_l in
      ''|'#'*) ;;
      [A-Za-z_]*=*)
        case ${iel_l%%=*} in
          *[!A-Za-z0-9_]*) infra_die "$iel_f: not a variable name: ${iel_l%%=*}" ;;
        esac
        export "${iel_l?}" ;;
      *) infra_die "$iel_f: a line that is not VAR=value" ;;
    esac
  done < "$iel_f"
}

infra_mode600() {
  if [ "$(uname -s)" = Darwin ]; then
    im_s=$(stat -f '%Lp %u' "$1" 2>/dev/null)
  else
    im_s=$(stat -c '%a %u' "$1" 2>/dev/null)
  fi
  [ "$im_s" = "600 $(id -u)" ] ||
    infra_die "$1 must be mode 600 and owned by $(id -un)" \
      "(rules/secrets.md - API Credentials on the Workstation)"
}

# infra_secrets_env — reads <tree>/secrets.env: INFRA_OP_ENV set
# when it holds op:// lines, INFRA_BWS_PROJECT when it names a
# project; dies on anything else.
infra_secrets_env() {
  INFRA_OP_ENV='' INFRA_BWS_PROJECT='' INFRA_OP_REF=''
  ise_f=$INFRA_TREE/secrets.env
  [ -f "$ise_f" ] || return 0
  while IFS= read -r ise_l || [ -n "$ise_l" ]; do
    case $ise_l in
      ''|'#'*) ;;
      bws-project:*)
        ise_v=${ise_l#bws-project:}
        ise_v=$(printf '%s' "$ise_v" | tr -d ' \t')
        case $ise_v in
          [0-9a-fA-F]*-*-*-*-*) ;;
          *) infra_die "$ise_f: not a Secrets Manager project id: $ise_v" ;;
        esac
        [ -z "$INFRA_BWS_PROJECT" ] ||
          infra_die "$ise_f: one bws-project line, not two"
        INFRA_BWS_PROJECT=$ise_v ;;
      [A-Za-z_]*=op://*/*/*)
        INFRA_OP_ENV=$ise_f
        [ -n "$INFRA_OP_REF" ] || INFRA_OP_REF=${ise_l#*=} ;;
      *)
        infra_die "$ise_f: every line is VAR=op://vault/item/field or" \
          "bws-project: <id>; a value in the clear is a secret in a" \
          "shared repository (rules/infra-code.md - Credentials)" ;;
    esac
  done < "$ise_f"
}

# The credential files are read once per process, and the manager
# asked once: a plan on a fresh tree runs init and plan through here.
INFRA_CREDS=''
infra_run() {
  if [ -z "$INFRA_CREDS" ]; then
    infra_secrets_env
    infra_env_local
    if [ -n "$INFRA_OP_ENV" ]; then
      # The token's one vault has to be the one the references name
      # (rules/ssh-passwords.md - Passwords in a Manager).
      pw_has op || infra_die "secrets.env names 1Password references" \
        "and op is not installed: bin/hostwarden-doctor says how"
      pw_manager_scoped "1password $INFRA_OP_REF" ||
        infra_die "1Password is not set up as rules/infra-code.md -" \
          "Credentials says"
    fi
    INFRA_CREDS=1
  fi
  cd "$INFRA_TREE" || infra_die "cannot enter $INFRA_TREE"
  if [ -n "$INFRA_OP_ENV" ]; then
    # pw_op execs op, so it runs in a subshell of its own.
    (pw_op run --env-file="$INFRA_OP_ENV" -- "$@")
  elif [ -n "$INFRA_BWS_PROJECT" ]; then
    pw_has bws || infra_die "secrets.env names a Secrets Manager project" \
      "and bws is not installed: bin/hostwarden-doctor says how"
    # bws run takes the command as one string, run by a shell: each
    # word single-quoted, a quote inside it closed and reopened.
    ir_cmd=''
    for ir_a; do
      ir_q=$(printf '%s' "$ir_a" | sed "s/'/'\\\\''/g")
      ir_cmd="$ir_cmd${ir_cmd:+ }'$ir_q'"
    done
    (pw_bws run --project-id "$INFRA_BWS_PROJECT" -- "$ir_cmd")
  else
    "$@"
  fi
}
