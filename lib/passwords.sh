# shellcheck shell=sh
# passwords.sh — where the SSH password of a host that takes no key
# comes from, defined once for bin/hostwarden-askpass and
# bin/hostwarden-password (rules/ssh-passwords.md).
#
# Sourced, never executed.
#
# A password belongs to its target, <user>@<host>:<port>: the user,
# HostName and Port that ssh itself resolves, never the name a call
# was typed with. A HostName that changes in the shared
# memory/ssh_hosts then finds no password, instead of handing this
# one to another machine.
#
# Where it comes from is one line per login in memory/user.md, which
# is personal (rules/machine-memory.md → Personal versus shared),
# under the heading `# SSH Passwords`:
#
#   - <user>@<host>: local [keychain|file]
#   - <user>@<host>: 1password op://<vault>/<item>/[<section>/]<field>
#   - <user>@<host>: rbw <profile>/<item name>
#   - <user>@<host>: bws <secret id>
#
# <host> is the name Hostwarden connects by. A password manager's
# entry must carry the target, spelled as pw_target prints it, in a
# field of its own: a line in user.md that points at any other entry,
# the user's bank login say, then reaches nothing
# (pw_manager_bound).
#
# A password manager is reached only through an identity that sees
# nothing but Hostwarden's entries (pw_manager_scoped): a 1Password
# service account whose token reaches one vault, a Bitwarden or
# Vaultwarden account of its own in an rbw profile of its own, or a
# Secrets Manager machine account's token. Never the user's own login,
# which would put the whole vault in reach.
#
# The local stores, picked by pw_backend:
#
#   keychain        macOS: the login keychain, through security(1)
#   file            anywhere else: one file per secret, encrypted
#                   with openssl under a key kept in another
#                   directory. It protects a file that leaves this
#                   machine alone, a backup or a sync; anything
#                   running as this user reads both
#
# A Linux desktop's Secret Service is no store here: any process of
# the user reads every item of an unlocked keyring, so it would put
# far more than Hostwarden's own passwords in reach. The file puts
# only those.
#
# Nothing here prints a secret but pw_local_get and pw_manager_get,
# whose stdout is ssh's pipe when bin/hostwarden-askpass runs them.
#
# Expects PW_ROOT, the checkout. Defines:
#   pw_target <user> <host> <port>
#                        — the target, lowercased host, on stdout
#   pw_backend           — the local store this machine uses
#   pw_local_backend <source>
#                        — the store a `local [<store>]` source names,
#                          or this machine's
#   pw_local_has <backend> <kind> <key>
#                        — true when the store holds that secret;
#                          <kind> is ssh or token
#   pw_local_get <backend> <kind> <key>
#   pw_local_put <backend> <kind> <key>
#                        — stores stdin; the keychain prompts itself
#   pw_local_del <backend> <kind> <key>
#   pw_source <user> <name>…
#                        — the source recorded for the first
#                          <user>@<name> found, on stdout
#   pw_record <user>@<name> <source>
#   pw_unrecord <user>@<name>
#   pw_valid_source <source>
#   pw_manager_scoped <source>
#                        — true when the source goes through an
#                          identity that sees Hostwarden's entries only
#   pw_manager_bound <source> <target>
#                        — true when the entry names this target
#   pw_manager_get <source> <target>
#                        — the password on stdout, bound entries only
#   pw_probe <user> <name> <target>
#                        — asks the host which login methods it offers
#                          and records the answer; needs HOSTWARDEN_CACHE
#   pw_keyless <target> [<days>]
#                        — true when an answer no older than <days>,
#                          30 by default, names no key login and a
#                          password one

PW_SERVICE=hostwarden-ssh
PW_TOKEN_SERVICE=hostwarden-token
PW_USER_MD=$PW_ROOT/memory/user.md

pw_target() {
  printf '%s@%s:%s\n' "$1" "$(printf %s "$2" | tr '[:upper:]' '[:lower:]')" "$3"
}

pw_has() { command -v "$1" >/dev/null 2>&1; }

pw_backend() {
  case ${HOSTWARDEN_PASSWORD_STORE:-} in
    keychain|file) echo "$HOSTWARDEN_PASSWORD_STORE"; return ;;
  esac
  if [ "$(uname -s)" = Darwin ] && pw_has security; then
    echo keychain
  else
    echo file
  fi
}

