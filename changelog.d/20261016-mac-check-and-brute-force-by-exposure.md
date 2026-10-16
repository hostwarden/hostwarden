### Added

- **The baseline expects SELinux or AppArmor, enforcing.** The
  security audit warns only where the module is disabled; SELinux
  in permissive mode, or AppArmor without an enforced profile, is
  a note. The baseline skill gives you the steps instead of taking
  them, since turning one on can stop a service.

### Changed

- **Brute-force protection is rated by exposure.** A service that
  takes a password from the internet with no fail2ban, CrowdSec,
  sshguard or blocklistd watching it is now a warning; with
  key-only SSH and no such service, a missing ban tool is no
  finding. Where one is needed, each OS family names it: fail2ban
  in its normal mode reading the journal, from EPEL on RHEL and
  Package Hub on SLES, and blocklistd on FreeBSD.
