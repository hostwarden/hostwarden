# guard-taboos.d/accounts.sh — the account files, written directly.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh disable=SC2034 # GUARD_ROUTE: read by deny

# --- The account files ----------------------------------------
# /etc/passwd, shadow, group, gshadow, FreeBSD's master.passwd and
# its databases, written in place, bypass every check useradd,
# usermod, passwd and pw make: one bad line and nobody logs in.
# rules/accounts.md does account work through those tools, so a
# direct write is never the way. vipw and vigr edit the files in
# place and are denied the same. Reading stays allowed (getent,
# grep, cat, awk). The guard does not judge sudoers: the rule
# files write one drop-in, backed up, checked with visudo -c -f
# (rules/accounts.md), and that is a documented, asked-first flow.
# The copy rule judges the destination only, so a backup of an
# account file is not a write to it. Needs root to act on, hence
# full; the precheck keeps the greps off every other call.
ACCT=
case "$TEXT" in
*passwd*|*shadow*|*/etc/group*|*pwd.db*|*vipw*|*vigr*) ACCT=1 ;;
esac
if [ -n "$ACCT" ] && full; then
  GUARD_ROUTE="Create, change and remove accounts with useradd, \
usermod, userdel or pw, and set passwords with passwd (rules/accounts.md); \
read the files with getent, grep or awk."
  ACCTFILE='/etc/(passwd|shadow|gshadow|group|master\.passwd|s?pwd\.db)'
  # A runtime as a command word, with or without a directory in front:
  # a directory called lua or perl in a path is no interpreter.
  ACCTRT="(^|[[:space:];|&(\`\"'])(/[^[:space:]]*/)?(python[0-9.]*|perl|ruby|node|nodejs|deno|bun|php[0-9.]*|lua[0-9.]*|tclsh|osascript|Rscript|julia|elixir|escript|erl)([^[:alnum:]_./-]|\$)"
  ACCTB="$ACCTFILE"'([[:space:]"'\'';|&)`<>]|$)'
  if hit_without '(^|[^[:alnum:]_.-])(vipw|vigr)([^[:alnum:]_.-]|$)' \
    "$HELP"; then
    deny "vipw and vigr edit the account files in place"
  fi
  if hit "$ACCTFILE"; then
    if hit '>>?[[:space:]]*["'\'']?[^[:space:];|&]*'"$ACCTB" \
      || hit "(^|[^[:alnum:]_.-])(sed|perl)[[:space:]]([^;&|]*[[:space:]])?(-[[:alpha:]]*i|--in-place)[^;&|]*$ACCTB" \
      || hit "(^|[^[:alnum:]_-])${EDITOR}[[:space:]][^;&|]*$ACCTB" \
      || hit "(^|[^[:alnum:]_-])(rm|shred|unlink|truncate|mv|install|ln|patch)[[:space:]][^;&|]*$ACCTB" \
      || writes_to "$ACCTFILE"
    then
      deny "writing an account file directly bypasses every check \
useradd and passwd make (getent, grep and awk read them)"
    fi
    # awk reads these files all day in the security skill and writes
    # only through an explicit redirect the rules above see.
    if hit "${ACCTRT}[^;&|]*${ACCTFILE}" || hit "${ACCTFILE}[^;&|]*${ACCTRT}"
    then
      deny "an interpreter with an account file on its command line \
can rewrite it, and a pattern matcher cannot tell that from a read - \
read it with getent, grep or awk instead"
    fi
  fi
  GUARD_ROUTE=''
fi
SEGS=$SEGS_LOOK