pw_local_backend() {
  pwlb=${1#local}
  pwlb=${pwlb# }
  if [ -n "$pwlb" ]; then echo "$pwlb"; else pw_backend; fi
}

pw_service() { [ "$1" = token ] && echo "$PW_TOKEN_SERVICE" || echo "$PW_SERVICE"; }

# The file store: the key in the configuration directory, the
# secrets in the data directory, so that a backup or a sync that
# takes one of them does not take both.
PW_FILE_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/hostwarden/passwords
PW_FILE_KEY=${XDG_CONFIG_HOME:-$HOME/.config}/hostwarden/password-key

pw_file() {
  printf '%s:%s' "$(pw_service "$1")" "$2" | openssl dgst -sha256 -r |
    { read -r h _; echo "$PW_FILE_DIR/$h"; }
}

pw_file_key() {
  [ -s "$PW_FILE_KEY" ] && return 0
  (
    umask 077
    mkdir -p "${PW_FILE_KEY%/*}" &&
      openssl rand -hex 32 > "$PW_FILE_KEY.$$" &&
      mv "$PW_FILE_KEY.$$" "$PW_FILE_KEY"
  )
}

pw_local_has() {
  case $1 in
    keychain)
      security find-generic-password -s "$(pw_service "$2")" -a "$3" \
        >/dev/null 2>&1 ;;
    file) [ -f "$(pw_file "$2" "$3")" ] ;;
    *) return 1 ;;
  esac
}

pw_local_get() {
  case $1 in
    keychain)
      security find-generic-password -s "$(pw_service "$2")" -a "$3" -w \
        2>/dev/null ;;
    file)
      pwg_f=$(pw_file "$2" "$3")
      [ -f "$pwg_f" ] && [ -s "$PW_FILE_KEY" ] &&
        openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:$PW_FILE_KEY" \
          -in "$pwg_f" 2>/dev/null ;;
    *) return 1 ;;
  esac
}

# The keychain takes the value only from its own prompt, which asks
# twice; the value then never passes through this shell. The other
# two read it from stdin.
pw_local_put() {
  case $1 in
    keychain)
      security add-generic-password -U -s "$(pw_service "$2")" -a "$3" \
        -l "Hostwarden $2 $3" -w ;;
    file)
      pw_file_key || return 1
      pwp_f=$(pw_file "$2" "$3")
      (
        umask 077
        mkdir -p "$PW_FILE_DIR" &&
          openssl enc -aes-256-cbc -pbkdf2 -salt -pass "file:$PW_FILE_KEY" \
            -out "$pwp_f.$$" &&
          mv "$pwp_f.$$" "$pwp_f"
      ) ;;
    *) return 1 ;;
  esac
}

pw_local_del() {
  case $1 in
    keychain)
      security delete-generic-password -s "$(pw_service "$2")" -a "$3" \
        >/dev/null 2>&1 ;;
    file) rm -f "$(pw_file "$2" "$3")" ;;
    *) return 1 ;;
  esac
}

# The characters a source may hold after its first word. Narrow on
# purpose: the line is read by a program that fetches a secret, and
# an entry named otherwise can be referred to by its ID instead.
PW_NAME='[A-Za-z0-9 ._()-]'

pw_valid_source() {
  printf '%s\n' "$1" | grep -Eqx \
"local( (keychain|file))?|\
1password op://$PW_NAME+/$PW_NAME+(/$PW_NAME+){1,2}|\
rbw [A-Za-z0-9_-]+/$PW_NAME+|\
bws [0-9a-fA-F-]{36}"
}

pw_source() {
  [ -f "$PW_USER_MD" ] || return 1
  pws_user=$1
  shift
  for pws_name in "$@"; do
    awk -v want="$(printf '%s@%s' "$pws_user" "$pws_name" |
        tr '[:upper:]' '[:lower:]')" '
      # A line the Markdown wrap broke goes on indented, and is
      # read back as one.
      found && /^[ \t]+[^ \t]/ { sub(/^[ \t]+/, ""); v = v " " $0; next }
      found { exit }
      /^# / { on = ($0 == "# SSH Passwords") ; next }
      on && /^- [^ :]+: / {
        k = substr($2, 1, length($2) - 1)
        if (tolower(k) == want) {
          sub(/^- [^ :]+: +/, ""); v = $0; found = 1
        }
      }
      END { sub(/[ \t]+$/, "", v); if (found) print v; exit !found }
    ' "$PW_USER_MD" && return 0
  done
  return 1
}

# pw_record <user>@<name> <source> — replaces the login's line, or
# adds it at the end of the section, which is added at the end of
# the file where it is missing.
pw_record() {
  pw_edit "$1" "- $1: $2"
}

pw_unrecord() {
  pw_edit "$1" ""
}

