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
#   pw_local_probe <backend> <kind> <key>
#                        — 0 held, 1 not held, 2 store not reachable
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

# The key is created exclusively: two first runs at once each make
# one, and ln keeps the first and fails for the second, which then
# uses the winner's. A plain mv would replace it, and what the
# first run encrypted could no longer be read.
pw_file_key() {
  [ -s "$PW_FILE_KEY" ] && return 0
  (
    umask 077
    mkdir -p "${PW_FILE_KEY%/*}" &&
      openssl rand -hex 32 > "$PW_FILE_KEY.$$" &&
      { ln "$PW_FILE_KEY.$$" "$PW_FILE_KEY" 2>/dev/null || :; }
    rm -f "$PW_FILE_KEY.$$"
    [ -s "$PW_FILE_KEY" ]
  )
}

pw_local_has() {
  case $1 in
    keychain)
      security find-generic-password -s "$(pw_service "$2")" -a "$3" \
        >/dev/null 2>&1 ;;
    # Held only where it can be read: a file restored or synced
    # without its key is a password the helper cannot give. remove
    # asks pw_local_probe instead, which counts the file alone.
    file) [ -f "$(pw_file "$2" "$3")" ] && [ -s "$PW_FILE_KEY" ] ;;
    *) return 1 ;;
  esac
}

# pw_local_probe <backend> <kind> <key> — 0 when the store holds it,
# 1 when it does not, 2 when the store could not be asked: a keychain
# that is locked or unreachable answers with a status of its own, and
# only 44 means no such item. A store this machine does not have holds
# nothing.
# pw_askpass_ok — true when ssh here is OpenSSH 8.4 or newer. Earlier
# ones ignore SSH_ASKPASS_REQUIRE and run the helper only under a
# display; a call without a terminal then sends an empty password,
# which the host counts as a failed login.
pw_askpass_ok() {
  ssh -V 2>&1 | awk '{ if (match($0, /OpenSSH_[0-9]+\.[0-9]+/)) {
    split(substr($0, RSTART + 8, RLENGTH - 8), v, ".")
    ok = v[1] > 8 || (v[1] == 8 && v[2] >= 4) } }
    END { exit !ok }'
}

pw_local_probe() {
  case $1 in
    keychain)
      # Without security a Mac's keychain cannot be asked, and its
      # password may be there; any other system has no keychain.
      if ! pw_has security; then
        [ "$(uname -s)" = Darwin ] && return 2
        return 1
      fi
      security find-generic-password -s "$(pw_service "$2")" -a "$3" \
        >/dev/null 2>&1
      case $? in 0) return 0 ;; 44) return 1 ;; *) return 2 ;; esac ;;
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
      on && /^- [^ ]+: / {
        k = substr($2, 1, length($2) - 1)
        if (tolower(k) == want) {
          sub(/^- [^ ]+: +/, ""); v = $0; found = 1
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
    on && /^- [^ ]+: / {
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

# The rest, in this order: what one part defines, the next reads. The
# managers and the methods a host offers are in passwords/.
# shellcheck source=passwords/managers.sh
. "$PW_ROOT/lib/passwords/managers.sh"
