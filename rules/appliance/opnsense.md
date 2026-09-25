# OPNsense

Base: `rules/os/freebsd.md`
Hardware: any

OPNsense is built on FreeBSD, so the base file supplies the
vocabulary (`ifconfig`, `pfctl`, ZFS). Most of its instructions for
changing the system are **wrong here**: OPNsense generates the
system configuration from one XML file and overwrites manual edits.
This file applies on top of the base (`rules/os-detection.md` →
Layers).

The host is usually the network's only way out. A mistake here cuts
off everyone behind it, not just your SSH session.

Source for everything below unless noted: the OPNsense
documentation, <https://docs.opnsense.org/>, and the
`opnsense/core` source where the docs are silent.

## Add: Version Detection

- `opnsense-version` prints e.g. `OPNsense 26.7.4 (amd64)`;
  `opnsense-version -v` only the version, `-V` the series (`26.7`).
- Two major releases a year (`YY.1`, `YY.7`), minor updates in
  between.
- Record in server memory: `Appliance: OPNsense <version>`.

## Access and Shell

- **root runs remote commands in csh.** root's login shell is
  `opnsense-shell`, which hands a command passed over SSH to
  `/bin/csh -c` (`rules/first-detection.md` step 1 records it as
  `Shell: csh`). An admin user with its own login shell gets that
  shell instead.
- An interactive root login shows the console menu.
- SSH is **off by default** on an installed system; the user
  enables it under System > Settings > Administration. Root login
  is a separate option there, and only members of `wheel` may log
  in at all.
- Non-root admins get a shell only when one is set for them under
  System > Access > Users. Keys are managed there too, not in
  `authorized_keys` by hand.
- `sudo` is installed but grants nothing until the "Sudo" option
  under System > Settings > Administration allows it for `wheel`
  ("Ask password" or "No password"). With "Ask password",
  `sudo -n` fails. Probe as usual (`rules/privilege-escalation.md`).
- The SSH config is generated into `/usr/local/etc/ssh/sshd_config`,
  host keys live in `/conf/sshd/`. `sshd_config` includes
  `/usr/local/etc/ssh/sshd_config.d/*.conf`. The SSH taboo in
  `AGENTS.md` covers all of these and the whole `/conf/sshd/`
  directory: read only.

## Configuration Model

- **Everything lives in `/conf/config.xml`.** `configd` renders the
  system configuration from it through templates and overwrites,
  among others: `sshd_config`, `/boot/loader.conf`, root's crontab,
  `/etc/rc.conf.d/*`, the pf ruleset (`/tmp/rules.debug`) and
  sudoers.
- **Change settings through the web UI** (or the API, if the user
  has set up a key). Give the user the exact menu path and values.
  Do not use `sysrc` or edit `rc.conf`.
- Every save keeps a copy in
  `/conf/backup/config-<epoch>.<fraction>.xml`. The backup directory
  is `/root/hostwarden-backups/`, and `config.xml` gets a backup
  there like any other file.
- **Apply from the shell with `configctl`**, the front end to
  `configd`:
  - `configctl configd actions` lists all actions.
  - `configctl filter reload` regenerates and loads the firewall
    rules.
  - `configctl service reload all` reapplies everything (console
    menu option 11).
- configd action names with a dot are called with a space:
  `configctl filter rule stats`, not `filter rule.stats`.
- Documented places for persistent custom additions:
  `/usr/local/etc/rc.syshook.d/<event>/` (boot and event hooks),
  `/usr/local/etc/cron.d/` (own cron jobs), System > Settings >
  Tunables (loader and sysctl values). Template overrides in
  `+TARGETS.D` may break on upgrades; avoid them.
- `configctl system halt`, `system reset_factory_defaults` and
  `system flush config_history` exist. Never.

## Replace: Package Manager

- `pkg info`, `pkg audit -F` and other queries are fine. Changing
  packages goes through `configctl firmware`, see Updates and
  Plugins.
- Never add the FreeBSD or any other repository under
  `/usr/local/etc/pkg/repos/`; OPNsense calls that "not supported".

## Replace: Automatic Security Updates

