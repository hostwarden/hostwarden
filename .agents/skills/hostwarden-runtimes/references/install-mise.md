# Installing mise

Reached from step 2 of the `hostwarden-runtimes` skill, when
the pre-install check found no mise on the host. Skip it when
mise is already there — installing a runtime does not
reinstall the manager.

## Installation

Only install mise when the Pre-Install Check found
no existing installation. mise is installed as
**the SSH user** (not root).

### Default: Standalone Installer (no root)

Always try this first. It works on any Linux distro,
needs no root or sudo, and avoids third-party repos.

```
curl https://mise.run | sh
```

- Installs to `~/.local/bin/mise`
- No root or sudo needed — works in unprivileged mode
- Works on all distro families
- Updates via `mise self-update`
- Requires `curl` (fall back to `wget` if unavailable:
  `wget -qO - https://mise.run | sh`)
- Does **not** modify shell config — the SSH
  Non-Interactive Shell Setup section handles PATH

After installing, add `~/.local/bin` to PATH in
`~/.bashrc` (before the interactive guard) so the
`mise` binary itself is found over SSH. This is
handled in the SSH Non-Interactive Shell Setup section
below.

### Alternative: Distro Package Manager (needs root)

Only use this when the user **explicitly prefers** it
and root access is available. **Ask the user before
adding the repo** — these are third-party repos.

Trade-offs:

- **Pro:** auto-updates via system package manager
- **Con:** requires root, adds a third-party repo,
  `mise self-update` is disabled

#### Debian & Ubuntu

```
apt-get update && apt-get install -y gpg wget
install -d -m 755 /etc/apt/keyrings
wget -qO - https://mise.jdx.dev/gpg-key.pub \
  | gpg --dearmor \
  | tee /etc/apt/keyrings/mise-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" \
  | tee /etc/apt/sources.list.d/mise.list
apt-get update && apt-get install -y mise
```

#### RHEL & Fedora

```
dnf install -y dnf-plugins-core
dnf config-manager --add-repo \
  https://mise.jdx.dev/rpm/mise.repo
dnf install -y mise
```

On RHEL 7/CentOS 7, use `yum` instead of `dnf`.

**Note:** `dnf config-manager` syntax differs
between dnf4 and dnf5, and the yum-era command is
`yum-config-manager` — check `--help` on the
target first.

#### SUSE

```
zypper addrepo \
  https://mise.jdx.dev/rpm/mise.repo mise
zypper refresh
zypper install -y mise
```

### Which Method to Use

1. **Check first:** run the Pre-Install Check. If
   mise already exists, skip installation entirely.
2. **Default:** standalone installer — always try
   this first when no mise is found.
3. **Alternative:** distro package — only when the
   user explicitly prefers it and root access is
   available.
4. **Unprivileged mode:** standalone installer is
   the only option (no root for package manager
   installs).