pw_edit() {
  [ -f "$PW_USER_MD" ] || : > "$PW_USER_MD" || return 1
  pwe_tmp="$PW_USER_MD.$$.lock"
  awk -v want="$(printf %s "$1" | tr '[:upper:]' '[:lower:]')" -v line="$2" '
    function add() { if (line != "" && !done) { print line; done = 1 } }
    function flush() { while (blank) { print ""; blank-- } }
    /^# / {
      if (on) { add(); blank = blank ? blank : 1 }
      flush()
      on = ($0 == "# SSH Passwords"); seen = seen || on
      print
      if (on) { print ""; skip = 1 }
      next
    }
    /^$/ { if (skip) next; blank++; cont = 0; next }
    # The wrapped rest of the line being replaced goes with it.
    cont && /^[ \t]+[^ \t]/ { next }
    { skip = 0; cont = 0; flush() }
    on && /^- [^ :]+: / {
      k = substr($2, 1, length($2) - 1)
      if (tolower(k) == want) { add(); cont = 1; next }
    }
    { print }
    END {
      if (on) add()
      else {
        flush()
        if (!seen && line != "") {
          if (NR) print ""
          print "# SSH Passwords"; print ""; print line
        }
      }
    }
  ' "$PW_USER_MD" > "$pwe_tmp" &&
    mv "$pwe_tmp" "$PW_USER_MD"
}

# The entry's own field that names the target it is for.
PW_BIND_FIELD=hostwarden

pw_op_ref_bind() {
  # op://vault/item/[section/]field → op://vault/item/hostwarden
  printf '%s\n' "$1" | awk -F/ -v f="$PW_BIND_FIELD" \
    '{ print $1 "//" $3 "/" $4 "/" f }'
}

# A service-account token or a Secrets Manager access token, where
# the user stored one (bin/hostwarden-password token), reaches the
# manager's CLI in its environment, never in its arguments.
pw_token() {
  pw_local_get "$(pw_backend)" token "$1"
}

# pw_op and pw_bws exec the CLI, so that pw_limit's kill reaches
# it: they run only as pw_limit's command, in its background
# subshell, where exec replaces that subshell and nothing else.
pw_op() {
  pwo_t=$(pw_token 1password) && [ -n "$pwo_t" ] || {
    echo "1Password is used only through a service account; the user" \
      "stores its token: bin/hostwarden-password token 1password" >&2
    exit 1
  }
  OP_SERVICE_ACCOUNT_TOKEN=$pwo_t
  export OP_SERVICE_ACCOUNT_TOKEN
  exec op "$@"
}

pw_bws() {
  pwb_t=$(pw_token bws) && [ -n "$pwb_t" ] || {
    echo "no Secrets Manager access token stored on this machine" >&2
    exit 1
  }
  BWS_ACCESS_TOKEN=$pwb_t
  export BWS_ACCESS_TOKEN
  exec bws "$@"
}

# pw_limit <seconds> <command…> — the command, killed once it has
# run that long. A manager's CLI that hangs on the network, or on a
# prompt a process without a terminal never sees, would keep ssh
# waiting with it.
pw_limit() {
  pwl_s=$1
  shift
  "$@" &
  pwl_p=$!
  # Its own output goes nowhere: a sleep that still holds ssh's pipe
  # would keep ssh waiting for the end of the answer.
  (sleep "$pwl_s"; kill "$pwl_p" 2>/dev/null) >/dev/null 2>&1 &
  pwl_w=$!
  wait "$pwl_p"
  pwl_rc=$?
  kill "$pwl_w" 2>/dev/null
  return "$pwl_rc"
}

# pw_manager_field <source> <target> <what> — <what> is bind or
# secret; prints that field of the entry.
pw_manager_field() {
  pwm_kind=${1%% *} pwm_ref=${1#* }
  pwm_user=${2%%@*}
  case $pwm_kind in
    1password)
      if [ "$3" = bind ]; then
        pw_limit 30 pw_op read --no-newline "$(pw_op_ref_bind "$pwm_ref")"
      else
        pw_limit 30 pw_op read --no-newline "$pwm_ref"
      fi ;;
    rbw)
      # <profile>/<item>: the profile is the Hostwarden account's own.
      pwm_prof=${pwm_ref%%/*} pwm_ref=${pwm_ref#*/}
      env RBW_PROFILE="$pwm_prof" rbw unlocked >/dev/null 2>&1 || {
        echo "rbw profile $pwm_prof is locked: the user runs" \
          "RBW_PROFILE=$pwm_prof rbw unlock" >&2
        return 1
      }
      # --field matches a substring of the field's name, case aside:
      # the entry must have no other field whose name holds it.
      if [ "$3" = bind ]; then
        pw_limit 15 env RBW_PROFILE="$pwm_prof" \
          rbw get --field "$PW_BIND_FIELD" "$pwm_ref" "$pwm_user"
      else
        pw_limit 15 env RBW_PROFILE="$pwm_prof" rbw get "$pwm_ref" "$pwm_user"
      fi ;;
    bws)
      pw_has jq || { echo "bws needs jq to read its answer" >&2; return 1; }
      # The secret's name, its key, is the target it is for. bws's
      # own status decides, before jq reads what it printed.
      pwm_json=$(pw_limit 15 pw_bws secret get "$pwm_ref" --output json) ||
        return 1
      if [ "$3" = bind ]; then
        printf '%s' "$pwm_json" | jq -er .key
      else
        printf '%s' "$pwm_json" | jq -er .value
      fi ;;
    *) return 1 ;;
  esac
}

