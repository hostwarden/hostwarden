# tests/hooks/guard-mode/backup-lab.sh — bin/hostwarden-backup
# --restore and scripts/lab.sh. Sourced by
# tests/hooks/guard-mode.sh, in the order its PARTS lists, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- bin/hostwarden-backup --restore ---------------------------
# A restore makes an operations install; a refused one leaves the
# checkout exactly as it was.
sh "$OPS/bin/hostwarden-backup" -o "$TMP/ws.tgz" >/dev/null
R=$(checkout refused)
mkdir -p "$R/memory"
echo 'Language: German' > "$R/memory/user.md"
fails "a restore overwrote user data without --force" sh "$R/bin/hostwarden-backup" --restore "$TMP/ws.tgz"
mode_is development "$R"
# An archive that carries the workspace's git internals is refused
# whole: restored, they would replace the hooks that scan commits.
mkdir -p "$TMP/evil/memory/.git/hooks"
printf '#!/bin/sh\nexit 0\n' > "$TMP/evil/memory/.git/hooks/pre-commit"
echo x > "$TMP/evil/memory/network.md"
tar czf "$TMP/evil.tgz" -C "$TMP/evil" memory
R=$(checkout evil)
fails "a restore accepted memory/.git from an archive" \
  sh "$R/bin/hostwarden-backup" --restore "$TMP/evil.tgz"
mode_is development "$R"
R=$(checkout restored)
sh "$R/bin/hostwarden-backup" --restore "$TMP/ws.tgz" >/dev/null
mode_is operations "$R"
[ -f "$R/memory/machines/server1.example.com/memory.md" ] && ok \
  || bad "a restore lost machine memory"

# --- scripts/lab.sh ----------------------------------------
# What it refuses before an engine or a VM manager is asked, and on
# a PATH without either, so no container or VM is ever started.
mkdir -p "$TMP/novm"
for t in sh git awk grep sed tr basename dirname mktemp cat cut cksum; do
  ln -s "$(command -v "$t")" "$TMP/novm/$t"
done
lab() { c=$1; shift; PATH="$TMP/novm" sh "$c/scripts/lab.sh" "$@" 2>&1; }
fails "the lab ran in an operations checkout" lab "$OPS" list
fails "the lab took an unknown family" lab "$DEV" up nosuch
fails "vm up ran without a test clone" lab "$DEV" vm up debian
fails "vm up took a development checkout as the test clone" \
  lab "$DEV" vm up debian --ops "$DEV"
fails "vm up took a test clone with an empty blacklist" \
  lab "$DEV" vm up debian --ops "$OPS"
echo '# production' > "$OPS/memory/blacklist.md"
fails "vm up took a blacklist of comments only" \
  lab "$DEV" vm up debian --ops "$OPS"
echo '- web1.example.com' >> "$OPS/memory/blacklist.md"
has "$(lab "$DEV" vm up debian --ops "$OPS")" "no VM manager" \
  "vm up did not reach the VM manager check"
has "$(lab "$DEV" up debian)" "no container engine" \
  "up did not ask for an engine"
HOSTWARDEN_LAB_ENGINE=false lab "$DEV" list >/dev/null && ok \
  || bad "list failed without a running engine"
has "$(lab "$WT" --help)" "lab.sh up <family>" "no help"
rm "$OPS/memory/blacklist.md"
