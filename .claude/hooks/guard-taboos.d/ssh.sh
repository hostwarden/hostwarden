# guard-taboos.d/ssh.sh — SSH keys, sshd_config and sshd's revocation list.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh

# --- SSH keys and sshd_config ---------------------------------
# Deleting is only one way to lose a key. Renaming it away,
# truncating it to zero, or making it unreadable to sshd have
# the same effect, and the sshd_config rule below already
# reflected that while this one did not.
# KEY and SSHD are checked once and first: most commands name
# neither, and the key rules, the sshd_config rule and the
# interpreter rule need one (OpenMediaVault, uci and ProgramData
# keep prechecks of their own).
# Each needs a word as well: KEY authorized_keys, .ssh, /etc/,
# /conf/sshd or ProgramData, SSHD /etc/ or ProgramData.
# CLOBBER: tools that delete, move, re-permission or rewrite a
# file named on their command line. Both rules below use it; the
# sshd_config rule adds cp, since a copy onto it replaces it.
CLOBBER='rm|shred|unlink|truncate|mv|chmod|chown|install|ln|setfacl|patch'
HAS_KEY=0 HAS_SSHD=0
case "$TEXT" in
*authorized_keys*|*.ssh*|*/etc/*|*/conf/sshd*|*[Pp][Rr][Oo][Gg][Rr][Aa][Mm][Dd][Aa][Tt][Aa]*)
  hit "$KEY" && HAS_KEY=1 ;;