- Automatic updates exist as an opt-in cron job ("Automatic
  firmware update", minor updates only). Its absence is not a
  finding; pending updates are.
- Keep the firmware release type on "Production".

## Updates

- **Never** use `freebsd-update`: base and kernel come as signed
  sets through `opnsense-update`.
- Check without installing:
  ```
  configctl firmware probe
  cat /tmp/pkg_upgrade.json
  ```
  `needs_reboot` in the JSON says whether the update would reboot;
  `upgrade_needs_reboot` only says that a major upgrade is
  available.
- Apply a minor update: `configctl firmware update`. **It reboots
  the firewall on its own** when base or kernel changed, and after
  any package change when the firmware "reboot" setting is on.
  Always ask first, and say whether the probe expects a reboot. It
  returns at once and runs in the background; follow it with
  `configctl firmware status`.
- On ZFS (24.7.3 and later), take a snapshot before updating:
  `configctl zfs snapshot list`, then
  `configctl zfs snapshot create <name>`. It is the rollback path
  (boot menu option 8). On UFS there is none; say so before asking.
- **Major upgrades** (e.g. 26.1 → 26.7) run offline and take the
  firewall down for the duration. The docs want console access.
  Hand them to the user (console menu option 12); never run
  `configctl firmware upgrade` yourself. Read the release notes
  first; they list plugins and repositories that block the upgrade.
- Update log: `opnsense-update -g`; last major upgrade:
  `opnsense-update -G`.

## Plugins

- Plugins are `os-*` packages. Install with
  `configctl firmware install os-<name>`, remove with
  `configctl firmware remove os-<name>`. Plain `pkg install` skips
  the registration in the config, so the plugin is lost on a
  config restore.
- Community plugins are "Tier 3": supported by the community, not
  the core team. Third-party repositories are not OPNsense's at
  all. Ask before installing either.
- `rules/service-class-check.md` still applies: OPNsense already
  brings a web server, DNS resolver and DHCP server.

## Replace: Firewall

- **Expected:** pf, managed by OPNsense. A default deny rule blocks
  everything no other rule matches; WAN also blocks private and
  bogon networks by default.
- Read-only: `pfctl -sr` (rules), `pfctl -s nat`, `pfctl -si`,
  `configctl filter rule stats`. The generated ruleset is in
  `/tmp/rules.debug`. A rule listing, that file's included, goes
  through `sed -E "${fc:?}"` (`fc`: `rules/secrets.md` → Commands
  That Leak).
- **Rules are changed in the web UI or the API**, never with
  `pfctl -f` on a file you wrote: the next `configctl filter
  reload` replaces it.
- Since 26.7 the rules API applies changes at once; there is no
  automatic rollback. Do not count on a timed revert.
- **Anti-lockout rule:** keeps the web UI and SSH reachable on LAN
  (or the first interface that exists), ahead of user rules. It
  can be disabled under Firewall > Settings > Advanced (26.7; the
  menu moves in later versions). Check that it is on before any
  rule change: it is on while
  `grep -c '<noantilockout' /conf/config.xml` prints `0`
  (`system/webgui/noantilockout`,
  <https://github.com/opnsense/core/blob/master/src/etc/inc/filter.lib.inc>).
  A rule listing cannot tell, since `fc` withholds its description.
  Do not turn it off unless the user explicitly asks.
- `pfctl -d` switches off the firewall **and NAT** until the next
  reload: everyone behind it loses internet access. It is not a
  safety net for Hostwarden.
- `configctl filter flush states` and the `filter kill …` actions
  drop live connections, including your own SSH session. Ask
  first.

## Replace: Service Manager

- **Enabled services:** `pluginctl -s` lists the services OPNsense
  runs, including the ones it starts itself, which `rc.conf` does
  not name; `pluginctl -S` gives the same as JSON with a `status`
  per service.
- **Service status:** `pluginctl -s <name> status`.
- `pluginctl -s <name> restart|start|stop|status` controls one.
  `configctl service list` (JSON) and
  `configctl service restart <name>` do the same through `configd`.
- Some services have their own namespace, e.g.
  `configctl webgui restart`, `configctl openssh restart`.
- Avoid `service <name> restart`: the generated config is written
  by `configd`, not by the rc.d script. The documented exception is
  `service configd restart`.
- `rules/service-reload.md` still decides when to ask. Restarting
  `openssh` over SSH needs the same care as on any host.

## Replace: Networking

- Interfaces, addresses, routes, DNS and the hostname are set in
  the web UI and rendered from `config.xml`. Never edit `rc.conf`
  or `resolv.conf`, and never restart `netif` or `routing` by hand.
- `ifconfig` and `netstat -rn` are fine for reading.

## Network configuration read

What the firewall knows about the networks behind it — interfaces,
VLANs, static routes, DHCP scopes and its WAN interfaces — read
from `/conf/config.xml` over the SSH login Hostwarden already has,
and folded into `memory/topology.md`
(`rules/network-topology.md` → Folding a configuration read). No
API key is set up for it: OPNsense grants API privileges per page,
not per method, and has no read-only scope to offer
(`docs/adr/20260925-appliances-read-over-ssh-allow-list.md`).

**An allow-list, never a section printed whole.** `config.xml`
holds secrets inside the very elements this read needs: a wireless
interface's passphrase sits under `<interfaces>`, a DDNS key under
the DHCP settings. So the read loads the configuration with the
product's own loader and prints only the keys below, as
`key=value` lines, and no free text: a value that is not an
address, a number, an identifier or a domain name prints as
`withheld`, and a key it does not find as `not read`, never
empty. Nothing else from `config.xml` reaches
the conversation (`rules/secrets.md`).

One `sh -s` bundle, since root's csh would run a command line
(Access and Shell), as root or through the privilege prefix
(`rules/privilege-escalation.md` → Stand-ins for sudo); without one
the read is not run:

```bash
<privilege prefix>
[ "$SUDO" = - ] && { echo "config=unknown(needs-root)"; exit 0; }
$SUDO php <<'PHP'
<?php
require_once("config.inc");
// Allow-listed keys only, and no free text: a value that is not
// an address, a number, an identifier (ID) or a domain name (DN)
// is withheld.
const V = '#^[A-Za-z0-9 ._:/,-]{1,64}$#';
const ID = '#^[A-Za-z0-9_.-]{1,32}$#';
const DN = '#^[A-Za-z0-9-]{1,63}([.][A-Za-z0-9-]{1,63})*$#';
function v($x, $r = V) {
  // A value the model stores as a list, Kea's pools say: its leaves.
  if (is_array($x)) {
    $l = [];
    array_walk_recursive($x, function ($e) use (&$l) { $l[] = $e; });
    $x = implode(',', $l);
  }
  if (!is_string($x) && !is_int($x)) return 'not read';
  $x = trim(str_replace("\n", ',', (string)$x));
  if ($x === '') return 'not read';
  return preg_match($r, $x) ? $x : 'withheld';
}
function p($k, $x, $r = V) { echo $k, '=', v($x, $r), "\n"; }
function items($a) {
  if (!is_array($a)) return [];
  foreach ($a as $k => $e) if (!is_int($k) && !is_array($e)) return [$a];
  return array_values($a);
}
$c = $GLOBALS['config'] ?? [];
$gw = [];
foreach (items($c['gateways']['gateway_item'] ?? null) as $g) {
  $n = v($g['name'] ?? null, ID); $gw[$n] = $g['gateway'] ?? null;
  p("gateway.$n.address", $g['gateway'] ?? null);
  p("gateway.$n.interface", $g['interface'] ?? null);
}
$f = ['if' => 'device', 'ipaddr' => 'ipv4',
  'subnet' => 'ipv4-prefix', 'ipaddrv6' => 'ipv6',
  'subnetv6' => 'ipv6-prefix', 'gateway' => 'gateway',
  'gatewayv6' => 'gateway6', 'dhcp6-ia-pd-len' => 'pd-len',
  'track6-interface' => 'track6'];
foreach ((array)($c['interfaces'] ?? []) as $n => $i) {
  if (!is_array($i) || !isset($i['enable'])) continue;
  $n = v($n, ID);
  foreach ($f as $k => $o) p("if.$n.$o", $i[$k] ?? null);
}
foreach (items($c['vlans']['vlan'] ?? null) as $l) {
  $n = v($l['vlanif'] ?? null, ID);
  p("vlan.$n.tag", $l['tag'] ?? null);
  p("vlan.$n.parent", $l['if'] ?? null);
}
foreach (items($c['staticroutes']['route'] ?? null) as $k => $r) {
  if (isset($r['disabled'])) continue;
  $g = v($r['gateway'] ?? null, ID);
  p("route.$k.network", $r['network'] ?? null);
  p("route.$k.gateway", $g);
  p("route.$k.via", $gw[$g] ?? null);
}
// Which DHCP server runs, from OPNsense's pluginctl or pfSense's
// service list: a server switched off keeps its settings.
$run = []; $known = false; $pf = false;
if (is_executable('/usr/local/sbin/pluginctl')) {
  $l = json_decode((string)shell_exec('pluginctl -S'), true);
  // A failed call or non-JSON answer must not read as "no DHCP
  // service running": only a decoded, non-empty list says so.
  if (is_array($l) && $l) {
    $known = true;
    foreach ($l as $k => $s) {
      $s = is_array($s) ? $s : [];
      $n = (string)($s['name'] ?? $k);
      $i = (string)($s['id'] ?? '');
      // Kea's four services share one name; `id` tells DHCPv4 apart.
      if (preg_match('/^dhcpd$/i', $n)) $b = 'isc';
      elseif (preg_match('/dnsmasq/i', $n)) $b = 'dnsmasq';
      elseif (preg_match('/kea/i', $n)) $b = $i === 'v4' ? 'kea' : '';
      else continue;
      $t = $s['status'] ?? null;
      $on = is_string($t) ? stripos($t, 'is running') !== false : !empty($t);
      p('service.' . v($n, ID) . ($i === '' ? '' : '.' . v($i, ID)),
        $on ? 'running' : 'stopped');
      if ($on && $b !== '') $run[$b] = true;
    }
  }
} elseif ((@include_once 'service-utils.inc') !== false) {
  $l = get_services();
  if (is_array($l) && $l) {
    $known = $pf = true;
    foreach ($l as $s) {
      $n = (string)($s['name'] ?? '');
      if (!preg_match('/dhcp|kea/i', $n) || preg_match('/6|relay/i', $n))
        continue;
      $on = (bool)get_service_status($s);
      p('service.' . v($n), $on ? 'running' : 'stopped');
      if ($on) $run[$c['dhcpbackend'] ?? 'isc'] = true;
    }
  }
}
p('dhcp.backend', $c['dhcpbackend'] ?? null);
p('dhcp.running', $known ? ($run ? implode(',', array_keys($run))
  : 'none') : null);
if ($pf ? $run : ($run['isc'] ?? false)) {
  foreach ((array)($c['dhcpd'] ?? []) as $n => $d) {
    if (!is_array($d) || !isset($d['enable'])) continue;
    $n = v($n, ID);
    p("dhcpd.$n.from", $d['range']['from'] ?? null);
    p("dhcpd.$n.to", $d['range']['to'] ?? null);
    p("dhcpd.$n.domain", $d['domain'] ?? null, DN);
  }
}
if ($run['dnsmasq'] ?? false) {
  foreach (items($c['dnsmasq']['dhcp_ranges'] ?? null) as $k => $r) {
    p("dnsmasq.$k.interface", $r['interface'] ?? null);
    p("dnsmasq.$k.from", $r['start_addr'] ?? null);
    p("dnsmasq.$k.to", $r['end_addr'] ?? null);
    p("dnsmasq.$k.domain", $r['domain'] ?? null, DN);
  }
}
if (!$pf && ($run['kea'] ?? false)) {
  $e = $c['OPNsense']['Kea']['dhcp4'] ?? [];
  foreach (items($e['subnets']['subnet4'] ?? null) as $k => $s) {
    p("kea.$k.subnet", $s['subnet'] ?? null);
    p("kea.$k.pools", $s['pools'] ?? null);
    p("kea.$k.domain", $s['option_data']['domain_name'] ?? null, DN);
  }
}
PHP
ifconfig -a | grep -E '^[a-z]|inet6? |ether |vlan: '
```

`config.inc` is the loader the product's own scripts use, and
`$config` the configuration it loads. pfSense's file uses the same
program (`rules/appliance/pfsense.md` → Network configuration
read), so it knows both products: `pluginctl` is OPNsense's, and
on OPNsense `dhcp.backend` is `not read`.

- **Per interface** (`if.<name>.*`): `<name>` is OPNsense's
  internal name (`wan`, `lan`, `opt1`), `device` the FreeBSD
  interface. Its description, the name the web UI shows, is free
  text and is not read, like every other description. `ipv4` is
  an address with
  `ipv4-prefix`, or the method: `dhcp`, `pppoe`, `pptp` or `l2tp`.
  `ipv6` likewise: an address, or `dhcp6`, `slaac`, `6rd`, `6to4`,
  or `track6`, a LAN that takes its prefix from the WAN `track6`
  names. `pd-len` is the size of the prefix a WAN asks for, as its
  distance from `/64`: `8` is a `/56`, `16` a `/48`. The program
  leaves out a disabled interface, static route or `dhcpd` scope.
- **Named gateways** (`gateway.<name>.*`): only a gateway added by
  hand under Gateways in the UI is stored in `gateway_item`, so
  only that kind gets a line here. OPNsense also builds one on its
  own for a WAN whose `ipv4` is `dhcp`, `pppoe`, `pptp` or `l2tp`,
  or whose `ipv6` is `dhcp6`, `slaac`, `6rd` or `6to4`, named
  `<if>_GW`, `<if>_DHCP`, `<if>_PPPOE`, `<if>_PPTP`, `<if>_L2TP`,
  `<if>_DHCP6`, `<if>_SLAAC`, `<if>_6RD` or `<if>_6TO4`, and marks
  it virtual, so it never reaches `config.xml`; a LAN's `track6`
  takes its prefix from the WAN and has no gateway of its own to
  build. `if.<name>.gateway` or `.gateway6` can name such a
  gateway, and a static route can point at one, with no matching
  `gateway.<name>.*` line to go with it: that is this gap, not a
  parsing failure. Its own live address — the upstream router's,
  not the WAN interface's — is not read either: OPNsense keeps it
  in its own dynamic-gateway state, set by whichever client
  configured that WAN, never in `config.xml`.
- **What counts as WAN:** the interface named `wan`, one with a
  `gateway` or `gateway6` of its own (an upstream gateway,
  multi-WAN), and one whose `ipv4` is `dhcp`, `pppoe`, `pptp` or
  `l2tp`. A WAN's live address comes from the `ifconfig` lines of
  its device, since a dynamic method leaves none in the
  configuration; a PPPoE WAN's device is its `pppoe<n>`. A WAN
  whose IPv4 runs through a `gif` tunnel to the provider is
  DS-Lite only where the user says so.
- **VLANs** (`vlan.<device>.*`): the tag and the parent. A VLAN's
  own description is free text and is not read.
- **Static routes** (`route.<n>.*`): the network, the gateway's
  name and `via` its address from the gateway list — `not read`
  for `via` where the route's own gateway is one of the virtual
  ones the gateway bullet above describes.
- **DHCP:** OPNsense runs one of three servers, ISC (`dhcpd.*`,
  a plugin since 26.1), dnsmasq (`dnsmasq.*`, the default since
  25.7) or Kea (`kea.*`, the default for new installs since 26.1).
  The `service.*` lines, from `pluginctl -S`, say which runs, and
  `dhcp.running` names them: the program prints the scopes of a
  running server alone, since a server switched off keeps its
  settings in `config.xml`. `dhcp.running=none` means every range
  reads `static only (DHCP off)`; `not read` means the program
  could not tell, and every range stays `DHCP not known`. A scope
  gives its range, or Kea's pools, and its domain name; a running
  server with no scope on an interface leaves that range
  `static only (DHCP off)`. dnsmasq also runs as a DNS forwarder
  alone, which then prints no scope.
- **The `ifconfig` lines** give each device's MAC (`ether`),
  which `rules/network-topology.md` → Range identity compares, and
  its live addresses.
- **Never read here:** firewall and NAT rules, which are the
  security audit's; DHCP leases; the rest of the configuration.

Where a line prints `not read` on a firewall whose web UI shows
the setting, the element is elsewhere on this release: report it
as not read, never guess another name.

## Replace: Accounts

- Users, groups, passwords and SSH keys are managed under
  System > Access > Users and written from `config.xml`; never
  `pw useradd`, `usermod` or `userdel`. Reading
  `/etc/master.passwd` as root for a verdict, as the base file
  describes, is fine.

## Replace: sshd

- sshd is `/usr/local/sbin/sshd`, its generated configuration
  `/usr/local/etc/ssh/sshd_config` (Access and Shell).
- Its options are under System > Settings > Administration:
  "Permit password login" sets both `PasswordAuthentication` and
  `ChallengeResponseAuthentication`, "Permit root user login" sets
  `PermitRootLogin`, and `AllowGroups wheel` and
  `X11Forwarding no` are always written. Report a finding as the
  option to change.
- Auth log: System > Log Files > Audit, kept under
  `/var/log/audit/` one file per day. Checksum of a file:
  `sha256 -q <file>`.

## Replace: Mail and Time

- Time sync is `ntpd`, configured in the web UI; `ntpq -pn` reads
  it as on FreeBSD.
- Mail notifications are configured in the web UI; a missing MTA
  behind `mailwrapper` is not a finding.

## Remove: Directory Conventions > sudo

## Add: Filesystem

- Take ZFS snapshots before an update with `configctl zfs
  snapshot`, see Updates, rather than with `bectl`.

## Remove: Console Configuration

## Remove: QEMU/UTM Emulated x86_64 Workarounds

## Remove: Common Pitfalls > `/etc/rc.conf` is central

## Remove: Common Pitfalls > `sudo` is not installed by default

## Remove: Common Pitfalls > `freebsd-update` vs `pkg`

## Replace: Logs

- One file per day: `/var/log/<area>/<area>_<YYYYMMDD>.log`,
  written by syslog-ng.
- `opnsense-log -l` lists the areas; `opnsense-log <area>` prints
  the current log, `opnsense-log -n <area>` its path
  (`/var/log/<area>/latest.log`). Never use `-f` over
  non-interactive SSH: it does not exit.
- `/var` may be a RAM disk (an option in System > Settings): then
  `df /var/log` names `tmpfs` or an `md` device, and the log does
  not survive a reboot. Not a finding on its own
  (`rules/verify-before-reporting.md`).
- No `journalctl`. `logger -t hostwarden` lands in the `system`
  area, but only at level notice or higher: keep `logger`'s
  default priority, never `-p user.info`. It also needs local
  logging to be on.
- **The syslog stream** is the `system` area's daily files, oldest
  first; the glob sorts them by date:
  ```
  syslog_stream() { cat /var/log/system/system_*.log; }
  ```
  "Maximum preserved files" under System > Settings > Logging sets
  how many days are kept. The activity check reads it back with:
  ```
  syslog_stream | grep -E "hostwarden|heinzel" | awk "$C"
  syslog_stream | head -1
  ```
  The first line is the oldest entry (`rules/activity-check.md` →
  How far back it reached). A shell function needs `sh`: send the
  call as the `sh -s` bundle (`rules/ssh-connections.md` → Bundle
  commands), never as a command line, which root's csh would run
  (see Access and Shell).

## Housekeeping and Audits

- Pending updates come from `configctl firmware probe` (see
  Updates); they are the finding, and replace the FreeBSD
  baseline's Release Support, Pending Updates and Update
  Notification. Check that the anti-lockout rule is on.
  `pfctl -si` reporting `Status: Disabled` is **CRITICAL** "No
  active firewall": `pfctl -d` leaves it off until the next
  reload.
- Report settings OPNsense generates as web UI changes, not file
  edits.
- Onboarding and every housekeeping run, a scheduled one included,
  run the Network configuration read and fold it.

**Housekeeping** runs the FreeBSD baseline with these changes:

- Firewall Status: `pfctl -si | head -1` (root) reads
  `Status: Enabled`; ipfw is not used. The `_enable` check does
  not apply.
- Time Sync: judge by `ntpq -pn` alone; `ntpd_enable` is not where
  the vendor enables ntpd.
- Failed Services: `pluginctl -S` (Replace: Service Manager)
  replaces the `service -e` loop; a service not running is WARN.
  A call that fails or prints nothing is not a clean result: report
  Failed Services as not read, never as nothing to flag.
- Certificate expiry: also the web UI's
  `/usr/local/etc/lighttpd_webgui/cert.pem`.
- Backups: a copy off the box needs a backup plugin
  (`pkg info -g 'os-*backup*'`); none installed is INFO.

**A security audit** runs the FreeBSD sections with these changes:

- SSH: judged as usual while sshd runs — an audit that came in
  over SSH shows it does; locally or on the console, check the
  `openssh` entry of `pluginctl -S` first, and with SSH off report
  only that. A call that fails or prints no `openssh` entry is not
  read, never taken as SSH off. Report findings as the options in
  Replace: sshd.
- Firewall: the appliance case in the security skill's
  `references/firewall.md`; the WAN rules are under Firewall >
  Rules > WAN. From the same `pfctl -s rules` output, no
  `sshlockout` rule means OPNsense's own login lockout (on by
  default) was disabled under Firewall > Settings > Advanced:
  INFO.
- Kernel: OPNsense sets `drop_redirect`, `kern.randompid` and
  `see_other_uids`/`gids` itself (System > Settings > Tunables):
  one the kernel table flags was changed on this box. The two
  `security.bsd.unprivileged_*` keys keep FreeBSD's default: not a
  finding here.
- SUID/SGID: files `pkg which` attributes to a package (`opnsense`
  itself or a port; it takes the whole list at once) are expected.
  The base system comes as sets, not packages; judge those against
  the FreeBSD list.

**Fleet audit:** the unattended-upgrades rows are replaced by the
"Automatic firmware update" cron job and the pending updates; the
WAN rules are the firewall rows to compare. The time daemon comes
from `pluginctl -S`: a failed or empty call is not read, never no
time daemon; the MTA rows are `n/a (OPNsense)`.
