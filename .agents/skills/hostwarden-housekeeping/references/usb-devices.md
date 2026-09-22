# USB Devices

Which USB devices a host depends on, and whether the one that
matters most, a UPS, is watched by anything. Runs on every
housekeeping run, except where the host's `Virtualization:` line
records a container: a container sees the USB bus of the machine
underneath and would report that machine's devices as its own.
A virtual machine runs it too, since a device passed through to it
is real. On Windows the form in `rules/os/windows.md` →
Housekeeping applies instead.

Only what a server stops doing its job without counts — a UPS, a
radio stick, a serial line, a licence dongle; Reading the output
says what is left out.

## Probe

**Linux** reads sysfs, which needs no root and no `lsusb`:

```sh
ids=
for d in /sys/bus/usb/devices/*; do
  [ -f "$d/idVendor" ] || continue
  read -r v < "$d/idVendor"; read -r p < "$d/idProduct"
  [ "$v" = 1d6b ] && continue
  m=; n=
  [ -f "$d/manufacturer" ] && read -r m < "$d/manufacturer"
  [ -f "$d/product" ] && read -r n < "$d/product"
  echo "== ${d##*/} $v:$p $m $n"
  ids="$ids $v:$p"
  for i in "$d"/*:*; do
    [ -f "$i/bInterfaceClass" ] || continue
    read -r c < "$i/bInterfaceClass"
    read -r sc < "$i/bInterfaceSubClass"
    read -r pr < "$i/bInterfaceProtocol"
    drv=$(readlink "$i/driver")
    echo "   $c $sc $pr ${drv##*/}"
  done
done
ls -l /dev/serial/by-id 2>&1
for r in /lib/udev/rules.d/*nut-usbups* /usr/lib/udev/rules.d/*nut-usbups*; do
  [ -f "$r" ] || continue
  for id in $ids; do
    grep -qi "\"${id%:*}\", ATTR{idProduct}==\"${id#*:}\"" "$r" && echo "nut-ups $id"
  done
  break
done
ps -A -o comm= | grep -E 'ups|nut|apc' | grep -Ev '^cups' | sort -u
upsc -l; apcaccess status 2>&1 | grep -m1 '^STATUS'
```

Each device is a `==` line with its bus path, `vendor:product` ID,
manufacturer and product string, followed by one line per
interface: class, subclass, protocol (hex) and the kernel driver
bound to it, or nothing when none is. `1d6b` is the Linux
Foundation's ID for the root hubs. `/dev/serial/by-id` names each
USB serial device by its manufacturer, product and serial number.
A `nut-ups` line is a `vendor:product` pair that NUT's udev rules
list, where NUT is installed. The last two lines say whether
anything watches a UPS: `upsc -l` names the UPSes the local
`upsd` serves, `apcaccess` prints `STATUS` where `apcupsd` runs,
and the `ps` line names the programs behind them. Read the two
commands first — NUT's driver names carry no common word
(`blazer_usb`, `bcmxcp_usb`, `powerpanel`, …), so the `ps` line
alone proves nothing.

**FreeBSD** needs root; `usbconfig` opens the USB device nodes:

```sh
usbconfig dump_device_desc | grep -E '^ugen|idVendor|idProduct'
usbconfig show_ifdrv
ps -A -o comm= | grep -E 'ups|nut|apc' | grep -Ev '^cups' | sort -u
upsc -l; apcaccess status 2>&1 | grep -m1 '^STATUS'
```

**macOS:**

```sh
ioreg -p IOUSB -l -w0 | grep -E '^ *\+-o |"idVendor"|"idProduct"|"USB Vendor Name"|"USB Product Name"'
pmset -g ps
ps -A -o comm= | grep -E 'ups|nut|apc' | grep -Ev '^cups' | sort -u
upsc -l; apcaccess status 2>&1 | grep -m1 '^STATUS'
```

`ioreg` prints the USB tree, each device followed by the
properties the `grep` keeps; `-l` is what prints them at all.
`idVendor` and `idProduct` come out as decimal numbers there —
record them as the four-digit hex the other families print
(`1452` is `05ac`). `pmset -g ps` lists the power sources macOS
itself watches; a USB UPS it has taken on appears there by
name.

