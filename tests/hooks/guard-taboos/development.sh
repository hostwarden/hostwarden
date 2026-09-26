# tests/hooks/guard-taboos/development.sh — the local scope of a
# development checkout. Sourced by tests/hooks/guard-taboos.sh, in
# its order, into the one shell every part shares; never run on its
# own.
# shellcheck shell=sh

# --- development: the local scope ------------------------------
# The same guard in a development tree. Text that names a taboo
# is the work there and passes; anything that reaches a server,
# root or a container is judged in full, and what an ordinary
# user reaches stays guarded. The local scope depends on who runs
# the matrix: as root or in the disk group every fixture is full,
# and on a machine running systemd the power-off rules stay on, so
# the fixtures that assume otherwise are queued only where they
# hold.
check_dev() { check "dev-$1" "$2"; }
LOCAL_SCOPE=1
case "$(id 2>/dev/null)" in uid=0\(*|*\(disk\)*) LOCAL_SCOPE= ;; esac
if [ -n "$LOCAL_SCOPE" ]; then
  check_dev pass 'grep -rn fdisk rules/'
  check_dev pass 'rg -n mkfs AGENTS.md'
  check_dev pass 'git commit -m "docs: explain why mkfs is blocked"'
  check_dev pass 'git commit -m "fix: guard misses sfdisk --delete"'
  check_dev pass 'git log --oneline --grep=wipefs'
  check_dev pass 'git commit -m "feat(guard): refuse ansible-playbook and tofu apply"'
  check_dev pass 'grep -rn "ansible web1 -m parted" .claude/hooks/'
  check_dev pass 'gh pr create --title "guard: catch parted mklabel" --body x'
  check_dev pass 'grep -n "dd if=" rules/os/debian.md'
  check_dev pass 'mkfs.ext4 -F /tmp/disk.img'
  check_dev pass 'git commit -m "docs: cp image.raw /dev/sda"'
  check_dev pass 'rg "cp .* /dev/sda" .'
  check_dev pass 'grep -rn "zpool destroy" rules/'
  check_dev pass 'git commit -m "docs: why e2fsck -y is a taboo"'
  check_dev pass 'rg -n "lvremove|mdadm --create" .claude/hooks/'
  check_dev pass 'lvextend -L +1G vg0/root'
  if [ ! -d /run/systemd/system ]; then
    check_dev pass 'rg -n shutdown AGENTS.md'
    check_dev pass 'git commit -m "guard: FreeBSD shutdown -c now power cycles"'
    check_dev pass 'git log --oneline --grep=poweroff'
    check_dev pass 'gh pr create --title "guard: catch poweroff via systemctl" --body x'
  fi
fi
if [ -d /run/systemd/system ]; then
  check_dev deny 'systemctl poweroff'
  check_dev deny 'poweroff'
fi
# Reaching past this user's own files brings the full scope back.
check_dev deny 'ssh h "mkfs.ext4 /dev/sda1"'
check_dev deny 'sudo fdisk /dev/sda'
check_dev deny 'doas dd if=img of=/dev/sda'
check_dev deny 'docker exec lab fdisk /dev/sdb'
check_dev deny 'podman run --rm img wipefs -a /dev/sdb'
check_dev deny 'orb -m lab parted /dev/vdb mklabel gpt'
check_dev deny 'wsl.exe -u root mkfs.ext4 /dev/sdb'
check_dev deny 'powershell.exe -c "wsl -u root wipefs -a /dev/sdb"'
check_dev deny 'cmd.exe /c "wsl -u root fdisk /dev/sdb"'
# The Windows rules apply in every scope: a Windows user reaches
# them without admin.
check_dev deny 'wsl.exe --unregister Ubuntu'
check_dev deny 'Stop-Computer -Force'
check_dev deny "osascript -e 'do shell script \"newfs_apfs /dev/disk4\" with administrator privileges'"
check_dev deny 'git commit -m "ssh h mkfs.ext4 /dev/sda1"'
check_dev deny 'GIT_SSH_COMMAND=x git fetch; dd if=a of=/dev/sda'
check_dev deny 'rsync -a x h:/y; shutdown -h now'
check_dev deny 'ssh root@bsd "shutdown -c now"'
check_dev deny 'sudo cp image.raw /dev/sda'
# What an ordinary user reaches stays guarded in every scope.
check_dev deny 'rm -f ~/.ssh/id_ed25519'
check_dev deny 'chmod 000 ~/.ssh'
check_dev deny 'echo x > ~/.ssh/authorized_keys'
check_dev deny "sed -i '' 's/^#Port/Port/' /opt/homebrew/etc/ssh/sshd_config"
check_dev deny 'diskutil eraseDisk APFS X disk4'
check_dev deny 'python3 -c "import os; os.remove(\"/home/alice/.ssh/id_ed25519\")"'
check_dev deny 'HOSTWARDEN_GUARD_DISABLE=1 true'
# Without lib/mode.sh the guard cannot tell its mode, and a guard
# that cannot tell stays full.
NOMODE=$(mktemp -d)
mkdir -p "$NOMODE/.claude/hooks" "$NOMODE/lib"
cp "$GUARD_DEV" "$NOMODE/.claude/hooks/"
cp -R "${GUARD_DEV%/*}/guard-taboos.d" "$NOMODE/.claude/hooks/"
cp "$REPO/lib/json.sh" "$NOMODE/lib/"
OUT=$(json_for 'mkfs.ext4 /dev/sda1' \
  | env -u HOSTWARDEN_GUARD_DISABLE sh "$NOMODE/.claude/hooks/guard-taboos.sh")
expect "the guard went local without mode.sh to tell its mode" \
  denied "$OUT"
# Without json.sh it can write no decision, and a hook that fails
# to start lets the call through; exit 2 blocks it instead, for
# guard-settings.sh too, once a call gets past its prefilter.
rm "$NOMODE/lib/json.sh"
cp "$SGUARD" "$NOMODE/.claude/hooks/"
for g in guard-taboos.sh guard-settings.sh; do
  json_for 'cat notes/settings.json' | env -u HOSTWARDEN_GUARD_DISABLE \
    sh "$NOMODE/.claude/hooks/$g" >/dev/null 2>&1
  expect "$g without json.sh did not exit 2" [ $? -eq 2 ]
done
rm -rf "$NOMODE"
