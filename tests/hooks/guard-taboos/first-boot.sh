# tests/hooks/guard-taboos/first-boot.sh — writes only a guest's
# first boot may make. Sourced by tests/hooks/guard-taboos.sh, in
# its order, into the one shell every part shares; never run on its
# own.
# shellcheck shell=sh

# --- a guest that has never run ---------------------------------
# AGENTS.md -> Critical Safety Rules lets the first-boot
# configuration of a guest that never started set sshd's login
# options and keys. The guard cannot prove a root filesystem
# belongs to such a guest, so it asks for the two shapes a manager
# owns and denies everything else. hostwarden-new-guest writes
# these files; references/lxc.md and references/image-prep.md are
# where they come from.
FB_LXC=/var/lib/lxc/web4/rootfs/etc/ssh/sshd_config.d/10-hostwarden.conf
FB_IMG=/var/lib/libvirt/images/web1.qcow2
check deny "scp 10-hostwarden.conf root@h:$FB_LXC"
check_mode ask default "scp 10-hostwarden.conf root@h:$FB_LXC"
check_mode ask default "rsync a.conf root@h:/var/lib/machines/web4/etc/ssh/sshd_config.d/"
check_mode ask default "tee $FB_LXC"
check_mode ask default "sed -i s/x/y/ /var/lib/lxc/web4/rootfs/etc/ssh/sshd_config"
check_mode ask default "rm /var/lib/lxc/web4/rootfs/etc/ssh/ssh_host_ed25519_key"
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in 10-hostwarden.conf:/etc/ssh/sshd_config.d"
check_mode ask default \
  "guestfish --rw -a $FB_IMG -i write /etc/ssh/sshd_config.d/10-hostwarden.conf x"
# Where no prompt reaches a human, the answer is deny, as it is
# for stopping a guest.
for m in acceptEdits plan auto; do
  check_mode ask "$m" "scp 10-hostwarden.conf root@h:$FB_LXC"
done
for m in bypassPermissions dontAsk bogus; do
  check_mode deny "$m" "scp 10-hostwarden.conf root@h:$FB_LXC"
done
# The running system is never one of these, whatever it is called.
# /mnt is the live system as often as it is an image, one
# unqualified path beside a qualified one is still the host, and
# -d names a libvirt guest that may be running.
check_mode deny default "cp 10-hostwarden.conf /etc/ssh/sshd_config.d/10-hostwarden.conf"
check_mode deny default "cp 10-hostwarden.conf /mnt/etc/ssh/sshd_config.d/x.conf"
check_mode deny default "rm /etc/ssh/ssh_host_ed25519_key"
check_mode deny default \
  "scp a.conf root@h:$FB_LXC b.conf root@h:/etc/ssh/sshd_config.d/b.conf"
check_mode deny default \
  "virt-customize -d web1 --copy-in 10-hostwarden.conf:/etc/ssh/sshd_config.d"
# The image branch holds for one invocation alone: a second command
# or a redirect beside it spells the host's /etc/ssh the same way.
check_mode deny default \
  "guestmount -a $FB_IMG -i /mnt/x && cp a.conf /etc/ssh/sshd_config.d/b.conf"
check_mode deny default \
  "virt-customize -a $FB_IMG --copy-in x:/etc/ssh/sshd_config.d > /etc/ssh/sshd_config"
check_mode deny default \
  "virt-customize -a $FB_IMG --copy-in x:/etc/ssh/sshd_config.d; rm /etc/ssh/sshd_config"
# virt-edit and virt-copy-in write with no verb on the line.
check_mode ask default "virt-edit -a $FB_IMG /etc/ssh/sshd_config -e s/a/b/"
check_mode ask default "virt-copy-in -a $FB_IMG 10.conf /etc/ssh/sshd_config.d"
check_mode deny default "virt-edit -d web1 /etc/ssh/sshd_config -e s/a/b/"
# The local side of --copy-in and --upload is only read: the host's
# sshd_config copied into an image elsewhere is no write to sshd's
# config. The image side under /etc/ssh still asks, and a host write
# beside it is still denied.
check_mode pass default "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config:/tmp"
check_mode pass default \
  "virt-customize -a $FB_IMG --upload /etc/ssh/sshd_config:/root/sshd_config.host"
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config.d/x.conf:/etc/ssh/sshd_config.d"
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in=10.conf:/etc/ssh/sshd_config.d"
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config:/etc/ssh"
# Quotes on either side are the shell's and change nothing.
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config:'/etc/ssh'"
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in \"sshd_config\":\"/etc/ssh\""
check_mode pass default \
  "virt-customize -a $FB_IMG --copy-in '/etc/ssh/sshd_config':'/tmp'"