## Reading the output

Leave out, by interface class on Linux or by name elsewhere: hubs
(`09`), mass storage (`08`, drivers `usb-storage` and `uas`),
printers (`07`), audio (`01`), video (`0e`), and HID interfaces
that are a boot keyboard or mouse (`03 01 01`, `03 01 02`). On a
virtual machine also leave out the hypervisor's own emulated
devices: vendor `0627` (QEMU's tablet), `0e0f` (VMware) and
`80ee` (VirtualBox).

Name each remaining device by what it is:

- **UPS** — a `nut-ups` line; else the vendor IDs of the large
  makers, `051d` APC, `0764` CyberPower, `0463` Eaton and MGE,
  `09ae` Tripp Lite, `10af` Liebert, `0d9f` PowerCom, `06da`
  Phoenixtec; else a product string with `UPS` in it. Small makers
  ship generic USB chips whose IDs say nothing: where neither
  names one, ask the user.
- **Serial line** — drivers `ftdi_sio`, `cp210x`, `ch341`, `pl2303`,
  `cdc_acm`. The `/dev/serial/by-id` name usually says what is on
  the other end: a Zigbee, Z-Wave or Thread coordinator (ConBee,
  SkyConnect, ZBT, Sonoff, Z-Stick), a GPS receiver, an infrared
  meter reader, a console cable. Where it does not, record it as a
  serial adapter and ask the user once what it connects to.
- **Mobile modem** — drivers `option`, `qmi_wwan`, `cdc_mbim`.
- **Network adapter** — drivers `r8152`, `ax88179_178a`,
  `cdc_ether`; Bluetooth — `btusb`.
- **Security token or smartcard reader** — interface class `0b`,
  or vendor `1050` (Yubico) or `20a0` (Nitrokey).
- **Licence dongle** — vendor `064f` (WIBU-Systems, CodeMeter) or
  `0529` (Aladdin/SafeNet, Sentinel HASP).
- **Management controller** — a virtual keyboard, mouse or CD-ROM
  from vendor `046b` (American Megatrends) or with `Virtual` in its
  product string is the server's BMC. It is no dependency, but it
  says the machine has an out-of-band console.
- **Anything else** is recorded by its product string.

On a hypervisor a device passed through to a guest is used by the
guest, not by this host: name the guest in the `USB:` line
(`… (1cf1:0030, passed to VM 101)`). The appliance file gives the
command that shows it.

## Memory

Record the result in the host's `memory.md`, one line for all:

```
- USB: UPS APC Back-UPS ES 700 (051d:0002, NUT `ups`); Zigbee ConBee II (1cf1:0030); BMC (046b)
- USB: none relevant
```

`none relevant` tells the next run the check ran; a host without a
`USB:` line has not been checked yet. Keep the `vendor:product`
IDs: they are what the next run compares.

## Findings

Severities as in `references/report-format.md`:

- **WARN:** a UPS is attached and nothing watches it — `upsc -l`
  names none, `apcaccess` does not answer, and no program in the
  `ps` line accounts for it. On macOS the same three answers
  count: a UPS is watched when `pmset -g ps` lists it, or when
  `upsc -l` or `apcaccess` answers, because NUT and apcupsd run
  there too and take the UPS away from Apple's own service. On a
  power cut an unwatched host goes down hard, and so does every
  machine that relies on it to announce the cut.
- **WARN:** a device recorded in `USB:` is gone. Name it; a missing
  radio stick or dongle stops whatever used it.
- **INFO:** a relevant device that memory does not list yet. Add it
  to `USB:`.

The first time a UPS turns up on a host, ask the user once which
other machines it powers, and record the answer in
`memory/network.md` (`rules/server-memory.md` → Cross-server
facts). A scheduled run has nobody to ask
(`references/scheduled.md`): it records the UPS with
`topology unknown` in the `USB:` line, reports that as INFO, and
leaves the question to the next interactive run. Neither run
blocks on it.
