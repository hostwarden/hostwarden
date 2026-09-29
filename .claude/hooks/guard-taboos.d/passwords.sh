# guard-taboos.d/passwords.sh — the SSH passwords and password
# manager tokens on this workstation (rules/ssh-passwords.md).
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES lists,
# into the one shell every module shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # GUARD_ROUTE: read by deny

# --- Stored passwords and tokens ------------------------------
# bin/hostwarden-askpass hands a host's password to ssh and to
# nobody else, and refuses a caller that is not its parent ssh by
# itself, so it needs no rule here. What it reads from is a store
# this user reads without a prompt: the keychain, the Secret
# Service, an encrypted file whose key sits in the user's own
# directories, a password manager that is unlocked. A command that
# reads one of them prints the secret into the session. Each is
# denied in every scope: the secrets are on this machine, whatever
# the checkout.
#
# This catches the everyday mistake -- a session that "checks" a
# password by printing it, or hands ssh one another way -- not a
# determined reader. The Read tool is not hooked at all, and the
# prose of rules/ssh-passwords.md is the rest of the protection.
#
# Accepted false positive: the words as text in a search, `grep
# "op read" lib/passwords.sh`, since a quoted argument and a
# command look alike after the split on quotes (the guard header).
# Spell the pattern apart instead: 'op re[a]d'.
#
# A manager's global options may stand between its name and its
# verb: a dash word, with a value after it or not.
PWOPTS='([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'
PWSTART='(^|[^[:alnum:]_.-])'
PWEND='([[:space:]]|$)'
PWMSG="reading a stored SSH password or a password manager's secret \
prints it into the session"
GUARD_ROUTE="Check a password with bin/hostwarden-password check, which \
reads none, and let ssh take it from bin/hostwarden-askpass \
(rules/ssh-passwords.md)."
case "$TEXT" in
*security*)
  # -w prints the password, -g the item with it; the attributes
  # alone, without either, are how a store is checked.
  hit "${PWSTART}security${PWOPTS}[[:space:]]+(find-(generic|internet)-password([[:space:]]+[^;&|]*)?[[:space:]]-[[:alnum:]]*[wg][[:alnum:]]*$PWEND|dump-keychain|export)" \
    && deny "$PWMSG: security with -w or -g, dump-keychain and export \
print the keychain's secrets" ;;
esac
case "$TEXT" in
*secret-tool*)
  hit "${PWSTART}secret-tool${PWOPTS}[[:space:]]+(lookup|search)$PWEND" \
    && deny "$PWMSG: secret-tool lookup and search print the Secret \
Service's secrets" ;;
esac
case "$TEXT" in
*op*)
  hit "${PWSTART}op${PWOPTS}[[:space:]]+(read|inject|run|(item|document)[[:space:]]+get)$PWEND" \
    && deny "$PWMSG: op read, inject, run and item get hand out \
1Password's secrets" ;;
esac
case "$TEXT" in
*rbw*|*bw*)
  hit "${PWSTART}rbw${PWOPTS}[[:space:]]+(get|code|totp|history)$PWEND" \
    && deny "$PWMSG: rbw get, code (alias totp) and history print Bitwarden's secrets"
  hit "${PWSTART}bws${PWOPTS}[[:space:]]+(secret[[:space:]]+(get|list)|run)$PWEND" \
    && deny "$PWMSG: bws secret get, list and run hand out Secrets \
Manager's values"
  hit "${PWSTART}bw${PWOPTS}[[:space:]]+(get|list|export|serve)$PWEND" \
    && deny "$PWMSG: bw get, list, export and serve hand out \
Bitwarden's secrets" ;;
esac
# The file store: its key and the files it encrypts. Any command
# that names either is denied, a listing too: nothing but
# bin/hostwarden-password has business there.
case "$TEXT" in
*hostwarden/password*)
  hit 'hostwarden/password-key|hostwarden/passwords([/[:space:]]|$)' \
    && deny "$PWMSG: the file store's key and its files are read by \
bin/hostwarden-askpass alone" ;;
esac
# Another way to hand ssh a password.
case "$TEXT" in
*sshpass*)
  hit "${PWSTART}sshpass[[:space:]]+(-|ssh$PWEND|scp$PWEND|rsync$PWEND)" \
    && deny "sshpass hands ssh a password through an argument, the \
environment or a file, where the session and ps can read it" ;;
esac
# ssh runs whatever SSH_ASKPASS names and gives it nothing; a
# program of another name would get the prompt instead of the helper,
# and could keep what it answers. An empty value switches it off.
case "$TEXT" in
*SSH_ASKPASS=*)
  PW_OTHER=$(printf '%s\n' "$TEXT" |
    grep -Eo "SSH_ASKPASS=[\"']?[^[:space:]\"';&|)]*" |
    grep -Ev '(=|/bin/hostwarden-askpass)$' | head -n 1)
  [ -n "$PW_OTHER" ] && deny "SSH_ASKPASS names another program than \
bin/hostwarden-askpass, which would get the password prompt" ;;
esac
GUARD_ROUTE=''
