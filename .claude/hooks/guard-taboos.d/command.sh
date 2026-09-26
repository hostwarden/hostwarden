# guard-taboos.d/command.sh — the command string and the helpers
# every rule reads it with. Sourced by guard-taboos.sh, in the order
# its GUARD_MODULES lists, into the one shell every module shares;
# never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the modules after it

# Extract the command string, Bash's or Monitor's. Without jq (or
# on malformed input) fall back to scanning the raw stdin text —
# that can only over-block, never under-block. A Monitor call
# without a command is a WebSocket watch, which starts no shell:
# jq marks it w and it passes, where its description would
# otherwise be scanned as a command. Without jq it cannot be told
# from a Monitor call jq failed on, so it is scanned raw.
# The permission mode, which only the guest rule at the end reads,
# comes from the same jq call, as shell assignments @sh has quoted.
# -s parses the whole input before printing anything, so input jq
# cannot read sets neither and is scanned raw.
CMD="" MODE=""
if command -v jq >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | jq -rs '@sh "CMD=\(map(
      if .tool_name == "Monitor" and (.tool_input.command // "") == ""
      then "w" else "c" + (.tool_input.command // "") end) | join("\n"))
    MODE=\(map(.permission_mode // empty | tostring) | join("\n"))"' \
    2>/dev/null)"
  [ "$CMD" = w ] && exit 0
  CMD=${CMD#c}
fi
[ -n "$CMD" ] || CMD="$INPUT"

# --- Heredoc bodies that are DATA, not code -------------------
# Documentation is the one thing that legitimately contains taboo
# words: a changelog entry describing a shutdown checkpoint, a
# rule file about fdisk, a commit message. Scanned as a command
# string, that prose is indistinguishable from an invocation, and
# the guard blocked Hostwarden's own changelog write over the word
# "shutdown" inside a heredoc.
#
# A heredoc body is only safe to skip when the command consuming
# it CANNOT execute it. That is decided by the consumer, never by
# the body, because these two look almost identical:
#
#   cat >> notes.md <<EOF          <- the body is text
#   ssh host bash -s <<EOF         <- the body RUNS, remotely
#
# So the body is dropped only when the first line is one lone
# pure data sink -- cat or tee writing to an ordinary file -- and
# every other condition fails CLOSED back to scanning everything:
# more than one heredoc, an unrecognized consumer, a missing
# terminator, a /dev/ target, or any awk failure. Whatever sits
# OUTSIDE the body (the first line itself, and everything after
# the terminator) is always still scanned, so
#   cat >> f <<EOF ... EOF; shutdown -h now
# is caught on the trailing command exactly as before.
#
# Deliberate boundary: a data sink whose target is itself
# executed later is excluded from the exemption, because writing
# a taboo INTO such a file reaches the effect on a delay. That
# set is named by EFFECT -- "something runs this file later" --
# and enumerated as scheduler and init locations, anything under
# /etc, launchd, the executable directories, script files by
# extension, and the shell start-up files. Over-matching there
# costs nothing: it only means the body is scanned as ordinary
# command text, which is what every non-exempt command gets.
# The wider boundary stays the documented one -- this hook is a
# backstop against the everyday mistake, not a sandbox. A body
# built at runtime, or fetched, defeats any string matcher.
#
# Writes AT a protected path need no rule here: the sink line
# itself is never dropped, so cat >> ~/.ssh/authorized_keys is
# still judged by the normal SSH-key rules below.
#
# NOT fixed by this, on purpose: a taboo word quoted as an
# ARGUMENT, e.g. grep shutdown /var/log/syslog. segments() splits
# on quotes so that ssh host "shutdown -h now" is caught, and
# after that split the grep argument and the ssh payload are the
# same shape. Telling them apart needs a per-command list of
# which arguments are data, which is open-ended and would reopen
# issue #4. Rephrase the probe (grep 'shut[d]own') instead.
#
# Only commands that carry a << at all can have a heredoc, and
# the awk below can do nothing but reprint the rest. The guard
# runs on every Bash call, so that fork is worth skipping.
case "$CMD" in
*'<<'*)
CMD_NOHEREDOC=$(printf '%s\n' "$CMD" | awk '
  BEGIN { q = sprintf("%c", 39) }
  NR == 1 {
    first = $0
    # A raw device target is never an ordinary file.
    if (first ~ /\/dev\//) { bad = 1; exit }
    # Targets that something later EXECUTES are not inert either.
    # Schedulers, init and unit locations, anything under /etc:
    if (first ~ /cron|systemd|init\.d|rc\.d|profile\.d|\/etc\//) {
      bad = 1; exit
    }
    # launchd jobs (macOS):
    if (first ~ /launchd|LaunchAgents|LaunchDaemons|\.plist/) {
      bad = 1; exit
    }
    # the executable directories -- /bin /sbin /usr/bin ~/bin ...:
    if (first ~ /\/s?bin\//) { bad = 1; exit }
    # a script file by extension:
    if (first ~ /\.(sh|bash|zsh|ksh|command|py|pl|rb)([ \t<]|$)/) {
      bad = 1; exit
    }
    # a shell start-up file, sourced on the next login:
    if (first ~ /\.(bashrc|bash_profile|bash_login|zshrc|zshenv|zprofile|zlogin|kshrc|cshrc|profile|login)([ \t<]|$)/) {
      bad = 1; exit
    }
    # Exactly one heredoc, so there is exactly one body to find.
    tmp = first; cnt = 0
    while (match(tmp, /<</)) { cnt++; tmp = substr(tmp, RSTART + 2) }
    if (cnt != 1) { bad = 1; exit }
    # The whole first line must be the data sink and nothing else:
    # no ; & | backtick $( ) that could smuggle a second command.
    # The target may arrive either way round -- cat writes through
    # a redirect (cat > f), tee takes it as a plain argument
    # (tee f) -- so both separators are allowed. The path token
    # itself still excludes every character that could start
    # another command, and < > stay out of it so the heredoc
    # operator can never be swallowed as a filename.
    p = "[\"" q "]?[^ \t;|&`$()<>\"" q "]+[\"" q "]?"
    shape = "^[ \t]*(cat|tee)([ \t]+-a)?(([ \t]*>>?[ \t]*|[ \t]+)" p ")?[ \t]*<<-?[ \t]*[\"" q "]?[A-Za-z_][A-Za-z0-9_]*[\"" q "]?[ \t]*$"
    if (first !~ shape) { bad = 1; exit }
    d = first
    sub(/^.*<<-?[ \t]*/, "", d)
    gsub(/["]/, "", d); gsub(q, "", d); sub(/[ \t]*$/, "", d)
    if (d !~ /^[A-Za-z_][A-Za-z0-9_]*$/) { bad = 1; exit }
    delim = d
    print first
    next
  }
  # Drop the body. Ending it on a whitespace-stripped match too is
  # deliberate: erring early only scans MORE text, never less.
  !ended {
    t = $0; sub(/^[ \t]+/, "", t)
    if ($0 == delim || t == delim) ended = 1
    next
  }
  { print }
  END { if (bad || !ended) exit 1 }
' 2>/dev/null)
GUARD_STRIP_STATUS=$?
# Only a clean parse of a recognized data sink may shrink the
# scanned text. Anything else keeps the full command string.
if [ "$GUARD_STRIP_STATUS" -eq 0 ] && [ -n "$CMD_NOHEREDOC" ]; then
  CMD="$CMD_NOHEREDOC"
fi
  ;;
esac

# The command string, plus one line per invocation it contains.
# Separators are ; & | quotes and newlines. Quotes count on
# purpose: to the shell, ssh -l root host "fdisk /dev/sda" is
# ONE invocation, but it carries a second command inside, and
# only splitting there puts fdisk in a segment that no longer
# holds ssh's -l. The FULL string stays in the list, so this can
# only ever block more, never less.
#
# CMD is final by now, so the split is computed once. The rules
# below ask dozens of questions of it, and re-forking tr for each
# of them costs more than the whole rest of the hook.
#
# The shell drops a backslash-newline before it reads a word, so
# shutdown -r -\<newline>h runs shutdown -r -h. A command that
# holds one is scanned a second time with those lines joined,
# added beside the original rather than instead of it.
CMDJ=
case "$CMD" in
*'\
'*)
  CMDJ=$(printf '%s\n' "$CMD" \
    | sed -e ':a' -e '/\\$/{' -e 'N' -e 's/\\\n//' -e 'ba' -e '}')
  ;;
esac
# The same goes for quotes and backslashes inside a word:
# shut''down, shut$'d'own and mk\fs run shutdown and mkfs. A
# command with one between two word characters is scanned once
# more with every quote, backslash and quoting $ removed, again
# beside the original. A name built from escapes ($'\x64') or
# variables is out of reach: this is a backstop, not a shell.
CMDQ=
case "$CMD$CMDJ" in
*[[:alnum:]_][\"\'\\\`\$][[:alnum:]_\"\'\\\`\$]*)
  CMDQ=$(printf '%s\n' "${CMDJ:-$CMD}" \
    | sed -e 's/\$["'\'']//g' -e 's/["'\''`\\]//g')
  ;;
esac
SEGS=$(printf '%s\n' "$CMD"
       printf '%s' "$CMD" | tr ';&|"'"'"'\n' '\n'
       for more in "$CMDJ" "$CMDQ"; do
         [ -n "$more" ] || continue
         printf '\n%s\n' "$more"
         printf '%s' "$more" | tr ';&|"'"'"'\n' '\n'
       done)

segments() {
  printf '%s\n' "$SEGS"
}

# The three texts once more, one per line, for a builtin case. Each
# segment is a piece of one of them, so a word without a newline is
# in some segment exactly when it is in TEXT: a case on it answers
# hit on a plain word without a process, and keeps the greps of a
# rule off every command that lacks the word the rule needs.
TEXT="$CMD
$CMDJ
$CMDQ"

hit() {
  segments | grep -Eq "$1"
}

# Case-insensitive variant. diskutil accepts its verbs in any
# case, so eraseDisk and erasedisk are the same command.
hit_i() {
  segments | grep -Eiq "$1"
}

# A raw disk device, as opposed to /dev/null, /dev/stderr,
# /dev/shm or /dev/disk/by-id (all of which are ordinary and
# must stay usable).
DEV='(/dev/(sd|vd|xvd|hd|nvme|mmcblk|nbd|loop|da|ada|nda|r?disk[0-9])|[Pp][Hh][Yy][Ss][Ii][Cc][Aa][Ll][Dd][Rr][Ii][Vv][Ee][0-9])'

# Any SSH key file, OR the directory that holds them. The
# directory belongs in here because re-permissioning or removing
# it reaches every key through the parent without ever naming a
# key: chown -R alice:alice /home/alice/.ssh hands the whole set
# to another owner, chmod 000 /root/.ssh hides it from sshd, and
# rm -rf ~/.ssh deletes it. The old pattern listed key FILENAMES
# only, so all three walked through while the spelled-out
# chmod 600 ~/.ssh/authorized_keys was denied. Same mistake as
# issues #5 and #6, one level up the path: the rule named the
# spelling of the target instead of the effect on it.
#
# Boundary, deliberately left open: a command that destroys an
# enclosing directory without naming .ssh at all (rm -rf /home/
# alice, a whole-filesystem operation) reaches the same effect
# and is NOT caught here. Closing it would mean treating every
# home directory as a key store. This is a backstop against the
# everyday mistake, not a sandbox.
#
# KEYPRIV additionally excludes a trailing .pub, so reading or
# copying a public key stays allowed while the private half does
# not. A certificate beside its key, ssh_host_ed25519_key-cert.pub
# or id_ed25519-cert.pub, is public in the same way, so "-cert."
# ends the name as "." does; any other hyphen suffix
# (ssh_host_rsa_key-old, id_ed25519-work) is still a private key.
# ERE has no lookahead, so "-cert." is excluded letter by letter.
# It stays filename-only on purpose: it guards a truncating
# redirect and ssh-keygen -f, neither of which is meaningful
# against a directory. KEYFILE is the same set without the
# trailing boundary, for writes_to below.
#
# Host keys and sshd_config do not always live in /etc/ssh:
# the OpenSSH port or package puts them in /usr/local/etc/ssh
# (FreeBSD; on OPNsense only sshd_config, see KEYDIR) or
# /opt/homebrew/etc/ssh. No pattern here
# is anchored on the left, so /etc/ssh matches every such prefix,
# and the rules must keep it that way instead of listing
# prefixes.
#
# KEYDIR adds the key stores of appliances (KEYSTORE, defined
# with FILEKEY above) to .ssh: OPNsense's
# /conf/sshd, and OpenWrt's /etc/dropbear, which holds dropbear's
# host keys and root's authorized_keys and nothing else. The rest
# of /conf is config and stays ordinary work. QNAP's
# /etc/config/ssh holds the live sshd_config (its init script
# starts sshd -f on it), sshd_user_config and authorized_keys
# (rules/appliance/qnap.md), so it counts as a store too.
# /etc/ssh itself is NOT a key store: it also holds ssh_config
# and moduli, so rm -rf /etc/ssh or chmod -R on it is left open,
# on the same terms as the home directory above.
#
# Windows' OpenSSH keeps both in C:\ProgramData\ssh, reached from
# WSL as /mnt/c/ProgramData/ssh. NTFS ignores case, and a Windows
# path may use backslashes, hence WINSSH.
# Every name below it is matched in any case too, and the
# directory itself counts as a key store: it holds the host keys
# and administrators_authorized_keys.
WINSSHDIR='[Pp][Rr][Oo][Gg][Rr][Aa][Mm][Dd][Aa][Tt][Aa][/\\]+[Ss][Ss][Hh]'
WINSSH="${WINSSHDIR}[/\\\\]+"
HOSTKEY="((/etc/ssh|/($KEYSTORE))/ssh_host_|/etc/dropbear/dropbear_|${WINSSH}[Ss][Ss][Hh]_[Hh][Oo][Ss][Tt]_)"
KEYDIR="(\\.ssh|/($KEYSTORE)|$WINSSHDIR)"
KEY="($HOSTKEY|authorized_keys|$KEYDIR"'(/|[^[:alnum:]_.-]|$))'
KEYFILE="($HOSTKEY"'[[:alnum:]_-]*[Kk][Ee][Yy]|\.ssh[/\\]+id_[[:alnum:]_-]+|authorized_keys|'"$WINSSH"'[[:alnum:]_]*[Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Ee][Dd]_[Kk][Ee][Yy][Ss])'
KEYPRIV="$KEYFILE"'([^.[:alnum:]-]|$|-($|[^c]|c($|[^e])|ce($|[^r])|cer($|[^t])|cert($|[^.])))'

# sshd's config: sshd_config, its drop-in directory, a file an
# appliance merges into it when it regenerates the config
# (pfSense appends /etc/sshd_extra), QNAP's own copy and its
# user file under /etc/config/ssh, dropbear's config where
# a system runs dropbear instead: OpenWrt's UCI file
# /etc/config/dropbear, /etc/conf.d/dropbear under OpenRC,
# /etc/default/dropbear on Debian, and Windows' sshd_config
# under ProgramData\ssh. The .d suffix is optional, so a plain
# hit on SSHD also finds the bare file. Then the editors that
# rewrite a file in place.
SSHD="(/etc/(ssh/sshd_config(\\.d(/[[:alnum:]_.-]*)?)?|config/ssh/sshd_(user_)?config|sshd_extra|(config|conf\\.d|default)/dropbear)|${WINSSH}[Ss][Ss][Hh][Dd]_[Cc][Oo][Nn][Ff][Ii][Gg])"
EDITOR='(vi|vim|nvim|nano|emacs|ed)'

# A general-purpose language runtime. See the interpreter section
# at the bottom for why this list, and not a list of the ways
# those runtimes spell a write.
INTERP='(^|[^[:alnum:]_.-])(python[0-9.]*|perl|ruby|node|nodejs|deno|bun|php[0-9.]*|lua[0-9.]*|tclsh|osascript|Rscript|julia|elixir|escript|erl|[gmn]?awk)([^[:alnum:]_.-]|$)'
# Windows' shells are runtimes too: Set-Content and Remove-Item
# spell a write no rule below knows. Matched without regard to
# case, as Windows finds them; cmd only as cmd.exe, since a bare
# cmd is a common word.
WININTERP='(^|[^[:alnum:]_.-])((powershell|pwsh)(\.exe)?|cmd\.exe)([^[:alnum:]_.-]|$)'
# wsl.exe and its older twin wslconfig.exe, as a command word.
# A quote may close right after it: "wsl.exe" --shutdown.
WSL='(^|[^[:alnum:]_.-])wsl(config)?(\.exe)?["'"'"']?[[:space:]]'

# The Windows rules below can only match a command that names
# wsl, a .exe, PowerShell, or one of the words they look for.
# A Windows server reached over SSH may see none of the first
# three: it runs a bare shutdown /s as shutdown.exe.
# Checking that once, without a process, keeps their greps off
# every other call; the guard runs on each one. A Windows rule
# whose word is missing here never runs, so a new rule adds its
# word. Linux uses shutdown and ciphers too, so those two count
# only in the form Windows gives them: a slash after shutdown,
# a /w or -w after cipher.
WIN=
case "$CMD" in
*[Ww][Ss][Ll]*|*.[Ee][Xx][Ee]*|*[Pp][Ww][Ss][Hh]*) WIN=1 ;;
*[Pp][Oo][Ww][Ee][Rr][Ss][Hh][Ee][Ll][Ll]*|*[Dd][Ii][Ss][Kk]*) WIN=1 ;;
*-[Cc][Oo][Mm][Pp][Uu][Tt][Ee][Rr]*|*-[Pp][Aa][Rr][Tt]*) WIN=1 ;;
*-[Vv][Oo][Ll][Uu][Mm][Ee]*|*[Mm][Bb][Rr]2*) WIN=1 ;;
*[Ff][Oo][Rr][Mm][Aa][Tt]*|*-[Ss][Tt][Oo][Rr][Aa][Gg][Ee]*) WIN=1 ;;
*[Ss][Hh][Uu][Tt][Dd][Oo][Ww][Nn]*/*|*[Bb][Cc][Dd][Ee][Dd]*) WIN=1 ;;
*[Cc][Hh][Kk][Dd][Ss][Kk]*) WIN=1 ;;
*[Cc][Ii][Pp][Hh][Ee][Rr]*[/-][Ww]*) WIN=1 ;;
esac

# True when command $1 occurs somewhere WITHOUT its read-only
# exemption $2 applying to that occurrence. Two conditions make
# an exemption count: it must sit in the same segment as the
# command, and it must FOLLOW it. Otherwise a flag belonging to
# a wrapper disarms the taboo, which is what issue #4 reported:
# ssh -l root host "fdisk /dev/sda" and lsblk -l && fdisk /dev/sdb
# were both waved through because a bare -l existed anywhere.
# A third argument i matches without regard to case, as Windows
# reads its commands; both patterns are then written in lowercase.
# awk -v reads backslash escapes, so a new pattern spells a literal
# dot [.] rather than \. .
#
# An exemption anchored with ^ lists what every argument may be
# rather than naming one read-only flag. It sees the line from
# the character before the command on, hence ^[^[:alnum:]]?, and
# the whole unsplit command is one of the lines, hence its end at
# the next ; & or |.
hit_without() {
  segments | grep -Eq${3:-} "$1" || return 1
  # The command IS present. From here on the only question is
  # whether the exemption belongs to it, so every failure path
  # below must deny. If this awk cannot evaluate POSIX classes,
  # we cannot prove the exemption applies: block.
  printf 'x' | awk '{ exit(($0 ~ /[[:alnum:]]/) ? 0 : 1) }' \
    2>/dev/null || return 0
  segments | awk -v cmd="$1" -v exempt="$2" -v fold="${3:-}" '
    {
      line = fold ? tolower($0) : $0
      while (match(line, cmd)) {
        if (RLENGTH <= 0) break
        if (substr(line, RSTART) !~ exempt) { bare = 1; exit }
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END { exit(bare ? 0 : 1) }' 2>/dev/null
  GUARD_AWK_STATUS=$?
  # Only a clean "every occurrence is exempt" (exit 1) allows.
  # Any other status is an awk failure, and that must not pass.
  [ "$GUARD_AWK_STATUS" -eq 1 ] && return 1
  return 0
}

# The model must not disarm the guard from inside a command.
# Matches the assignment form only — merely mentioning the
# variable name (docs, grep) is fine. Note: heredocs flow
# through the command string too, so writing the literal
# assignment into a file or commit message also triggers
# this; phrase such text without the equals sign.
case "$TEXT" in
*HOSTWARDEN_GUARD_DISABLE=*)
  deny "inline HOSTWARDEN_GUARD_DISABLE assignment is not \
allowed - the operator must export it before launching the \
session" ;;
esac

# True when the command writes INTO a path matching $1 (a regex
# without a trailing boundary) through a tool that names its
# target: tee or sponge, dd of=, an output flag (curl -o, wget -O,
# sort -o, openssl -out), or the destination of cp, rsync or scp.
# The same shapes reach a disk device, sshd_config and a key.
#
# A copy is judged by its DESTINATION, the last operand of its
# invocation, because the common legitimate forms name the
# protected path as the source: scp -i ~/.ssh/id_ed25519, a backup
# of authorized_keys, cp /dev/sda disk.img. Trailing options,
# redirects, a closing parenthesis or backtick and a comment are
# skipped while looking for that operand; cp -t names it up front.
# An = right before an output path is excluded on purpose:
# ssh -o IdentityFile=~/.ssh/id_ed25519 only reads the key.
#
# The set of writers cannot be closed (an archive unpacked into
# place, a git checkout, any tool with an output flag of its own),
# so this stays a backstop, not a sandbox.
#
# END includes < and >: a redirect glued to the path
# (tee /etc/ssh/sshd_config<<EOF) still ends it.
END="([\"'[:space:];|&)\`<>]|\$)"
ENDARG="[\"']?([[:space:]]+(-[^[:space:]]*|[0-9]*[<>]+&?([[:space:]]*[^[:space:]]+)?))*[[:space:])\`]*(#.*)?\$"
writes_to() {
  hit "(^|[^[:alnum:]_.-])(tee|sponge)[[:space:]]([^;|&<>]*[[:space:]])?[^[:space:];|&]*$1$END" \
    || hit "(^|[[:space:]])of=[^[:space:]]*$1$END" \
    || hit "(^|[[:space:]])(-[oO]|-out|--output(-document)?)([[:space:]]+|=)?[^[:space:]=]*$1$END" \
    || hit "(^|[^[:alnum:]_.-])(cp|rsync|scp)[[:space:]]([^;&|]*[[:space:]])?[^[:space:]]*$1$ENDARG" \
    || hit "(^|[^[:alnum:]_.-])cp[[:space:]]([^;&|]*[[:space:]])?(-[[:alpha:]]*t[[:space:]]*|--target-directory[=[:space:]])[^[:space:]]*$1$END"
}
