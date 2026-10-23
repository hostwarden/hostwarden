# shellcheck shell=sh
# hostwarden-doctor, sourced: the agents and key files ssh offers,
# and whether a key file has no passphrase or no agent holds it
# (website/docs/getting-started/install.md → SSH keys). Reads has,
# row, miss, real_ssh, ssh_conf_each, ROOT and INSTALL_DOCS.
#
# A WARN, never a refusal. Hostwarden never creates a key, never
# adds one to an agent and never reads a private key itself: the
# looks at a key file are ssh-keygen's, deriving its public half
# with an empty passphrase, which succeeds only where the file has
# none and of which only the key type is matched, and printing the
# fingerprint of its public half.

# shellcheck source=../ssh-agent.sh
. "$ROOT/lib/ssh-agent.sh"

# How long ssh -G, and then ssh-add -l, may each take, in seconds.
KEYS_LIMIT=5

# keys_limit <file> <command…> — the command's output in <file>,
# the command killed past KEYS_LIMIT, which returns 3. ssh -G runs a
# Match exec of the user's own configuration as the session's first
# call would, and an agent may wait to be unlocked: either would
# hold up session start. The output goes to a file, not a pipe, so
# a process left behind cannot hold the doctor's output open; no
# coreutils timeout, which macOS lacks.
keys_limit() {
  o=$1
  shift
  LC_ALL=C "$@" </dev/null >"$o" 2>/dev/null &
  p=$!
  # The watchdog takes its sleep with it when it is stopped.
  (sleep "$KEYS_LIMIT" & s=$!; trap 'kill "$s"; exit' TERM
    wait "$s"; kill "$p") >/dev/null 2>&1 &
  w=$!
  # dash reports a job killed by a signal on wait's stderr.
  wait "$p" 2>/dev/null
  rc=$?
  kill "$w" 2>/dev/null
  # A signal's status is above 128; ssh's own failure is 255.
  if [ "$rc" -gt 128 ] && [ "$rc" -ne 255 ]; then return 3; fi
  return "$rc"
}

# keys_fleet — the operations host's fleet key, which belongs there
# without a passphrase: the Fleet key line of memory/user.md, or its
# default (hostwarden-fleet-read → references/operations-host.md),
# in KEYS_FLEET_PATH. A user.md that is a link is not read, as
# lib/ssh-agent.sh reads none.
keys_fleet() {
  KEYS_FLEET_PATH=$HOME/.ssh/id_fleet_read
  u=$ROOT/memory/user.md
  [ -f "$u" ] && [ ! -L "$u" ] || return 0
  while IFS= read -r l; do
    case $l in
      'Fleet key:'*)
        l=${l#Fleet key:} l=${l#"${l%%[![:space:]]*}"}
        l=${l%"${l##*[![:space:]]}"}
        case $l in \~/*) l=$HOME/${l#\~/} ;; esac
        [ -z "$l" ] || KEYS_FLEET_PATH=$l ;;
    esac
  done < "$u"
}

# keys_agent_name <socket> — the agent a socket path names, where
# its path says so.
keys_agent_name() {
  case $1 in
    *1password*|*1Password*) echo 1Password ;;
    *[Bb]itwarden*) echo Bitwarden ;;
    *[Kk]ee[Pp]ass[Xx][Cc]*|*keepassxc*) echo KeePassXC ;;
    *[Ss]ecretive*) echo Secretive ;;
    *yubikey-agent*) echo yubikey-agent ;;
    *gpg-agent*) echo gpg-agent ;;
    */com.apple.launchd.*/Listeners) echo "ssh-agent (launchd)" ;;
    *ssh-agent*|*/ssh-*/agent.*) echo ssh-agent ;;
    *) echo "an agent" ;;
  esac
}

