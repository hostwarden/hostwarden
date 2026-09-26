#!/bin/sh
# tests/lib/coord-rest.sh — the matrix for lib/coord-rest.sh's
# hostwarden_coord_rest, what the taboo guard still judges with its
# off switch on. CI runs it through scripts/check.sh; an agent
# session leaves it to CI (.claude/rules/pull-requests.md → Checks).

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
# shellcheck source=../../lib/coord-tokenize.sh
. "$REPO/lib/coord-tokenize.sh"
# shellcheck source=../../lib/coord-lib.sh
. "$REPO/lib/coord-lib.sh"
# shellcheck source=../../lib/coord-rest.sh
. "$REPO/lib/coord-rest.sh"

# rest <desc> <command> <names> <local> <expected> —
# hostwarden_coord_rest's output with R as its reach, blank lines
# dropped, compared verbatim: what the taboo guard still judges with
# its off switch on.
R='(^|[^[:alnum:]_.-])(ssh|scp|sftp|mosh|rsync|pct|qm|virsh|docker|kubectl|ansible[[:alnum:]-]*|salt[[:alnum:]-]*|pssh|parallel)(\.exe)?([^[:alnum:]_.-]|$)|[[:alnum:]_-]\.exe([^[:alnum:]_.-]|$)'
rest() {
  got=$(hostwarden_coord_rest "$2" "$3" "$R" "$4" | grep -v '^[[:space:]]*$')
  if [ "$got" = "$5" ]; then ok; else
    bad "rest: $1"
    echo "--- expected"; printf '%s\n' "$5"
    echo "--- got"; printf '%s\n' "$got"
  fi
}
W=web1.example.com
rest "toward the host: nothing left" \
  "sudo ssh -p 2222 root@$W uptime" $W 0 ''
rest "a local pipe stays, the ssh goes" \
  "cat img | ssh $W \"dd bs=4M\"" $W 0 'cat img '
rest "a local redirection of the ssh stays" \
  "ssh $W cat > out.img" $W 0 'true > out.img'
rest "a quoted redirection target keeps the segment whole" \
  "ssh $W cat > \"out.img\"" $W 0 "ssh $W cat > \"out.img\""
rest "a redirection in a heredoc body is the far side's" \
  "$(printf 'ssh %s sh -s <<EOF\necho b > /tmp/x\nEOF' $W)" $W 0 ''
rest "another host stays" \
  "ssh $W true; ssh db1.example.com uptime" $W 0 \
  ' ssh db1.example.com uptime'
rest "a destination in a variable stays" 'ssh $H uptime' $W 0 'ssh $H uptime'
rest "scp stays, even toward the host" \
  "scp a $W:/tmp/a" $W 0 "scp a $W:/tmp/a"
rest "a path or a service named ssh is no hop" \
  "ssh $W 'mkdir -p /mnt/etc/ssh /mnt/root/.ssh; systemctl restart ssh'" \
  $W 0 ''
for c in 'ssh db1.example.com uptime' 'timeout 9 ssh db1.example.com uptime' \
  '/usr/bin/ssh db1.example.com uptime' 'sh -c "ssh db1.example.com uptime"' \
  'ansible db1.example.com -m ping' 'virsh -c qemu+ssh://db1.example.com/system list' \
  'docker -H ssh://db1.example.com ps' 'pct exec 105 -- uptime' \
  'salt-ssh db1.example.com uptime' \
  'ANSIBLE_NOCOLOR=1 ansible db1.example.com -m ping' \
  '$SUDO ssh db1.example.com uptime' \
  'if true; then ssh db1.example.com uptime; fi' \
  'su -c "ssh db1.example.com uptime"' \
  'sshpass -e ssh db1.example.com uptime' \
  'timeout 9 /usr/bin/ssh db1.example.com uptime' \
  'ipmitool -H bmc1.example.com chassis status' \
  'systemctl -H db1.example.com status' \
  'systemctl -qH db1.example.com status' \
  'pssh -h /root/hosts -i uptime' \
  'net view \\db1' \
  'parallel -S db1.example.com uptime ::: 1' \
  'nice parallel --slf hosts uptime ::: 1' \
  'pvesh create /nodes/db1/status --command reboot' \
  'command ssh db1.example.com uptime' \
  'ssh.exe root@db1.example.com uptime'; do
  rest "a hop onward stays: $c" "ssh $W '$c'" $W 0 "ssh $W '$c'"
done
rest "a hop onward in a heredoc body stays" \
  "$(printf 'ssh %s sh -s <<EOF\nansible db1.example.com -m ping\nEOF' $W)" \
  $W 0 "$(printf 'ssh %s sh -s <<EOF\nansible db1.example.com -m ping\nEOF' $W)"
rest "a hop onward on a later line stays" \
  "$(printf 'ssh %s sh -s <<EOF\nexport LC_ALL=C\nlsblk\nssh db1.example.com uptime\nEOF' $W)" \
  $W 0 "$(printf 'ssh %s sh -s <<EOF\nexport LC_ALL=C\nlsblk\nssh db1.example.com uptime\nEOF' $W)"
rest "a hop onward on a later line of a quoted command stays" \
  "$(printf "ssh %s 'lsblk\nansible db1.example.com -m ping'" $W)" \
  $W 0 "$(printf "ssh %s 'lsblk\nansible db1.example.com -m ping'" $W)"
rest "a shell body behind a cat elsewhere on the line is read" \
  "$(printf 'ssh %s "cat /etc/os-release; sh -s" <<EOF\nssh db1.example.com uptime\nEOF' $W)" \
  $W 0 "$(printf 'ssh %s "cat /etc/os-release; sh -s" <<EOF\nssh db1.example.com uptime\nEOF' $W)"
rest "a config file written by a heredoc is data" \
  "$(printf 'ssh %s sh -s <<EOF\ncat > /mnt/etc/ssh/rescue.conf <<EOS\nSubsystem sftp /usr/libexec/sftp-server\nEOS\nEOF' $W)" \
  $W 0 ''
rest "the line after a heredoc's closing line is its own command" \
  "$(printf 'ssh %s sh -s <<EOF\nlsblk\nEOF\nmake install' $W)" $W 0 'make install'
rest "the named host's own Proxmox node is no hop" \
  "ssh $W 'pvesh get /nodes/web1/status'" $W 0 ''
rest "a package or a service named like a tool is no hop" \
  "ssh $W 'apt-get install -y rsync; systemctl enable ssh'" $W 0 ''
rest "local: a local command goes" 'uptime && df -h' '' 1 ''
rest "local: an unread scp stays" \
  'scp a db1.example.com:/tmp/a' '' 1 'scp a db1.example.com:/tmp/a'
rest "local: a wrapped ssh stays" \
  'timeout 9 ssh db1.example.com uptime' '' 1 \
  'timeout 9 ssh db1.example.com uptime'
rest "local: a Windows program stays" \
  'bcdedit.exe /enum' '' 1 'bcdedit.exe /enum'
rest "local: an ssh to localhost stays" \
  'ssh localhost uptime' '' 1 'ssh localhost uptime'

finish coord-rest
