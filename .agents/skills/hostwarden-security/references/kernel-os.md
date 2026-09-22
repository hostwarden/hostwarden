# Kernel / OS Security — Linux and FreeBSD

These checks read sysctl values. No root needed.

**Containers.** A system container or a FreeBSD jail —
`Virtualization:` in memory names a container — runs on its
host's kernel (`rules/system-containers.md`), and a kernel-wide
sysctl read there returns the host's value. There, report ASLR
and SUID Core Dumps `n/a (container)`. IP Forwarding and ICMP
Redirect Acceptance belong to the container's own network
namespace and are judged as below. Which FreeBSD keys a jail
owns is under FreeBSD.

## ASLR (Address Space Layout Randomization)

```bash
sysctl -n kernel.randomize_va_space
```

- `0` → **CRITICAL** (ASLR disabled)
- `1` → **WARN** (partial — should be 2)
- `2` → OK (full randomization)

## IP Forwarding

```bash
sysctl -n net.ipv4.ip_forward net.ipv6.conf.all.forwarding
```

On macOS:

```bash
sysctl -n net.inet.ip.forwarding net.inet6.ip6.forwarding
```

- `1` in either family → **WARN** unless the server's
  `memory.md` mentions WireGuard, VPN, or router functionality,
  or the host is a firewall appliance. In that case → OK with
  note.
- `0` → OK

## ICMP Redirect Acceptance — Linux only

```bash
sysctl -n net.ipv4.conf.all.accept_redirects
```

- `1` → **WARN**
- `0` → OK

## SUID Core Dumps — Linux only

```bash
sysctl -n fs.suid_dumpable
```

- `1` → **WARN** (allows core dumps from SUID programs, potential
  information leak)
- `0` or `2` → OK (`2` is "suidsafe" — restricted)

## FreeBSD

One call reads everything; no root needed:

```bash
sysctl kern.elf64.aslr.enable kern.elf64.aslr.pie_enable \
  kern.elf64.aslr.stack net.inet.ip.forwarding \
  net.inet6.ip6.forwarding net.inet.icmp.drop_redirect \
  kern.sugid_coredump kern.securelevel \
  security.bsd.see_other_uids security.bsd.see_other_gids \
  security.bsd.see_jail_proc security.bsd.unprivileged_read_msgbuf \
  security.bsd.unprivileged_proc_debug kern.randompid \
  security.jail.vnet
```

| Key | Finding |
|-----|---------|
| `kern.elf64.aslr.enable` | `0` → **CRITICAL** (ASLR disabled) |
| `…aslr.pie_enable`, `…aslr.stack` | `0` → **WARN** (partial) |
| `net.inet*.forwarding` | as IP Forwarding above |
| `net.inet.icmp.drop_redirect` | `0` → **WARN** (FreeBSD's default) |
| `kern.sugid_coredump` | `1` → **WARN** |
| `kern.securelevel` | report only |
| the five `security.bsd` keys | `1` → **INFO**, one line naming them |
| `kern.randompid` | `0` → **INFO**, on the same line |

- In a jail, three rows are its own: `kern.securelevel`, never
  below the host's (`jail(8)`),
  `security.bsd.unprivileged_proc_debug`, and the `net.inet*`
  keys where `security.jail.vnet` is `1`, a jail with its own
  network stack. Every other row reads `n/a (container)`, and
  the INFO line names `unprivileged_proc_debug` alone.
- ASLR is on by default on 64-bit platforms. On a 32-bit one
  (`uname -p` shows `i386` or `armv7`) read `kern.elf32.aslr.*`,
  off by default there: **INFO**.
- Forwarding is also expected for jails or bhyve guests networked
  through this host.
- `kern.securelevel` above `0` explains changes that fail
  (`security(7)`).
- `kern.randompid` reads back as a modulus: any value but `0` is
  hardened.
