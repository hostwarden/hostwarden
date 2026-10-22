# guard-taboos.d/identity.sh — Hostwarden's own SSH identity
# (rules/ssh-identity.md). Sourced by guard-taboos.sh, in the order
# its GUARD_MODULES lists, into the one shell every module shares;
# never run on its own.
# shellcheck shell=sh disable=SC2034 # GUARD_ROUTE: read by deny

# --- Another key than Hostwarden's own ------------------------
# Only where this checkout's memory/user.md records an identity:
# `SSH identity:` own-agent, manager or hardware. Without one,
# nothing here applies and every call runs as it does today. With
# one, memory/ssh_config offers Hostwarden's key alone to every host
# whose memory records it, and an ssh call could still log in with
# the admin's key by naming it (-i, -o IdentityFile), by naming
# another agent (-o IdentityAgent, -o IdentitiesOnly=no against a
# password manager's agent that holds the admin's keys too), by
# forwarding the admin's agent (-A), or by leaving this checkout's
# file out: -F /dev/null, another -F or none at all reads
# SSH_AUTH_SOCK, the admin's agent. So each of those is denied on
# ssh, scp and sftp, on an rsync -e "ssh …" and on an rsync to a
# remote without one, and so is any command naming a private key
# under .ssh named id_*. The one call without this checkout's file
# is a control command to a running master by its socket, `ssh -F
# /dev/null -S <socket> -O forward|cancel|check|exit`, which logs in
# nowhere. Git's route to ssh, GIT_SSH_COMMAND and
# .claude/hooks/git-ssh.sh, is not an ssh call here and keeps the
# admin's key.
#
# identity.awk reads the words. This catches the everyday mistake,
# a call copied from somewhere with -i in it, not a determined
# reader: what runs as this user reads the same files and sockets
# (docs/adr/20260924-guard-is-a-backstop-not-a-sandbox.md). What
# holds is outside the session: the agent's own confirmation, the
# key's authorized_keys options, sshd's log (rules/ssh-identity.md
# → What Holds).
#
# A private key path names .ssh, so the gate below covers it too.
case "$TEXT" in
*ssh*|*scp*|*sftp*|*rsync*)
  # The line is read by lib/identity.sh, as bin/hostwarden-ssh-config
  # reads it: a line that does not parse is no identity here either,
  # and the session start has already said so.
  ID_ON=''
  if [ -f "$HOOKDIR/../../memory/user.md" ]; then
    if [ -f "$LIBDIR/identity.sh" ]; then
      ID_ROOT=$HOOKDIR/../..
      # shellcheck source=../../../lib/identity.sh
      . "$LIBDIR/identity.sh"
      id_read 2>/dev/null && id_recorded && ID_ON=1
    else
      ID_ON=unread
    fi
  fi
  if [ -n "$ID_ON" ]; then
    # The checkout by its physical and its logical path: a session
    # names it as it found it, through a link or not (config-mgmt.sh
    # takes both for the same reason).
    ID_DIRS=$(cd "$HOOKDIR/../.." 2>/dev/null && pwd -P && pwd)
    ID_CFG="${ID_DIRS%%"
"*}/memory/ssh_config"
    ID_CFG2="${ID_DIRS#*"
"}/memory/ssh_config"
    # A reader that fails denies: it found nothing it could vouch for.
    if [ "$ID_ON" = unread ]; then
      ID_WHY=unread
    else
      ID_WHY=$(awk -v cfg="$ID_CFG" -v cfg2="$ID_CFG2" -v RS='\001' \
        -f "$HOOKDIR/guard-taboos.d/identity.awk" 2>/dev/null <<ID_EOF
$CMD
ID_EOF
) || ID_WHY=unread
    fi
    GUARD_ROUTE="Hostwarden logs in with its own SSH identity on the hosts \
whose memory records its key, and with the standard options everywhere: \
ssh -F \"$ID_CFG\" … (AGENTS.md - SSH Options, rules/ssh-identity.md). \
A public key, id_*.pub, stays readable."
    ID_MSG="this workstation records Hostwarden's own SSH identity, and"
    case $ID_WHY in
      '') ;;
      key*) deny "$ID_MSG a private key file is never read: ${ID_WHY#key }" ;;
      i) deny "$ID_MSG -i would log in with another key" ;;
      A) deny "$ID_MSG -A would forward the admin's agent to the host" ;;
      S) deny "$ID_MSG -S would run another program as ssh" ;;
      opt*) deny "$ID_MSG -o ${ID_WHY#opt } would pick another key or agent" ;;
      F*) deny "$ID_MSG an ssh call without -F naming this checkout's \
memory/ssh_config reads the admin's agent (got: ${ID_WHY#F })" ;;
      rsync) deny "$ID_MSG an rsync to a remote host needs -e 'ssh -F \
\"$ID_CFG\"', or it reads the admin's agent" ;;
      *) deny "$ID_MSG the command could not be read for its SSH calls" ;;
    esac
    GUARD_ROUTE=''
  fi ;;
esac
