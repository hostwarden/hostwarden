# Busybox Userland

On Alpine (`rules/os/alpine.md`) and OpenWrt
(`rules/appliance/openwrt.md`) most commands are busybox applets:
fewer flags than GNU, and on OpenWrt some applets left out of the
build altogether. A missing applet answers "not found", a missing
flag prints the applet's usage. `busybox --list` names the applets
the build has; `<command> --help` shows the flags before you use a
GNU one (`AGENTS.md` → Verify Before Running). The GNU tools are
packages on both; do not install one just to run a check.

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
- `find` has no `-nouser` or `-nogroup`.
- `ps` takes no `-p`, and `-o` only on Alpine; on OpenWrt, plain
  `ps` or `ps w`.
- No `ss`: use busybox `netstat -tulnp`.
- No `lscpu`: read `/proc/cpuinfo`.
- No `timedatectl`, `journalctl` or `systemctl`.
- The shell is busybox `ash`: `sh`-compatible, without arrays. It
  understands some bash syntax, `[[` among it; write plain `sh`
  anyway, so a probe runs wherever it lands.

## Alpine

- `date -d` does not parse the `notAfter` format `openssl` prints:
  use `openssl x509 -checkend <seconds>` instead.
- `last` takes no filter, so no `last reboot`.
- GNU packages: `coreutils`, `findutils`, `grep`, `procps-ng`,
  `iproute2-ss`.

## OpenWrt

- Not in the build: `nproc` (use `grep -c "^processor"
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
- GNU packages: `coreutils-*`, `procps-ng-ps`, `diffutils`, `ss`.
  On a router each one also costs flash
  (`rules/appliance/openwrt.md` → Package Manager).
