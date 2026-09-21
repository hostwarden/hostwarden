#!/bin/sh
# git-ssh.sh — GIT_SSH_COMMAND in a development session, so git
# push over SSH reaches the real ssh past the shim (shim.sh).
#
# It takes the shim off PATH and runs what git would have run
# without it: the command the user set in GIT_SSH_COMMAND before
# the session (session-mode.sh keeps it in
# HOSTWARDEN_GIT_SSH_COMMAND), else this repository's
# core.sshCommand, else ssh. Looked up at every call, so each
# repository keeps its own sshCommand and a changed PATH counts.
#
# This is git's route to ssh, and so a route past the shim for
# anyone who calls it directly. guard-mode.sh denies the plain
# $GIT_SSH_COMMAND form; beyond that, the prose rule in AGENTS.md
# is the whole protection.

# session-mode.sh writes both paths from the same root, so the
# shim's PATH entry is this directory's shim/, spelled alike.
SHIM=${0%/*}/shim
P=
set -f
IFS=:
for d in $PATH; do
  [ "$d" = "$SHIM" ] || P="$P${P:+:}$d"
done
unset IFS
set +f
PATH=$P
export PATH
C=${HOSTWARDEN_GIT_SSH_COMMAND:-$(git config core.sshCommand)}
# The same form git uses: the command string, then the arguments.
exec sh -c "${C:-ssh} \"\$@\"" git-ssh "$@"