# pw_manager_scoped <source> — true when the identity the source
# goes through is Hostwarden's own: a 1Password token that sees
# exactly one vault, the one the reference names; an rbw profile
# that is set up. What an rbw account's collections hold, only the
# user can say (rules/ssh-passwords.md → Passwords in a Manager).
pw_manager_scoped() {
  pws_kind=${1%% *} pws_ref=${1#* }
  case $pws_kind in
    1password)
      pw_has jq || { echo "1password needs jq to read its answer" >&2; return 1; }
      pws_json=$(pw_limit 30 pw_op vault list --format json) || return 1
      pws_n=$(printf '%s' "$pws_json" | jq -er length) || return 1
      if [ "$pws_n" != 1 ]; then
        echo "the service account sees $pws_n vaults; it must see one," \
          "kept for Hostwarden alone" >&2
        return 1
      fi
      pws_v=$(printf '%s\n' "$pws_ref" | cut -d/ -f3 | tr '[:upper:]' '[:lower:]')
      printf '%s' "$pws_json" |
        jq -e --arg v "$pws_v" '.[0] | (.name | ascii_downcase) == $v or (.id | ascii_downcase) == $v' \
        >/dev/null || {
        echo "the reference names another vault than the service" \
          "account's one" >&2
        return 1
      } ;;
    rbw)
      pws_prof=${pws_ref%%/*}
      env RBW_PROFILE="$pws_prof" rbw config show 2>/dev/null |
        grep -q '"email"' || {
        echo "rbw profile $pws_prof is not set up: RBW_PROFILE=$pws_prof" \
          "rbw config set email <the Hostwarden account>" >&2
        return 1
      } ;;
    bws) pw_token bws >/dev/null || {
        echo "no Secrets Manager access token stored on this machine" >&2
        return 1
      } ;;
    *) return 1 ;;
  esac
}

pw_manager_bound() {
  pwmb=$(pw_manager_field "$1" "$2" bind) || return 1
  pwmb=$(printf %s "$pwmb" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
  [ "$pwmb" = "$(printf %s "$2" | tr '[:upper:]' '[:lower:]')" ]
}

pw_manager_get() {
  pw_manager_bound "$1" "$2" || {
    echo "the entry's $PW_BIND_FIELD field does not name $2" >&2
    return 1
  }
  pw_manager_field "$1" "$2" secret
}

# --- Only where no key can log in -----------------------------
# A host whose sshd offers publickey takes a key or a certificate,
# and gets no password from Hostwarden. What it offers is the list
# it names after a login with the method none, which authenticates
# nothing (rules/host-keys.md uses the same call). The answer is kept
# per target in the cache bin/hostwarden-askpass reads.
pw_methods_file() {
  printf '%s/askpass/methods-%s\n' "$HOSTWARDEN_CACHE" \
    "$(printf %s "$1" | cksum | cut -d' ' -f1)"
}

pw_probe() {
  pwp_out=$(ssh -F "$PW_ROOT/memory/ssh_config" -o ControlMaster=no \
    -o ControlPath=none -o BatchMode=yes -o PreferredAuthentications=none \
    -o ForwardAgent=no -o ClearAllForwardings=yes -l "$1" "$2" true \
    2>&1 </dev/null)
  # Only the target's own refusal counts: ssh names the user and host
  # it was refused by, and a jump host's refusal names the jump host.
  pwp_m=$(printf '%s\n' "$pwp_out" | awk -v want="${3%:*}: permission denied (" '
    BEGIN { want = tolower(want) }
    { l = tolower($0) }
    index(l, want) == 1 {
      m = substr($0, length(want) + 1); sub(/\).*/, "", m); last = m }
    END { if (last != "") print last }')
  [ -n "$pwp_m" ] || return 1
  (
    umask 077
    mkdir -p "$HOSTWARDEN_CACHE/askpass" &&
      printf '%s\n' "$pwp_m" > "$(pw_methods_file "$3")"
  ) || return 1
  echo "$pwp_m"
}

# A host takes a password only where it offers password or
# keyboard-interactive, and no publickey.
pw_keyless() {
  pwk_f=$(pw_methods_file "$1")
  [ -n "$(find "$pwk_f" -mtime -"${2:-30}" 2>/dev/null)" ] || return 1
  ! grep -q publickey "$pwk_f" &&
    grep -Eq '(^|,)(password|keyboard-interactive)(,|$)' "$pwk_f"
}
