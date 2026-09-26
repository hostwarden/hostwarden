# guard-taboos.d/edit.sh — the target of Edit, Write, MultiEdit and
# NotebookEdit. Sourced by guard-taboos.sh, in the order its
# GUARD_MODULES lists, into the one shell every module shares; never
# run on its own.
# shellcheck shell=sh

# --- Edit, Write, MultiEdit, NotebookEdit: the target path ------
# These tools write one file, named in file_path (notebook_path),
# and a Bash call never carries that key: inside a JSON string the
# quotes around a key-like word are escaped, so a bare
# "file_path" is a key. Such a call is judged by its target alone,
# in every mode and scope, and never reaches the command scan
# below: its content is text that nothing runs.
#
# The targets are the key files and sshd's config the Bash rules
# protect, matched exactly on the right, so a document about them
# (a note named authorized_keys.md, sshd_config.example) stays
# editable:
# authorized_keys and OpenMediaVault's directory of that name, a
# private or public key under .ssh, a host key, an appliance key
# store (/conf/sshd, /etc/dropbear, /etc/config/ssh), Windows'
# ProgramData\ssh,
# sshd_config and its drop-ins, a file an appliance merges into
# it, and dropbear's config. ~/.ssh/config and known_hosts are not
# keys and stay open. The left side stays open as in the Bash
# rules, so /opt/homebrew/etc/ssh, an offline image and
# /mnt/c/ProgramData count.
#
# The path is judged as given and as the file system resolves it:
# the directory physically, and a link as the last component
# followed, so a link elsewhere that points at a key is the key.
# A . or .. segment is also removed by text first, and that form is
# resolved the same way: a directory that does not exist yet cannot
# be resolved, and a tool that normalises the path by text writes
# ~/.ssh/nosuch/../id_ed25519 to ~/.ssh/id_ed25519. The match
# ignores case: macOS file systems do by default, so ~/.SSH/
# AUTHORIZED_KEYS opens authorized_keys, and pwd -P keeps the case
# it was given.
# KEYSTORE: the appliances' key stores, whole directories of keys
# and sshd's config; KEYDIR below says whose they are.
KEYSTORE='conf/sshd|etc/config/ssh|etc/dropbear'
FILEKEY='((^|[/\\])authorized_keys2?|/authorized_keys/[^/]+|(^|[/\\])\.ssh[/\\]+id_[^/\\]+|/etc/ssh/ssh_host_[^/]+|/('"$KEYSTORE"')/[^/]+|/etc/ssh/sshd_config(\.d/[^/]+)?|/etc/sshd_extra|/etc/(config|conf\.d|default)/dropbear|programdata[/\\]+ssh[/\\]+[^/\\]+)$'
KEYMSG="writing an SSH key, authorized_keys or the SSH server's \
config is never allowed"
case "$INPUT" in
*'"file_path"'*|*'"notebook_path"'*)
  FP="" FWD=""
  if command -v jq >/dev/null 2>&1; then
    eval "$(printf '%s' "$INPUT" | jq -r '@sh "FP=\(.tool_input.file_path
      // .tool_input.notebook_path // "") FWD=\(.cwd // "")"' 2>/dev/null)"
  fi
  if [ -z "$FP" ]; then
    # Without jq, or a path jq could not read: the raw input
    # decides, which can only over-block.
    printf '%s' "$INPUT" | tr '"' '\n' | grep -Eiq "$FILEKEY" \
      && deny "$KEYMSG, and without jq the target of this edit cannot \
be told apart from its content - install jq"
    exit 0
  fi
  case "$FP" in /*) ;; *) FP="$FWD/$FP" ;; esac
  # resolve <path> — appends the path as the file system resolves it
  # to FALL, one per line.
  resolve() {
    R=$1 n=0
    while [ $n -lt 10 ]; do
      FD=${R%/*}
      [ -d "${FD:-/}" ] && R="$(cd "${FD:-/}" && pwd -P)/${R##*/}"
      [ -L "$R" ] || break
      L=$(readlink "$R")
      case "$L" in /*) R=$L ;; *) R="${R%/*}/$L" ;; esac
      n=$((n + 1))
    done
    # Still a link after ten steps: a loop, or a chain long enough
    # to hide where it ends. Neither can be shown to miss a key.
    [ -L "$R" ] && deny "$KEYMSG, and this edit goes through a chain \
of links that does not end, so its target cannot be shown to be \
something else"
    FALL="$FALL$R
"
  }
  FALL="$FP
"
  resolve "$FP"
  case "/$FP/" in
  */./*|*/../*)
    FNORM=$(printf '%s\n' "$FP" | awk -F/ '{
      n = 0
      for (i = 2; i <= NF; i++) {
        if ($i == "" || $i == ".") continue
        if ($i == "..") { if (n) n--; continue }
        s[++n] = $i
      }
      o = ""
      for (i = 1; i <= n; i++) o = o "/" s[i]
      print (o == "" ? "/" : o)
    }')
    FALL="$FALL$FNORM
"
    resolve "$FNORM"
    ;;
  esac
  if printf '%s' "$FALL" | grep -Eiq "$FILEKEY"; then
    deny "$KEYMSG, through an edit as much as through a shell - read \
it with cat, grep or sshd -T, and leave a change to it to the user"
  fi
  exit 0
  ;;
esac
