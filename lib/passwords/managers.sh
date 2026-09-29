# shellcheck shell=sh
# passwords/managers.sh — the password managers and the login methods
# a host offers. Sourced by lib/passwords.sh, after the local stores
# and the sources it defines, into the one shell both share; never
# run on its own.
# shellcheck disable=SC2034 # read by the callers of lib/passwords.sh

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
