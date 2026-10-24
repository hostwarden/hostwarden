# shellcheck shell=sh
# identity.sh — Hostwarden's own SSH identity, as memory/user.md
# records it (rules/ssh-identity.md), for bin/hostwarden-identity,
# bin/hostwarden-ssh-config and bin/hostwarden-doctor.
#
# Sourced, never executed. Never sources user.md or evaluates its
# values. The lines, unindented, under `# SSH Identity`:
#
#   SSH identity: own-agent | manager | hardware | none
#   SSH identity key: ~/.ssh/hostwarden_ed25519.pub
#   SSH identity agent: ~/.cache/hostwarden/agent.sock
#   SSH identity source: 1password op://<vault>/<item>/<field>?ssh-format=openssh
#   SSH identity source: bws <secret id>
#   SSH identity source: file ~/.ssh/hostwarden_ed25519
#   SSH identity certificate: ~/.ssh/hostwarden_ed25519-cert.pub
#   SSH identity renew: <the user's own command>
#
# `none` records that the user declined; it is no identity. The
# source is where `bin/hostwarden-identity load` takes the private
# key from, for Hostwarden's own agent only. The certificate is the
# one the user's CA issues for the key (rules/ssh-ca.md →
# Hostwarden's Own Certificate); the renew line is only printed,
# never run.
#
# Expects ID_ROOT, the checkout. Defines:
#   id_read      — sets ID_KIND, ID_KEY, ID_AGENT, ID_SOURCE, ID_CERT
#                  and ID_RENEW, the paths with ~/ expanded; fails,
#                  with the reason on
#                  stderr, on a line that is there twice or does not
#                  parse. ID_KIND is empty where nothing is recorded
#   id_recorded  — true when an identity other than none is recorded
#   id_path <value>
#                — ID_PATH, the value as an absolute path; fails on
#                  anything ssh_config or a shell would read as more
#                  than a path
#   id_fingerprint
#                — the SHA256 fingerprint of ID_KEY, on stdout

id_error() { echo "hostwarden: $*" >&2; return 1; }

id_path() {
  ID_PATH=$1
  # shellcheck disable=SC2088 # a literal tilde, expanded here
  case "$ID_PATH" in '~/'*) ID_PATH=$HOME/${ID_PATH#\~/} ;; esac
  case "$ID_PATH" in
    *\"*|*\$*|*%*|*\\*|*'`'*|*'
'*|*"$(printf '\r')"*)
      id_error "SSH identity: \"$1\" holds a character memory/ssh_config cannot name"
      return 1 ;;
    /*) ;;
    *) id_error "SSH identity: \"$1\" must be absolute or start with ~/"; return 1 ;;
  esac
}

id_read() {
  ID_KIND='' ID_KEY='' ID_AGENT='' ID_SOURCE='' ID_CERT='' ID_RENEW=''
  ID_USER_MD=$ID_ROOT/memory/user.md
  [ ! -L "$ID_USER_MD" ] || {
    id_error 'memory/user.md is a link; the SSH identity is not read'
    return 1
  }
  [ -f "$ID_USER_MD" ] || return 0
  idr_out=$(awk '
    /^SSH identity( key| agent| source| certificate| renew)?:/ {
      k = $0; sub(/:.*/, "", k)
      v = $0; sub(/^[^:]*:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
      if (k in seen) { print "twice " k; bad = 1; exit }
      seen[k] = 1
      print k "\t" v
    }
    END { exit bad }
  ' "$ID_USER_MD") || {
    id_error "memory/user.md has more than one \"${idr_out##*twice }:\" line"
    return 1
  }
  idr_tab=$(printf '\t')
  while IFS= read -r idr_l; do
    [ -n "$idr_l" ] || continue
    idr_v=${idr_l#*"$idr_tab"}
    case ${idr_l%%"$idr_tab"*} in
      'SSH identity') ID_KIND=$idr_v ;;
      'SSH identity key') ID_KEY=$idr_v ;;
      'SSH identity agent') ID_AGENT=$idr_v ;;
      'SSH identity source') ID_SOURCE=$idr_v ;;
      'SSH identity certificate') ID_CERT=$idr_v ;;
      'SSH identity renew') ID_RENEW=$idr_v ;;
    esac
  done <<EOF
$idr_out
EOF
  case $ID_KIND in
    '') [ -z "$ID_KEY$ID_AGENT$ID_SOURCE$ID_CERT$ID_RENEW" ] ||
          { id_error 'memory/user.md has "SSH identity …:" lines without an "SSH identity:" line'; return 1; }
        return 0 ;;
    none) return 0 ;;
    own-agent|manager|hardware) ;;
    *) id_error "SSH identity: \"$ID_KIND\" is none of own-agent, manager, hardware, none"
       return 1 ;;
  esac
  [ -n "$ID_KEY" ] && [ -n "$ID_AGENT" ] ||
    { id_error 'an SSH identity needs both "SSH identity key:" and "SSH identity agent:"'; return 1; }
  id_path "$ID_KEY" || return 1
  ID_KEY=$ID_PATH
  case $ID_KEY in
    *.pub) ;;
    *) id_error 'SSH identity key: name the public key, a file ending in .pub'; return 1 ;;
  esac
  id_path "$ID_AGENT" || return 1
  ID_AGENT=$ID_PATH
  if [ -n "$ID_CERT" ]; then
    id_path "$ID_CERT" || return 1
    ID_CERT=$ID_PATH
    case $ID_CERT in
      *-cert.pub) ;;
      *) id_error 'SSH identity certificate: name the certificate, a file ending in -cert.pub'; return 1 ;;
    esac
  elif [ -n "$ID_RENEW" ]; then
    id_error '"SSH identity renew:" needs an "SSH identity certificate:" line'
    return 1
  fi
  case $ID_KIND:$ID_SOURCE in
    manager:?*) id_error "a password manager's agent holds the key itself; drop \"SSH identity source:\""
      return 1 ;;
    manager:*) ;;
    *:'') ;;
    *:'file '*)
      id_path "${ID_SOURCE#file }" || return 1
      ID_SOURCE="file $ID_PATH" ;;
    own-agent:*)
      # The characters lib/passwords.sh lets a source name, and the
      # query 1Password needs for a key in OpenSSH format.
      printf '%s\n' "$ID_SOURCE" | grep -Eqx \
"1password op://[A-Za-z0-9 ._()-]+/[A-Za-z0-9 ._()-]+/[A-Za-z0-9 ._()-]+(\?ssh-format=openssh)?|\
bws [0-9a-fA-F-]{36}" || {
        id_error "SSH identity source: \"$ID_SOURCE\" is none of file, 1password, bws"
        return 1
      } ;;
    *) id_error "SSH identity source: a hardware key's source is its file"
       return 1 ;;
  esac
}

# id_fingerprint — the key's SHA256 fingerprint, from the public key;
# fails where it reads none.
id_fingerprint() {
  idf=$(LC_ALL=C ssh-keygen -E sha256 -lf "$ID_KEY" 2>/dev/null |
    awk '{ print $2; exit }')
  [ -n "$idf" ] && printf '%s\n' "$idf"
}

id_recorded() {
  case $ID_KIND in own-agent|manager|hardware) return 0 ;; esac
  return 1
}
