# shellcheck shell=sh
# hostwarden-doctor, sourced: what the probes below run to see
# whether a tool or a setting is there. Definitions only; reads has
# and ROOT, and the lib/mode.sh and lib/follow.sh functions the
# doctor has sourced already.

# An ssh on PATH that is not the shim (.claude/hooks/shim.sh): the
# one git-ssh.sh hands a push to, on the same PATH. Only looked
# for, never run.
real_ssh() {
  hostwarden_path_without_shim
  (PATH=$HOSTWARDEN_PATH && command -v ssh >/dev/null)
}

# Every call shares one connection and passes memory/ssh_config
# (AGENTS.md → SSH Options), whose Include and ProxyJump need
# OpenSSH 7.3: 7.2 rejects the file before connecting. -G parses
# and connects to nothing; the config on stdin holds only an
# Include of nothing, so the user's config, and any Match exec in
# it, stay out.
ssh_shares() {
  set --
  for o in $HOSTWARDEN_SSH_OPTIONS; do set -- "$@" -o "$o"; done
  printf 'Match all\n  Include /nonexistent/hostwarden-probe\n' |
    ssh -F /dev/stdin -G "$@" example.invalid
}

# KnownHostsCommand came with OpenSSH 8.5. An older ssh rejects the
# keyword, so bin/hostwarden-ssh-config leaves it out there; this
# names the case, and the install that brings it back.
ssh_khc() {
  ssh -F /dev/null -G -o KnownHostsCommand=none example.invalid
}

# A host that takes only a password (rules/ssh-passwords.md) needs
# SSH_ASKPASS_REQUIRE, from OpenSSH 8.4 on. -V prints the version;
# nothing else of ssh tells it without connecting.
ssh_askpass() {
  ssh -V 2>&1 | awk '{ if (match($0, /OpenSSH_[0-9]+\.[0-9]+/)) {
    split(substr($0, RSTART + 8, RLENGTH - 8), v, ".")
    ok = v[1] > 8 || (v[1] == 8 && v[2] >= 4) } }
    END { exit !ok }'
}

# .claude/skills and every DNS alias are links, and git writes a
# text file where it cannot link
# (website/docs/getting-started/install.md → Symbolic links).
# Probed in the clone: a temporary directory can sit on a
# filesystem that links when this one does not.
links_work() {
  d=$(mktemp -d "$ROOT/.link-probe.XXXXXX") || return 1
  ln -s "$d" "$d/l" 2>/dev/null
  [ -L "$d/l" ]
  rc=$?
  rm -rf "$d"
  return $rc
}

# The transport 5L.1 accepts. macOS ships a sendmail that delivers
# only while its Postfix is loaded.
mail_ok() {
  has msmtp && return 0
  # The absolute path too, as 5L.1 does: a PATH without /usr/sbin
  # is common, and the MTA puts it there.
  has sendmail || [ -x /usr/sbin/sendmail ] || return 1
  [ "$OS" = Darwin ] || return 0
  launchctl print system/com.apple.postfix.master
}

# The drives under /mnt are Windows' own filesystem: slow for git,
# and without Unix permissions unless mounted with metadata.
in_distro_fs() { case $ROOT in /mnt/?/*) return 1 ;; esac; }

# A key ssh can use from here: a key file ssh would try, or one an
# agent holds, the one in SSH_AUTH_SOCK or an IdentityAgent from
# ~/.ssh/config. Keys in Windows' ssh-agent or in a password
# manager on Windows are not reachable from WSL unless something
# relays them. Only names are checked, never contents; the common
# case, a default key file, costs no process.
key_reachable() {
  # The names ssh tries on its own (ssh_config(5) → IdentityFile).
  for f in id_rsa id_ecdsa id_ecdsa_sk id_ed25519 id_ed25519_sk; do
    [ -f "$HOME/.ssh/$f" ] && return 0
  done
  has ssh-add && ssh-add -l >/dev/null 2>&1 && return 0
  ssh_conf_key "$HOME/.ssh/config" 0
}

# ssh_conf_key <file> <depth> — an IdentityFile or IdentityAgent
# that works, in <file> or a file it includes, host blocks too.
# Read as text, never through ssh -G, which would run any Match
# exec at every session start. Include nests at most five deep,
# as a loop of includes must end somewhere.
ssh_conf_key() {
  [ "$2" -lt 5 ] && [ -r "$1" ] || return 1
  while read -r k f; do
    # Key value, Key=value and Key = value all occur.
    case $k in *=*) f=${k#*=} k=${k%%=*} ;; esac
    f=${f#=} f=${f# }
    # A quoted value ends at its closing quote; an unquoted one at
    # a # that starts a word, which ssh reads as a comment.
    case $f in
      \"*) f=${f#\"} f=${f%%\"*} ;;
      *) f=${f%%[[:space:]]#*} f=${f%"${f##*[![:space:]]}"} ;;
    esac
    case $f in \~/*) f=$HOME/${f#\~/} ;; esac
    case $k in
      [Ii][Dd][Ee][Nn][Tt][Ii][Tt][Yy][Ff][Ii][Ll][Ee]) [ -f "$f" ] && return 0 ;;
      [Ii][Dd][Ee][Nn][Tt][Ii][Tt][Yy][Aa][Gg][Ee][Nn][Tt]) [ -S "$f" ] \
        && has ssh-add && SSH_AUTH_SOCK=$f ssh-add -l >/dev/null 2>&1 \
        && return 0 ;;
      # Several names, each relative to ~/.ssh unless absolute,
      # each a glob. Split first, glob after the prefix.
      [Ii][Nn][Cc][Ll][Uu][Dd][Ee])
        set -f
        for i in $f; do
          case $i in \~/*) i=$HOME/${i#\~/} ;; /*) ;; *) i=$HOME/.ssh/$i ;; esac
          set +f
          for j in $i; do
            ssh_conf_key "$j" $(($2 + 1)) && return 0
          done
          set -f
        done
        set +f ;;
    esac
  done < "$1"
  return 1
}
