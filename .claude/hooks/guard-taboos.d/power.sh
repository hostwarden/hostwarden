# guard-taboos.d/power.sh — power off.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh

# --- Power off ------------------------------------------------
# Each rule greps only a command that holds its word (TEXT above).
case "$TEXT" in
*halt*|*poweroff*)
  if power && hit '(^|[^[:alnum:]_-])(halt|poweroff)([^[:alnum:]_-]|$)'; then
    deny "halt/poweroff never runs without explicit user request"
  fi ;;
esac
case "$TEXT" in
*init*)
  if power && hit '(^|[^[:alnum:]_.-])(tel)?init[[:space:]]+0([^0-9]|$)'; then
    deny "init 0 powers off the server"
  fi ;;
esac
# echo o > /proc/sysrq-trigger cuts the power instantly, and b
# resets without syncing. Nothing reads this file, so any
# mention of it is a write.
case "$TEXT" in
*sysrq-trigger*)
  power && deny "sysrq-trigger powers off or resets the server \
without shutting anything down cleanly" ;;
esac
# Both Linux rules need the word itself, so a command without it
# skips their greps, as the Windows rules do with WIN below.
case "$TEXT" in
*shutdown*)
  # Some guest managers take shutdown as a verb for one guest
  # (GMSHUT), which the guest rule at the end asks about. The host
  # rules here judge the segments with that verb renamed, and the
  # full set is restored after them. xe's vm-shutdown needs no
  # renaming: none of these rules reads a shutdown after a dash.
  SEGS_ALL=$SEGS
  for gm in $GMSHUTWORDS; do
    case $SEGS in
    *"$gm"*)
      SEGS=$(printf '%s\n' "$SEGS" | sed -E \
        "s/((^|[^[:alnum:]_.-])(${GMSHUT#|})${GOPTS}[[:space:]]+)shutdown/\1guest-off/g")
      break ;;
    esac
  done
  # Windows' shutdown is judged below, so the Linux rule exempts
  # it rather than lending it its -r: shutdown.exe, or shutdown
  # whose every flag takes Windows' slash, as a Windows server
  # reached over SSH runs it. One dash flag keeps it Linux's,
  # quoted or escaped too: the shell and PowerShell drop " ' and `
  # before the program sees its flag.
  if power && hit_without '(^|[^[:alnum:]_-])shutdown([^[:alnum:]_-]|$)' \
    '(^|[[:space:]])-(r|c)([[:space:]]|$)|^[^[:alnum:]]?shutdown[.]exe|^[^[:alnum:]]?shutdown[[:space:]]+/[^[:space:];&|]*([[:space:]]+["'\''`]*[^[:space:];&|"'\''`-][^[:space:];&|]*)*[[:space:]]*([;&|]|$)'
  then
    deny "shutdown without -r powers off the server (reboots \
use shutdown -r; -c cancels)"
  fi
  # systemd and sysvinit let the last action flag win, so
  # shutdown -r -h now powers off; FreeBSD and macOS refuse the
  # pair. Order does not matter here: a flag that halts one
  # implementation is not waved through because another reboots.
  # Only a dash flag counts, so Windows' slash form is left to the
  # rules below. The shell drops quotes, backslashes and the $ of
  # $'...' before the program sees '-h', $'--poweroff', \-P or
  # --h"a"lt, so any of them may sit anywhere in the flag. Brace
  # expansion builds a flag too: -{r,h} is -r -h, so { } and ,
  # count among them. A sequence, -{h..h} or -{a..z}, can name any
  # letter in its range, so a dash before one counts on its own.
  if power && hit '(^|[^[:alnum:]_-])shutdown[[:space:]]([^;&|]*[[:space:]])?["'\''`\\${},]*(-["'\''`\\${},[:alnum:]]*\{[[:alnum:]]\.\.[[:alnum:]][^[:space:];&|]*|-["'\''`\\${},[:alnum:]]*[hHPp]["'\''`\\${},[:alnum:]]*|-["'\''`\\${},]*-["'\''`\\${},]*(h["'\''`\\${},]*a|p)["'\''`\\${},[:alpha:]]*)(["'\''`\\${},[:space:]]|$)'
  then
    deny "shutdown with -h, -H, -P, -p, --halt or --poweroff \
halts or powers off the server even beside -r"
  fi
  # -c cancels on Linux and takes no time. FreeBSD's shutdown needs
  # a time, and there -c turns the power off and on again through
  # the BMC (shutdown(8)). So -c with a time is FreeBSD's power
  # cycle.
  if power && hit '(^|[^[:alnum:]_-])shutdown[[:space:]]([^;&|]*[[:space:]])?-[[:alpha:]]*c[[:alpha:]]*[[:space:]]([^;&|]*[[:space:]])?["'\'']?(now|\+[0-9]+|[0-9]+(:[0-9]+)?)["'\'']?([[:space:]]|$)'
  then
    deny "shutdown -c with a time power cycles a FreeBSD server \
(on Linux, shutdown -c alone cancels)"
  fi
  SEGS=$SEGS_ALL
  ;;
esac
# Windows reads shutdown in any case and takes its flags with / or
# -, the dash only where shutdown.exe cannot be Linux's. /s and
# /sg shut down, /p powers off at once and /h hibernates, even
# beside a /r. Otherwise /r and /g restart and /a aborts. Both
# rules must match every form the Linux rule hands over, and the
# gate for WIN must let it through: widen all four together.
WINSHUT='(^|[^[:alnum:]_-])shutdown(\.exe[[:space:]]+([^;&|]*[[:space:]])?["'\''`]*[/-]|[[:space:]]+/([^;&|]*[[:space:]]["'\''`]*/)?)'
if [ -n "$WIN" ] \
  && hit_i "${WINSHUT}(s|sg|p|h)([[:space:]\"'\`]|\$)"; then
  deny "shutdown /s, /p and /h power off or hibernate the machine"
fi
if [ -n "$WIN" ] \
  && hit_without '(^|[^[:alnum:]_-])shutdown(\.exe([^[:alnum:]_.-]|$)|[[:space:]]+/)' \
  '(^|[[:space:]])[/-][rga]([[:space:]]|$)' i; then
  deny "shutdown.exe without /r, /g or /a powers off the machine"
fi
# Windows, as WSL reaches it. Stop-Computer is PowerShell's
# power-off. wsl --shutdown stops the virtual machine that every
# distribution runs in, and --terminate (-t, and wslconfig's /t)
# one distribution: either is a halt for whatever runs inside.
# -t counts only right after wsl, where it cannot belong to the
# command wsl runs.
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_-])stop-computer([^[:alnum:]_-]|$)'; then
  deny "Stop-Computer powers off the machine"
fi
if [ -n "$WIN" ] \
  && hit_i "${WSL}([^;&|]*[[:space:]])?(--(shutdown|terminate)([[:space:]=]|\$)|/(t|terminate)([[:space:]]|\$))|${WSL}+-t([[:space:]]|\$)"
then
  deny "wsl --shutdown and --terminate stop WSL distributions, \
which is a power-off for everything running in them"
fi