# keys_path <identityfile> — the path ssh -G printed, with ~ and the
# tokens that do not depend on the host filled in, in KEYS_PATH;
# returns 1 for none, 2 where a token or variable depends on the
# host or the environment.
keys_path() {
  f=$1 r=''
  # shellcheck disable=SC2016 # a literal ${ in the path
  case $f in none) return 1 ;; *'${'*) return 2 ;; esac
  case $f in \~/*) f=$HOME/${f#\~/} ;; esac
  while :; do
    case $f in
      *%*)
        r=$r${f%%\%*} f=${f#*%}
        case $f in
          d*) r=$r$HOME ;;
          u*) r=$r${USER:-$(id -un)} ;;
          %*) r=$r% ;;
          *) return 2 ;;
        esac
        f=${f#?} ;;
      *) KEYS_PATH=$r$f; return 0 ;;
    esac
  done
}

# keys_show <path> — the path as a row shows it, ~ for the home.
keys_show() {
  # shellcheck disable=SC2088 # a literal ~ is what the row shows
  case $1 in "$HOME"/*) echo '~/'"${1#"$HOME"/}" ;; *) echo "$1" ;; esac
}

# A tab, which no socket path in an agent's list line holds.
KEYS_TAB=$(printf '\t')

# keys_agent_list <socket> <file> — ssh-add -l through <socket>, its
# status in KA_RC (3: no answer in time, an agent waiting to be
# unlocked, perhaps), the identities in KA_N and of them hardware in
# KA_HW; their fingerprints, public, go to KEYS_FPS as
# <socket><tab><fingerprint> lines, and nothing else of the lines is
# kept. 1 is an agent that answers with none, in a sentence that is
# no key. Through env: an assignment in front of a function may
# outlast it, as in bash's POSIX mode, macOS's sh.
keys_agent_list() {
  KA_N=0 KA_HW=0
  keys_limit "$2" env SSH_AUTH_SOCK="$1" ssh-add -l
  KA_RC=$?
  [ "$KA_RC" -eq 0 ] || return 0
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    KA_N=$((KA_N + 1))
    case $l in *-SK\)) KA_HW=$((KA_HW + 1)) ;; esac
    l=${l#* } KEYS_FPS="$KEYS_FPS$1$KEYS_TAB${l%% *}
"
  done < "$2"
}

# keys_conf_applies — whether the block SSH_CONF_HOSTS names applies
# to a host Hostwarden knows, one with a directory under
# memory/machines/ (KEYS_HOSTS) or an alias of one (KEYS_ALIASES),
# or to every host. A block for another service, a Git forge's, is
# none of Hostwarden's business. As ssh reads them, a host matches
# where one pattern matches it and no negated one does.
keys_conf_applies() {
  set -f
  case " $SSH_CONF_HOSTS " in
    *' !'*) ;;
    *' * '*) set +f; return 0 ;;
  esac
  for h in $KEYS_HOSTS $KEYS_ALIASES; do
    m=0
    for p in $SSH_CONF_HOSTS; do
      # shellcheck disable=SC2254 # the pattern is ssh's, a glob
      case $p in
        '!'*) case $h in ${p#!}) m=2; break ;; esac ;;
        *) case $h in $p) m=1 ;; esac ;;
      esac
    done
    [ "$m" -ne 1 ] || { set +f; return 0; }
  done
  set +f
  return 1
}

# keys_block_agent — the agent the block SSH_CONF_HOSTS names, from
# the first walk's KEYS_BLOCK_AGENTS, in KEYS_BLOCK_AGENT; empty for
# the default agent.
keys_block_agent() {
  KEYS_BLOCK_AGENT=''
  while IFS= read -r l; do
    case $l in
      "$SSH_CONF_HOSTS$KEYS_TAB"*)
        KEYS_BLOCK_AGENT=${l#"$SSH_CONF_HOSTS$KEYS_TAB"}
        return ;;
    esac
  done <<EOF
$KEYS_BLOCK_AGENTS
EOF
}

# keys_conf_alias — ssh_conf_each's callback for a first walk: a
# block whose HostName is a host Hostwarden knows makes its patterns
# names of that host, an alias the second walk then accepts. A
# HostName with a token stands for no one host. It also notes the
# agent each block names, which may stand below the block's key
# files.
keys_conf_alias() {
  if [ "$1" = identityagent ]; then
    KEYS_BLOCK_AGENTS="$KEYS_BLOCK_AGENTS$SSH_CONF_HOSTS$KEYS_TAB$2
"
    return 1
  fi
  [ "$1" = hostname ] || return 1
  case $2 in *%*) return 1 ;; esac
  case " $KEYS_HOSTS " in
    *" $2 "*)
      set -f
      for p in $SSH_CONF_HOSTS; do
        case $p in '!'*|'*') ;; *) KEYS_ALIASES="$KEYS_ALIASES $p" ;; esac
      done
      set +f ;;
  esac
  return 1
}

# keys_conf_line — ssh_conf_each's callback: the IdentityFile and
# IdentityAgent lines of the user's own configuration, in the blocks
# keys_conf_applies accepts, host blocks included, which the neutral
# host's ssh -G never reaches.
keys_conf_line() {
  [ "$1" != hostname ] || return 1
  keys_conf_applies || return 1
  case $1 in
    # Each file with the agent its block names, the default's empty.
    identityfile) keys_block_agent
      files="$files$KEYS_BLOCK_AGENT$KEYS_TAB$2
" ;;
    identityagent) agents="$agents$2
" ;;
  esac
  return 1
}

# ssh_keys <config or empty> <host> — the classification of the
# keys ssh offers: those ssh -G gives <host>, which every host gets,
# and those of any host's own block in ~/.ssh/config. Sets
# KEYS_AGENT (its name, empty where none answers), KEYS_AGENT_N
# (identities it lists), KEYS_AGENT_HW (of them, hardware),
# KEYS_AGENT_SLOW (set where it did not answer in time),
# KEYS_AGENT_MORE (a line per agent a host's own block names:
# name, then its count or "no answer within N seconds"),
# KEYS_MORE_SLOW (set where one of those did not answer), and
# newline-separated lists of key files: KEYS_HW (hardware),
# KEYS_BARE (no passphrase), KEYS_LOCKED (a passphrase), of them
# KEYS_HELD (one the agent its login uses holds) and KEYS_ALONE (one
# that agent answers without),
# KEYS_UNMATCHED (a passphrase, and an agent the doctor did not
# ask, so held is not known), KEYS_UNREAD (not a key ssh-keygen
# reads, or not readable),
# KEYS_UNCHECKED (a path ssh fills in per host), and KEYS_FLEET,
# the operations host's fleet key where ssh offers it without a
# passphrase, which is no finding. Returns 3 where ssh -G took too
# long, its status where it failed.
ssh_keys() {
  KEYS_AGENT='' KEYS_AGENT_N=0 KEYS_AGENT_HW=0 KEYS_AGENT_SLOW=''
  KEYS_AGENT_MORE='' KEYS_MORE_SLOW='' KEYS_FLEET='' KEYS_FPS=''
  KEYS_HW='' KEYS_BARE='' KEYS_LOCKED='' KEYS_HELD='' KEYS_ALONE=''
  KEYS_UNREAD='' KEYS_UNCHECKED='' KEYS_UNMATCHED=''
  g=$(mktemp "${TMPDIR:-/tmp}/hostwarden-doctor.XXXXXX") || return 1
  if [ -n "$1" ]; then
    keys_limit "$g" ssh -F "$1" -G "$2"
  else
    keys_limit "$g" ssh -G "$2"
  fi
  rc=$?
  [ "$rc" -eq 0 ] || { rm -f "$g"; return "$rc"; }
  sock=$SSH_AUTH_SOCK files='' agents=''
  while IFS= read -r l; do
    case $l in
      'identityagent '*)
        sock=${l#identityagent }
        [ "$sock" != none ] || sock=''
        ! hw_agent_dynamic "$sock" || sock=$SSH_AUTH_SOCK ;;
      'identityfile '*) files="$files$KEYS_TAB${l#identityfile }
" ;;
    esac
  done < "$g"
  KEYS_HOSTS=''
  for d in "$ROOT"/memory/machines/*/; do
    [ -d "$d" ] || continue
    d=${d%/} KEYS_HOSTS="$KEYS_HOSTS ${d##*/}"
  done
  KEYS_ALIASES='' KEYS_BLOCK_AGENTS=''
  ssh_conf_each "$HOME/.ssh/config" 0 keys_conf_alias
  ssh_conf_each "$HOME/.ssh/config" 0 keys_conf_line
  if [ -n "$sock" ] && [ -S "$sock" ] && has ssh-add; then
    keys_agent_list "$sock" "$g"
    [ "$KA_RC" -ne 3 ] || KEYS_AGENT_SLOW=1
    [ "$KA_RC" -gt 1 ] && [ "$KA_RC" -ne 3 ] \
      || KEYS_AGENT=$(keys_agent_name "$sock")
    KEYS_AGENT_N=$KA_N KEYS_AGENT_HW=$KA_HW
  fi
  # A host's own agent, each once. One whose path ssh fills in per
  # host is not asked.
  seen="
