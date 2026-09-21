# Busybox Userland

On Alpine (`rules/os/alpine.md`) and OpenWrt
(`rules/appliance/openwrt.md`) most commands are busybox applets:
fewer flags than GNU, and on OpenWrt some applets left out of the
build altogether. A missing applet answers "not found", a missing
flag prints the applet's usage. `busybox --list` names the applets
the build has; `<command> --help` shows the flags before you use a
GNU one (`AGENTS.md` → Verify Before Running).

Sources: Alpine's build configuration,
<https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/busybox/busyboxconfig>;
OpenWrt's defaults for its current release,
<https://github.com/openwrt/openwrt/blob/openwrt-25.12/package/utils/busybox/Config-defaults.in>;
the applets' usage text in the busybox source,
<https://github.com/mirror/busybox>.

## On Both

- `df` has no `--output` or `-x`: use `df -Ph` and filter; without
  `-P`, a long device name wraps onto its own line.
- `uptime` takes no options, so no `uptime -s`.
- `grep` has no `-P`.
- `find` has no `-nouser` or `-nogroup`: it rejects them, and with
  stderr discarded the check reads as clean.
- `ps` takes no `-p`.
- No `ss`: use busybox `netstat -tulnp`.
- No `lscpu`: read `/proc/cpuinfo`.
- No `timedatectl`, `journalctl` or `systemctl`.
- The shell is busybox `ash`: `sh`-compatible, without arrays. It
  understands some bash syntax, `[[` among it; write plain `sh`
  anyway, so a probe runs wherever it lands.

## Alpine

- `ps` takes `-o`.
- `date -d` does not parse the `notAfter` format `openssl` prints:
  use `openssl x509 -checkend <seconds>` instead.
- `last` takes no filter, so no `last reboot`.
- The GNU tools are packages (`coreutils`, `findutils`, `grep`,
  `procps-ng`, `iproute2-ss`). Do not install one just to run a
  check.

## OpenWrt

- `ps` takes no `-o` either: plain `ps`, or `ps w` for wide
  output.
- Not in the build: `nproc` (use `grep -c ^processor
  /proc/cpuinfo`), `last`, `stat` (use `ls -l`), `timeout`, `diff`,
  `hostname` (use `uci get system.@system[0].hostname`), `whoami`
  (use `id -un`), `su`, `realpath`, `base64`, `lsof`, `pkill`
  (`pgrep` is there) and `watch`.
- `sort` knows `-n`, `-r`, `-u`, `-s` and `-z`, nothing else: no
  `-k`, `-t` or `-h`. `du -h | sort -h` fails; use
  `du -k | sort -n`.
- `find` has no `-printf` and no `-delete`, and `-exec` ends with
  `\;` only, never `+`. `xargs` has no `-I`.
- `df` has no `-a`, `-i` or `-B` either.
- No `openssl` binary: a certificate expiry check needs the
  `openssl-util` package, which is not there by default.
- The GNU tools are packages (`coreutils-*`, `procps-ng-ps`,
  `diffutils`, `ss`). Do not install one just to run a check:
  every package takes flash space and is gone after the next
  sysupgrade (`rules/appliance/openwrt.md` → Updates).