esac
case "$TEXT" in
*/etc/*|*[Pp][Rr][Oo][Gg][Rr][Aa][Mm][Dd][Aa][Tt][Aa]*)
  hit "$SSHD" && HAS_SSHD=1 ;;
esac
# A libguestfs copy into sshd's directory names no sshd path when
# the local file is called something else, `--copy-in x:/etc/ssh`,
# or when the path is only put together where it lands,
# `--copy-in ssh:/etc`. It opens the sshd rules all the same.
case "$CMD" in
*--copy-in*|*--upload*)
  [ "$HAS_SSHD" -eq 0 ] && image_sshd_write && HAS_SSHD=1 ;;
esac
if [ "$HAS_KEY" -eq 1 ] \
  && { hit "(^|[^[:alnum:]_-])($CLOBBER)([^[:alnum:]_-]|\$)" \
       || hit '(^|[[:space:]])(-delete|--remove-s(ource|ent)-files)([[:space:]]|$)'; }
then
  if first_boot_only "$KEY"; then
    first_boot_ask "deleting, moving or re-permissioning SSH keys"
  else
    deny "deleting, moving or re-permissioning SSH keys is never \
allowed"
  fi
fi
# virt-sysprep deletes an image's SSH host keys by default (its
# ssh-hostkeys operation) and names no key path, so the rule above
# never sees it. Every invocation counts as that deletion: on an
# image opened with -a, alone on the line, it is the first-boot ask
# like any other key change in a guest that never ran; anywhere
# else it is denied. An --operations list without ssh-hostkeys is
# asked about all the same - the prompt costs one click, and
# telling the lists apart is a parser this hook does not need.
case "$TEXT" in
*virt-sysprep*)
  if hit '(^|[^[:alnum:]_.-])virt-sysprep([^[:alnum:]_.-]|$)'; then
    if first_boot_only "$KEY"; then
      first_boot_ask "removing an image's SSH host keys with virt-sysprep"
    else
      deny "virt-sysprep removes SSH host keys by default - only on a \
disk image opened with -a, alone on the line, and only with a prompt"
    fi
  fi ;;
esac
# KEYPRIV only ever matches where KEY does, so both rules below
# wait for HAS_KEY.
# A truncating redirect needs no command at all: : > key.
if [ "$HAS_KEY" -eq 1 ] \
  && hit ">[[:space:]]*[\"']?[^[:space:];|&]*$KEYPRIV"; then
  deny "redirecting onto an SSH key file truncates it"
fi
# ssh-keygen -f onto an existing private key overwrites it.
# Reading a .pub (for a fingerprint) stays allowed.
case "$TEXT" in
*ssh-keygen*)
  if [ "$HAS_KEY" -eq 1 ] \
    && hit '(^|[^[:alnum:]_-])ssh-keygen([^[:alnum:]_-]|$)' \
    && hit "$KEYPRIV"; then
    deny "ssh-keygen pointed at an existing key overwrites it - a \
fingerprint of a .pub runs in a call of its own, with no private \
key path in it"
  fi ;;
esac
# OpenMediaVault's ssh Salt state renders sshd_config and empties and
# rebuilds /var/lib/openmediavault/ssh/authorized_keys, naming
# neither path on the command line. It deploys through
# omv-salt deploy run with ssh among the state names, or through
# omv-salt stage run deploy, which renders every state. What
# --append-dirty deploys is invisible here; the appliance file
# (rules/appliance/openmediavault.md) covers it. Each word may be
# quoted, "/usr/sbin/omv-salt" too, escaped inside an ssh payload;
# segments() splits at the quotes, so only the whole line carries
# the words together. The case keeps the grep off every other Bash
# call.
case "$CMD" in
*omv-salt*)
  Q='[\"'\'']*'
  if hit "(^|[^[:alnum:]_.-])omv-salt${Q}[[:space:]]+${Q}(deploy|stage)${Q}[[:space:]]+${Q}run${Q}[[:space:]]([^;&|]*[[:space:]])?${Q}(ssh|deploy)$END"
  then
    deny "deploying the OpenMediaVault ssh state rewrites \
sshd_config and rebuilds the authorized_keys directory - the user \
changes SSH settings in the web UI"
  fi
  ;;
esac
if [ "$HAS_SSHD" -eq 1 ]; then
  if hit '>>?[[:space:]]*["'\'']?[^[:space:];|&]*'"$SSHD" \
    || { hit '(^|[^[:alnum:]_-])(sed|perl)([^[:alnum:]_-]|$)' \
         && hit '(^|[[:space:]])-i'; } \
    || hit "(^|[^[:alnum:]_-])$EDITOR([^[:alnum:]_-]|\$)" \
    || hit "(^|[^[:alnum:]_-])($CLOBBER|cp)([^[:alnum:]_-]|\$)" \
    || { hit "(^|[^[:alnum:]_.-])$IMAGETOOL([^[:alnum:]_.-]|\$)" \
         && hit "(^|[[:space:]])(--copy-in|--upload|--write|--edit|--ssh-inject|write|upload|copy-in|edit)([[:space:]]|=)" \
         && image_sshd_write; } \
    || hit '(^|[^[:alnum:]_.-])(virt-edit|virt-copy-in)([^[:alnum:]_.-]|$)' \
    || writes_to "$SSHD"
  then
    if first_boot_only "$SSHD"; then
      first_boot_ask "writing sshd's configuration"
    else
      deny "modifying sshd_config or a file merged into it is \
never allowed (reading it is fine: cat, grep, sshd -T)"
    fi
  fi
fi
# Windows' OpenSSH files under ProgramData\ssh are changed by cmd
# and PowerShell verbs the two rules above do not know: del, erase,
# rd, move, ren, copy, takeown, attrib, Remove-Item, Set-Content
# and their aliases, reached over SSH without naming PowerShell.
# The verb counts in the invocation that names the path after it,
# or behind a pipe from a listing of it (gci ... | ri). icacls
# counts only with a flag that changes the ACL, since reading one
# is an audit. A copy out of the directory is denied too, as cp is
# above. Windows reads its commands in any case.
case "$CMD" in
*[Pp][Rr][Oo][Gg][Rr][Aa][Mm][Dd][Aa][Tt][Aa]*)
  WINCLOBBER='del|erase|rd|rmdir|move|ren|rename|copy|xcopy|robocopy|takeown|attrib|cacls|notepad|remove-item|ri|move-item|mi|rename-item|rni|copy-item|cpi|set-content|add-content|clear-content|clc|out-file|new-item|ni|set-acl|tee-object'
  WINVERB="(^|[^[:alnum:]_.-])($WINCLOBBER)(\\.exe)?"
  # The directory itself, not ssh-backups or ssh_notes beside it:
  # after it a separator, a quote, space or the shell's punctuation
  # (ssh>NUL, ssh)), or the end.
  WINSSHB="${WINSSHDIR}([^[:alnum:]_.-]|\$)"
  # A verb before the path, a listing of it piped to a verb, and an
  # icacls that changes the ACL: one grep for the three.
  WINDEL="${WINVERB}[[:space:]][^;&|]*${WINSSHB}"
  WINPIPE="${WINSSHDIR}([^[:alnum:]_.-][^;&]*)?\\|[[:space:]]*($WINCLOBBER)([^[:alnum:]_.-]|\$)"
  WINACL="(^|[^[:alnum:]_.-])icacls(\\.exe)?[[:space:]][^;&|]*${WINSSHB}[^;&|]*[[:space:]]/(grant|deny|remove|reset|setowner|inheritance|setintegritylevel|restore|substitute)"
  if hit_i "($WINDEL)|($WINPIPE)|($WINACL)"; then
    deny "deleting, moving, overwriting or re-permissioning Windows' \
OpenSSH files under ProgramData/ssh is never allowed (reading them \
is fine: type, Get-Content, icacls without a change)"
  fi
  ;;
esac
# OpenWrt changes /etc/config/dropbear through uci, which never
# names the file: uci set dropbear.@dropbear[0].Port=2222, then
# uci commit dropbear. A write verb followed by the config name
# is the change, whether uci carries it on its command line or
# reads it from a uci batch here-document. uci show, get, changes
# and export only read.
# A bare commit names no config and writes every staged one, a
# dropbear change someone else left in /tmp/.uci included. A bare
# import commits every package its input declares (uci_do_import
# in uci's cli.c), a backup's package dropbear too. Both are
# denied: as the last word of a uci invocation (a redirect or a
# comment after it changes nothing), or as a batch line of their
# own. uci commit <config> and uci import <config> stay ordinary
# work.
# The case is a builtin precheck: most commands never mention uci
# and skip every grep.
UCIW='(set|add|add_list|del_list|delete|rename|reorder|import|commit)'
case "$CMD" in
  *uci*)
    if hit '(^|[^[:alnum:]_.-])uci([^[:alnum:]_.-]|$)'; then
      if hit "(^|[[:space:]'\"])${UCIW}[[:space:]]+['\"]?dropbear([.=[:space:]'\"]|\$)"
      then
        deny "changing the dropbear configuration through uci modifies \
the SSH server config, which is never allowed (reading it is fine: \
uci show dropbear)"
      fi
      if hit '((^|[^[:alnum:]_.-])uci([[:space:]]+[^[:space:]]+)*[[:space:]]+|^[[:space:]]*)(commit|import)[[:space:]]*([0-9]*[<>]|#|$)'
      then
        deny "a bare uci commit or import writes every config it \
holds, dropbear included - name the config: uci commit firewall"
      fi
    fi
    ;;
esac

# --- Writes INTO an SSH key -----------------------------------
# Writing into a key file replaces it as surely as deleting it.
if [ "$HAS_KEY" -eq 1 ]; then
  if writes_to "($KEYFILE|$KEYDIR/?)"; then
    deny "writing into an SSH key file or a key directory \
replaces the keys there"
  fi
  # An in-place edit needs the key AFTER the tool in the same
  # invocation: in ssh -i ~/.ssh/id_ed25519 host "sed -i ..." the
  # key belongs to ssh, and the edit runs elsewhere.
  if hit "(^|[^[:alnum:]_.-])sed[[:space:]]([^;&|]*[[:space:]])?(-[[:alpha:]]*i|--in-place)[^;&|]*$KEYPRIV" \
    || hit "(^|[^[:alnum:]_-])${EDITOR}[[:space:]][^;&|]*$KEYPRIV"
  then
    deny "editing an SSH key file in place can delete keys from it"
  fi
fi

# --- SSH revocation list --------------------------------------
# Once sshd_config names a revocation list (RevokedKeys), a
# missing or unreadable file makes sshd refuse EVERY public key
# login, authorized_keys included (sshd_config(5)): the same
# lockout as deleting the keys, reached through a file that is
# not a key. REVOKED is a path under an ssh configuration
# directory whose name says revoked or krl, the names the rule
# files and the CA tools use; unanchored on the left, like the
# rest, so /usr/local/etc/ssh counts. Only the effects that make
# it missing or unreadable are denied. Writing it (ssh-keygen -k,
# cp over it) keeps it in place and stays allowed; an interpreter
# is handled below with the other protected paths.
REVOKED='/etc/ssh/[^[:space:]"'\'';|&<>]*([Rr]evoked|[Kk][Rr][Ll])'
HAS_KRL=0
case "$TEXT" in
*/etc/ssh/*)
  hit "$REVOKED" && HAS_KRL=1 ;;
esac
if [ "$HAS_KRL" -eq 1 ] \
  && { hit '(^|[^[:alnum:]_-])(rm|shred|unlink|mv|chmod|chown|ln|setfacl)([^[:alnum:]_-]|$)' \
       || hit '(^|[[:space:]])(-delete|--remove-s(ource|ent)-files)([[:space:]]|$)'; }
then
  deny "deleting, moving or re-permissioning sshd's revocation \
list makes sshd refuse every public key login - read it with \
ssh-keygen -Q -l or ls -l"
fi
