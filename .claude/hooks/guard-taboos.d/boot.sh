# guard-taboos.d/boot.sh — boot loaders and firmware variables.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh disable=SC2034 # SEGS_LOOK: restored by accounts.sh

# --- Boot loaders and firmware variables ----------------------
# A boot entry, the boot order or the loader itself is the way
# back into a host that has no console, and a deleted firmware
# variable has bricked boards. Writers, by effect: efibootmgr in
# any form that creates, deletes, reorders, activates or times an
# entry (bare, -v and -V read); grub-install and update-grub,
# which rewrite the loader or its config; grub-mkconfig only
# with -o or a redirect onto the boot files (without, it prints);
# the bootctl verbs that install, update, remove or set; bless in
# any form but --info and --getBoot; efivar -w; and a write,
# delete or re-permission under the efivars mount. Reading all of
# it stays allowed. The work belongs to the hostwarden-os-install
# skill and its guard-off gate, so a deny here points there, as
# the default route does; the rules need root, hence full.
# One precheck keeps the greps off every other call.
#
# A manual or a lookup only names a tool: man grub-install, tldr
# bless, which update-grub. LOOKUP (storage.sh) says what counts as
# one; for the rules of this module and of accounts.sh each lookup
# is blanked out of the segments and the segments are restored
# after them. A sed that fails or prints nothing leaves them whole,
# which only blocks more.
SEGS_LOOK=$SEGS
case "$TEXT" in
*man*|*info*|*whatis*|*apropos*|*tldr*|*which*|*whereis*|*type*)
  if LOOKLESS=$(printf '%s\n' "$SEGS" | sed -E "s/${LOOKUP}/\1:/g") \
    && [ -n "$LOOKLESS" ]; then
    SEGS=$LOOKLESS
  fi
  ;;
esac
BOOT=
case "$TEXT" in
*efibootmgr*|*grub*|*bootctl*|*bless*|*efivar*) BOOT=1 ;;
esac
if [ -n "$BOOT" ] && full; then
  if hit '(^|[^[:alnum:]_.-])efibootmgr([[:space:]][^;&|]*)?[[:space:]](-[[:alpha:]]*[BcCaAoOnNtTDwyfFe@]|--(delete|delete-bootnum|deactivate|activate|set-timeout|del-timeout|fw-ui|no-fw-ui|env|create|create-only|active|inactive|bootorder|delete-bootorder|bootnext|delete-bootnext|timeout|delete-timeout|remove-dups|write-signature|sysprep|append-binary-args))([[:space:]]|=|$)'
  then
    deny "efibootmgr in a write form changes the boot entries or \
the boot order (efibootmgr -v reads them)"
  fi
  if hit_without '(^|[^[:alnum:]_.-])grub2?-install([^[:alnum:]_.-]|$)' \
    '(^|[[:space:]])(-V|--version|--help)([[:space:]]|$)'; then
    deny "grub-install rewrites the boot loader"
  fi
  if hit_without '(^|[^[:alnum:]_.-])update-grub2?([^[:alnum:]_.-]|$)' \
    "$HELP" \
    || hit '(^|[^[:alnum:]_.-])grub2?-mkconfig([[:space:]][^;&|]*)?[[:space:]](-o|--output)([[:space:]]|=)' \
    || hit '(^|[^[:alnum:]_.-])grub2?-mkconfig[^;&|]*>>?[[:space:]]*["'\'']?/(boot|efi)' \
    || { hit '(^|[^[:alnum:]_.-])grub2?-mkconfig([^[:alnum:]_.-]|$)' \
         && writes_to '/(boot|efi)/[^[:space:]]*'; }
  then
    deny "update-grub and grub-mkconfig -o rewrite the boot loader \
config (grub-mkconfig without -o only prints it)"
  fi
  if hit_without '(^|[^[:alnum:]_.-])bootctl([[:space:]][^;&|]*)?[[:space:]](install|update|remove|cleanup|unlink|set-default|set-oneshot|set-timeout|set-timeout-oneshot|random-seed|reboot-to-firmware)([[:space:]]|$)' \
    "$HELP"
  then
    deny "this bootctl verb installs, removes or reconfigures the \
boot loader (bootctl status and list read it)"
  fi
  if hit_without '(^|[^[:alnum:]_.-])bless([^[:alnum:]_.-]|$)' \
    '(^|[[:space:]])(--info|--getBoot|--version|--help)([[:space:]]|$)'; then
    deny "bless in a write form changes what the Mac boots (bless \
--info and --getBoot read it)"
  fi
  if hit '(^|[^[:alnum:]_.-])efivar([[:space:]][^;&|]*)?[[:space:]](-w|--write|-a|--append|-D|--delete)([[:space:]]|$)'; then
    deny "efivar -w and -D write or delete a firmware variable"
  fi
fi
EFIVARS='/sys/firmware/efi/efivars'
case "$TEXT" in
*efivars*)
  if full && hit "$EFIVARS"; then
    if hit ">>?[[:space:]]*[\"']?[^[:space:];|&]*$EFIVARS" \
      || hit "(^|[^[:alnum:]_-])($CLOBBER|chattr|mount)([^[:alnum:]_-]|\$)" \
      || hit '(^|[[:space:]])-delete([[:space:]]|$)' \
      || writes_to "${EFIVARS}[^[:space:]]*"
    then
      deny "writing to or deleting under the efivars mount changes \
firmware variables and can brick the board (cat and ls read them)"
    fi
    if hit "(^|[[:space:];|&(\`\"'])(/[^[:space:]]*/)?(python[0-9.]*|perl|ruby|node|nodejs|deno|bun|php[0-9.]*|lua[0-9.]*|tclsh|osascript|Rscript|julia|elixir|escript|erl|[gmn]?awk)([^[:alnum:]_./-]|\$)[^;&|]*$EFIVARS"; then
      deny "an interpreter with the efivars mount on its command line \
can write a firmware variable, and a pattern matcher cannot tell that \
from a read - read them with cat or ls instead"
    fi
  fi ;;
esac
