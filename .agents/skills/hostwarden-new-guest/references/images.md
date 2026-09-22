# Cloud Images

A VM starts from its distribution's official cloud image, the
variant that runs cloud-init, and only after its checksum matched.
Download it on the host, over HTTPS, and check it there. Take the
current release from a live search (`rules/version-check.md`);
the URLs below name the pattern, not a release to use.

A checksum that does not match stops the creation: delete the
download, say so, and never use it. A download already on the
host is used again while its checksum still matches the current
list.

## Debian

- Image: `https://cloud.debian.org/images/cloud/<codename>/latest/debian-<n>-genericcloud-amd64.qcow2`.
  `genericcloud` has fewer kernel drivers than `generic`, enough
  for KVM; `nocloud` runs no cloud-init and cannot take the
  baseline.
- Check: `SHA512SUMS` from the same directory, then
  `sha512sum --ignore-missing -c SHA512SUMS`.
- Debian signs no checksum list for these images: the TLS
  download from `cloud.debian.org` is what the checksum rests on.
  Say so once when the user is shown the plan.

Source: <https://cloud.debian.org/images/cloud/>

## Ubuntu

- Image: `https://cloud-images.ubuntu.com/<codename>/current/<codename>-server-cloudimg-amd64.img`,
  a qcow2 despite its name.
- Check: `SHA256SUMS` and its detached signature `SHA256SUMS.gpg`,
  signed by the UEC Image Automatic Signing Key, fingerprint
  `D2EB 4462 6FDD C30B 513D  5BB7 1A5D 6C4C 7DB8 7C81`:

  ```bash
  gpg --keyserver hkp://keyserver.ubuntu.com \
    --recv-keys D2EB44626FDDC30B513D5BB71A5D6C4C7DB87C81
  gpg --keyid-format long --verify SHA256SUMS.gpg SHA256SUMS
  sha256sum --ignore-missing -c SHA256SUMS
  ```

Source: <https://ubuntu.com/docs/public-images/public-images-how-to/verify-image-checksum/>

## Rocky Linux

- Image: `https://dl.rockylinux.org/pub/rocky/<n>/images/x86_64/Rocky-<n>-GenericCloud-Base.latest.x86_64.qcow2`.
- Check: `<image>.CHECKSUM` and `<image>.CHECKSUM.asc` beside it,
  signed with the release key `RPM-GPG-KEY-Rocky-<n>`; the
  fingerprints are on <https://rockylinux.org/resources/gpg-key-info>.
  The list is in BSD format (`SHA256 (<file>) = …`), which
  `sha256sum -c` reads.

## AlmaLinux

- Image: `https://repo.almalinux.org/almalinux/<n>/cloud/x86_64/images/AlmaLinux-<n>-GenericCloud-latest.x86_64.qcow2`.
- Check: `CHECKSUM` and `CHECKSUM.asc` in the same directory, with
  `https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux-<n>`;
  its fingerprint is in the release notes on
  <https://wiki.almalinux.org>.

## Fedora

- Image: `Fedora-Cloud-Base-Generic-<n>-<build>.x86_64.qcow2` under
  `https://dl.fedoraproject.org/pub/fedora/linux/releases/<n>/Cloud/x86_64/images/`.
- Check: the `-CHECKSUM` file there is signed inline:

  ```bash
  curl -O https://fedoraproject.org/fedora.gpg
  gpgv --keyring ./fedora.gpg --output - <checksum file> | sha256sum --ignore-missing -c
  ```

Source: <https://fedoraproject.org/security/>

## Fedora CoreOS

- Image: `coreos-installer download -s <stream> -p <platform>
  -f qcow2.xz --decompress`, with `<platform>` `qemu` for libvirt
  and `proxmoxve` for Proxmox VE. The platform decides what the
  image reads its Ignition config from, so the wrong one comes up
  unconfigured.
- Check: the download verifies the release's signature itself.
  Read `coreos-installer download --help` on the host for the flag
  that turns that off, so the plan can say it was not passed.

Source: <https://docs.fedoraproject.org/en-US/fedora-coreos/>

## Flatcar

- Image: `flatcar_production_<platform>_image.img` from the
  channel, `<platform>` `qemu` or `proxmoxve`.
- Check: the `.sig` beside it, against the image signing key,
  fingerprint
  `F88C FEDE FF29 A5B4 D952 3864 E25D 9AED 0593 B34A`:

  ```bash
  gpg --verify flatcar_production_qemu_image.img.sig
  ```

Source: <https://www.flatcar.org/security/image-signing-key/>

## Keys on the host

`gpg` and `gpgv` on the host import into a keyring of their own
for this, never root's default one:
`GNUPGHOME=$(mktemp -d)` in the same call, removed afterwards.
A signature that does not verify stops the creation like a
checksum that does not match.