# A copy into sshd's directory asks whatever the local file is
# called, and so does one into dropbear's; a copy into a directory
# dropbear's config shares with everything else asks only when the
# line names dropbear.
check_mode ask default "virt-customize -a $FB_IMG --copy-in sshd_config.d:/etc/ssh"
check_mode ask default "virt-customize -a $FB_IMG --copy-in x.conf:/etc/ssh/sshd_config.d"
check_mode ask default "virt-customize -a $FB_IMG --copy-in keys:/etc/dropbear"
check_mode ask default "virt-customize -a $FB_IMG --copy-in dropbear:/etc/default"
check_mode pass default "virt-customize -a $FB_IMG --copy-in grub:/etc/default"
# Every directory sshd keeps its config or keys in counts, and so does
# the path a copy only puts together where it lands.
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config:/usr/local/etc/ssh"
check_mode ask default "virt-customize -a $FB_IMG --copy-in x:/etc/config/ssh"
check_mode ask default "virt-customize -a $FB_IMG --copy-in x:/conf/sshd"
check_mode ask default "virt-customize -a $FB_IMG --upload x:/ProgramData/ssh/sshd_config"
check_mode ask default "virt-customize -a $FB_IMG --copy-in ssh:/etc"
check_mode ask default "virt-customize -a $FB_IMG --copy-in ./ssh/:/usr/local/etc"
check_mode ask default "virt-customize -a $FB_IMG --copy-in sshd_extra:/etc"
check_mode pass default "virt-customize -a $FB_IMG --copy-in /etc/ssh/ssh_config:/root"
check_mode deny default "virt-customize -d web1 --copy-in sshd_config.d:/etc/ssh"
check_mode deny default \
  "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config:/tmp; cp a /etc/ssh/sshd_config"
# The ask is decided last: a taboo anywhere after a first-boot write
# in the same line is still that taboo's deny.
check_mode deny default \
  "scp a.conf root@h:$FB_LXC && cp k /root/.ssh/authorized_keys"
check_mode deny default "scp a.conf root@h:$FB_LXC; ansible-playbook site.yml"
check_mode deny default \
  "scp a.conf root@h:$FB_LXC; terraform apply -auto-approve"
check_mode deny default "scp a.conf root@h:$FB_LXC; tofu destroy"
check_mode deny default \
  "rm /var/lib/lxc/web4/rootfs/etc/ssh/ssh_host_ed25519_key; ansible-playbook site.yml"
# virt-sysprep deletes host keys by default without naming a path.
check_mode ask default "virt-sysprep -a $FB_IMG"
check_mode ask default "virt-sysprep -a $FB_IMG --operations machine-id"
check_mode deny bypassPermissions "virt-sysprep -a $FB_IMG"
check_mode deny default "virt-sysprep -d web1"
check_mode deny default "virt-sysprep -a $FB_IMG; ansible-playbook site.yml"
check_mode deny default "virt-sysprep -a $FB_IMG && cat /etc/hostname"
# A key further down a guest root than /etc/ssh is not covered.
check_mode deny default "rm /var/lib/lxc/web4/rootfs/root/.ssh/authorized_keys"
check_mode deny default "rm /var/lib/lxc/web4/rootfs/../../../../etc/ssh/ssh_host_ed25519_key"
# Reading stays reading, and the seed the guest actually reads is
# not sshd's config at all.
check pass "cat /var/lib/lxc/web4/rootfs/etc/ssh/sshd_config"
check pass "scp user-data root@h:/var/lib/lxc/web4/rootfs/var/lib/cloud/seed/nocloud-net/user-data"
check pass "virt-customize -a $FB_IMG --copy-in 90-hostwarden.cfg:/etc/cloud/cloud.cfg.d"
# One prompt names every reason the line holds, each once: a guest
# stopped beside a first-boot write, a key change beside an sshd
# write in the same guest, and a storage change beside a guest.
for pair in \
  "pct stop 105; scp a.conf root@h:$FB_LXC|stopping or deleting|for a guest that has not started" \
  "rm /var/lib/lxc/web4/rootfs/etc/ssh/ssh_host_ed25519_key; tee $FB_LXC|re-permissioning SSH keys|writing sshd's configuration" \
  "zpool replace tank sdb sdd; pct stop 105|this storage change|stopping or deleting"
do
  c=${pair%%|*} rest=${pair#*|}
  OUT=$(json_for "$c" Bash default \
    | env -u HOSTWARDEN_GUARD_DISABLE sh "$HOOK")
  for w in "${rest%%|*}" "${rest#*|}"; do
    case "$OUT" in
    *'"permissionDecision":"ask"'*"$w"*) PASS=$((PASS + 1)) ;;
    *) FAIL=$((FAIL + 1)); echo "FAIL: the combined ask lost: $w in $c" ;;
    esac
  done
done