$sock
"
  while IFS= read -r a; do
    case $a in ''|none|*%*|*'${'*) continue ;; esac
    ! hw_agent_dynamic "$a" || continue
    case $seen in *"
$a
"*) continue ;; esac
    seen="$seen$a
"
    [ -S "$a" ] && has ssh-add || continue
    keys_agent_list "$a" "$g"
    case $KA_RC in
      0|1) KEYS_AGENT_MORE="$KEYS_AGENT_MORE$(keys_agent_name "$a"), $KA_N keys
" ;;
      3) KEYS_MORE_SLOW=1
        KEYS_AGENT_MORE="$KEYS_AGENT_MORE$(keys_agent_name "$a"), no answer\
 within $KEYS_LIMIT seconds
" ;;
    esac
  done <<EOF
$agents
EOF
  rm -f "$g"
  keys_fleet
  seen='
'
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    # The agent that login uses: its block's, else the default.
    ag=${l%%"$KEYS_TAB"*} l=${l#*"$KEYS_TAB"}
    [ -n "$ag" ] || ag=$sock
    # An agent the doctor did not ask — the environment's where the
    # default is another, or a path with a variable or a token —
    # leaves the file unmatched: neither held nor alone.
    unk=''
    if hw_agent_dynamic "$ag"; then
      ag=$SSH_AUTH_SOCK
      [ "$ag" = "$sock" ] || unk=1
    fi
    # shellcheck disable=SC2016 # a literal $ in the path
    case $ag in none) ag='' ;; *%*|*'$'*) unk=1 ;; esac
    keys_path "$l"
    case $? in
      1) continue ;;
      2) KEYS_UNCHECKED="$KEYS_UNCHECKED$l
