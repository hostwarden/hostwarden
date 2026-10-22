# guard-taboos.d/edit.sh — the target of Edit, Write, MultiEdit and
# NotebookEdit. Sourced by guard-taboos.sh, in the order its
# GUARD_MODULES lists, into the one shell every module shares; never
# run on its own.
# shellcheck shell=sh
# shellcheck disable=SC2059 # FOLDS builds its bytes with printf

# --- Edit, Write, MultiEdit, NotebookEdit: the target path ------
# These tools write one file, named in file_path (notebook_path),
# and a Bash call never carries that key: inside a JSON string the
# quotes around a key-like word are escaped, so a bare
# "file_path" is a key. Such a call is judged by its target alone,
# in every mode and scope, and never reaches the command scan
# below: its content is text that nothing runs. Every path key
# under tool_input is judged, not the first one found, so a
# harmless one cannot stand in front of a protected one.
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
# a relative one against the session's cwd, the directory
# physically, and a link as the last component followed, so a link
# elsewhere that points at a key is the key. A . or .. segment is
# also removed by text first, and that form is resolved the same
# way: a directory that does not exist yet cannot be resolved, and
# a tool that normalises the path by text writes
# ~/.ssh/nosuch/../id_ed25519 to ~/.ssh/id_ed25519. The match
# ignores case: macOS file systems do by default, so ~/.SSH/
# AUTHORIZED_KEYS opens authorized_keys, and pwd -P keeps the case
# it was given.
#
# Nor is the folding ASCII-only. APFS folds in full: the long s and
# the Kelvin sign open s and k, a sharp s opens ss, and the
# ligatures U+FB00 to U+FB06 open ff, fi, fl, ffi, ffl and st, so
# sshd_con<U+FB01>g is sshd_config. FOLDS below holds every entry
# of CaseFolding.txt (Unicode 18) that folds onto ASCII letters
# alone, thirteen, counted with a script and not from memory;
# U+0130 counts by its Turkic entry. The set is not closed (U+1DF95
# joined it late): a newer Unicode needs a recount. HFS+ skips
# zero-width characters when it compares names, and every name
# above is plain ASCII, so each form is also matched with every
# other non-ASCII byte removed. Both apply to the path before it
# is resolved, and again to every form the match reads.
# KEYSTORE: the appliances' key stores, whole directories of keys
# and sshd's config; KEYDIR below says whose they are.
KEYSTORE='conf/sshd|etc/config/ssh|etc/dropbear'
FILEKEY='((^|[/\\])authorized_keys2?|/authorized_keys/[^/]+|(^|[/\\])\.ssh[/\\]+id_[^/\\]+|/etc/ssh/ssh_host_[^/]+|/('"$KEYSTORE"')/[^/]+|/etc/ssh/sshd_config(\.d/[^/]+)?|/etc/sshd_extra|/etc/(config|conf\.d|default)/dropbear|programdata[/\\]+ssh[/\\]+[^/\\]+)$'
KEYMSG="writing an SSH key, authorized_keys or the SSH server's \
config is never allowed"
case "$INPUT" in
*'"file_path"'*|*'"notebook_path"'*)
  # The sed program of the folds: each character as its UTF-8 bytes,
  # and the ASCII letters it folds onto.
  FOLDS=''
  for f in '\305\277:s' '\342\204\252:k' '\303\237:ss' \
    '\341\272\236:ss' '\360\235\276\225:ss' '\304\260:i' \
    '\357\254\200:ff' '\357\254\201:fi' '\357\254\202:fl' \
    '\357\254\203:ffi' '\357\254\204:ffl' '\357\254\205:st' \
    '\357\254\206:st'; do
    FOLDS="${FOLDS}s/$(printf "${f%:*}")/${f#*:}/g;"
  done
  # unfold <text> — sets UF to the text with the folds spelled out,
  # every line. A failure denies: the form it misses could be the
  # key. Called in this shell, never in a substitution, whose exit
  # would end only the subshell.
  unfold() {
    UF=$(printf '%s\n' "$1" | LC_ALL=C sed -e "$FOLDS" 2>/dev/null) \
      || deny "$KEYMSG, and the target of this edit could not be \
folded, so it cannot be shown to be an ordinary file"
  }
  # ascii <text> — sets UA to the text with every non-ASCII byte
  # removed; a failure denies, as unfold's does.
  ascii() {
    UA=$(printf '%s\n' "$1" | LC_ALL=C tr -d '\200-\377' 2>/dev/null) \
      || deny "$KEYMSG, and the target of this edit could not be \
reduced to ASCII, so it cannot be shown to be an ordinary file"
  }
  # hit <text> — whether any line names a key, as given, unfolded or
  # unfolded and stripped to ASCII.
  hit() {
    unfold "$1"
    HM=$UF
    ascii "$HM"
    printf '%s\n%s\n%s\n' "$1" "$HM" "$UA" \
      | LC_ALL=C grep -Eiq "$FILEKEY"
  }
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
  # judge <path> — appends the path, what it resolves to, and the
  # same without its . and .. segments to FALL.
  judge() {
    FALL="$FALL$1
"
    resolve "$1"
    case "/$1/" in
    */./*|*/../*)
      FNORM=$(printf '%s\n' "$1" | awk -F/ '{
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
  }
  # target <path> — one path key: made absolute against the cwd the
  # input carries, or the hook's own, then judged as given, unfolded,
  # and unfolded and stripped to ASCII.
  target() {
    NT=$((NT + 1))
    FP=$1
    case "$FP" in /*) ;; *) FP="${FWD:-$PWD}/$FP" ;; esac
    unfold "$FP"
    FM=$UF
    ascii "$FM"
    FA=$UA
    judge "$FP"
    [ "$FM" = "$FP" ] || judge "$FM"
    [ "$FA" = "$FM" ] || judge "$FA"
  }
  FWD="" FALL="" NT=0
  if command -v jq >/dev/null 2>&1; then
    eval "$(printf '%s' "$INPUT" | jq -r '
      @sh "FWD=\(.cwd // "" | tostring)",
      (.tool_input | .. | objects | (.file_path, .notebook_path)
        | select(. != null) | tostring | @sh "target \(.)")' \
      2>/dev/null)"
  fi
  if [ "$NT" -eq 0 ]; then
    # Without jq, or a path jq could not read: the raw input
    # decides, which can only over-block. Nothing resolves a
    # relative target there, and a JSON escape in the path (a
    # backslash before a slash, or before the letter u and four hex
    # digits) can spell any character, so either is denied as it
    # stands; an escape in the content is only text.
    PK='"(file|notebook)_path"[[:space:]]*:[[:space:]]*"'
    if printf '%s\n' "$INPUT" | LC_ALL=C grep -Eq \
      "${PK}[^/]|${PK}[^\"]*\\\\"
    then
      deny "$KEYMSG, and without jq the target of this edit is \
relative or may hide behind a JSON escape - install jq"
    fi
    hit "$(printf '%s' "$INPUT" | tr '"' '\n')" \
      && deny "$KEYMSG, and without jq the target of this edit cannot \
be told apart from its content - install jq"
    exit 0
  fi
  if hit "$FALL"; then
    deny "$KEYMSG, through an edit as much as through a shell - read \
it with cat, grep or sshd -T, and leave a change to it to the user"
  fi
  exit 0
  ;;
esac