"; continue ;;
    esac
    f=$KEYS_PATH
    # A .pub names a key the agent holds; it is no private key.
    case $f in *.pub) continue ;; esac
    case $seen in *"
$f
"*) continue ;; esac
    seen="$seen$f
"
    [ -f "$f" ] || continue
    # The public half beside it names a hardware key at no cost.
    { read -r t _ < "$f.pub"; } 2>/dev/null || t=''
    case $t in sk-*) KEYS_HW="$KEYS_HW$f
"; continue ;; esac
    # Its public half, or ssh-keygen's reason, which names the file
    # and no more.
    t=$(LC_ALL=C ssh-keygen -y -P '' -f "$f" </dev/null 2>&1)
    case $t in
      *'incorrect passphrase'*)
        KEYS_LOCKED="$KEYS_LOCKED$f
"
        # Its fingerprint, from the public half beside it or the one
        # a key file of OpenSSH's own format carries in the clear,
        # against the list of the agent that login uses. Unknown, it
        # is neither.
        t=$(ssh-keygen -l -f "$f.pub" 2>/dev/null) \
          || t=$(ssh-keygen -l -f "$f" </dev/null 2>/dev/null) || t=''
        t=${t#* } t=${t%% *}
        case $t in
          '') ;;
          *) if [ -n "$unk" ]; then
              KEYS_UNMATCHED="$KEYS_UNMATCHED$f
"
            else case "
$KEYS_FPS" in
              *"
$ag$KEYS_TAB$t
"*) KEYS_HELD="$KEYS_HELD$f
" ;;
              *) KEYS_ALONE="$KEYS_ALONE$f
" ;;
            esac; fi ;;
        esac ;;
      sk-*) KEYS_HW="$KEYS_HW$f
" ;;
      ssh-*|ecdsa-*)
        if [ "$f" = "$KEYS_FLEET_PATH" ]; then KEYS_FLEET=$f
        else KEYS_BARE="$KEYS_BARE$f
"; fi ;;
      *) KEYS_UNREAD="$KEYS_UNREAD$f
" ;;
    esac
  done <<EOF
$files
EOF
}

# The section: rows, and the lines --quiet prints too. The neutral
# host of lib/ssh-agent.sh stands for every host: it matches the
# blocks that apply to all of them, never a host's own, and none of
# the password hosts' Match exec blocks bin/hostwarden-ssh-config
# writes.
keys_report() {
  [ -n "$QUIET" ] || echo "SSH keys"
  cfg=''
  [ -f "$ROOT/memory/ssh_config" ] && cfg=$ROOT/memory/ssh_config
  ssh_keys "$cfg" "$HW_AGENT_NEUTRAL_HOST"
  case $? in
    0) why='' ;;
    3) why="took longer than $KEYS_LIMIT seconds; a Match exec in your\
 own SSH configuration is the usual cause" ;;
    *) why="failed; run it by hand to see why" ;;
  esac
  if [ -n "$why" ]; then
    row "skipped  ssh -G ${why%%;*}"
    miss keys "key check skipped" "ssh -G${cfg:+ over memory/ssh_config} $why"
    return
  fi
  if [ -n "$KEYS_AGENT_SLOW" ]; then
    row "agent    $KEYS_AGENT, no answer within $KEYS_LIMIT seconds"
  elif [ -n "$KEYS_AGENT" ]; then
    row "agent    $KEYS_AGENT, $KEYS_AGENT_N keys, $KEYS_AGENT_HW hardware"
  else
    row "agent    none answers"
  fi
  while IFS= read -r a; do
    [ -n "$a" ] && row "agent    $a, a host's own"
  done <<EOF
$KEYS_AGENT_MORE
EOF
  while IFS= read -r f; do
    [ -n "$f" ] && row "hardware $(keys_show "$f")"
  done <<EOF
$KEYS_HW
EOF
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case $KEYS_HELD in
      *"$f
"*) row "file     $(keys_show "$f"), passphrase set, in an agent" ;;
      *) case $KEYS_UNMATCHED in
          *"$f
"*) row "file     $(keys_show "$f"), passphrase set, agent not asked" ;;
          *) row "file     $(keys_show "$f"), passphrase set" ;;
        esac ;;
    esac
  done <<EOF
$KEYS_LOCKED
EOF
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    s=$(keys_show "$f")
    row "WARN     $s, no passphrase"
    miss keys "$s" "no passphrase; keep the key in an agent that confirms\
 each use, or on a hardware key ($INSTALL_DOCS#ssh-keys)"
  done <<EOF
$KEYS_BARE
EOF
  while IFS= read -r f; do
    [ -n "$f" ] && row "unchecked $f, a path ssh fills in per host"
  done <<EOF
$KEYS_UNCHECKED
EOF
  while IFS= read -r f; do
    [ -n "$f" ] && row "unread   $(keys_show "$f"), not a key ssh-keygen reads"
  done <<EOF
$KEYS_UNREAD
EOF
  [ -z "$KEYS_FLEET" ] \
    || row "fleet    $(keys_show "$KEYS_FLEET"), no passphrase, the fleet key"
  # A key neither agent-held nor hardware: a file with a passphrase
  # that no agent holds, which a login under BatchMode skips. An
  # agent that did not answer may hold it.
  [ -z "$KEYS_AGENT_SLOW$KEYS_MORE_SLOW" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] && miss keys "$(keys_show "$f")" "a key neither\
 agent-held nor hardware; keep it in an agent that confirms each use,\
 or use a hardware key ($INSTALL_DOCS#ssh-keys)"
  done <<EOF
$KEYS_ALONE
EOF
}

[ -n "$DEV" ] || ! real_ssh || ! has ssh-keygen || keys_report
