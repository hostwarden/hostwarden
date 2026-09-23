# Accounts on Demand

People sign in to an identity provider (IdP, over OIDC), get a
short-lived user certificate from a user CA the user runs, and log
in to servers where nobody created their account by hand. The
server never sees the IdP: it sees a certificate and a name that has to
resolve at login (`rules/accounts.md` → Certificate Logins).
Nothing at login time creates the account in time;
`pam_mkhomedir` creates only the home (`rules/accounts-probe.md` →
Home Directory at First Login).

Hostwarden reads, asks and reports here. It never writes to the
IdP, the directory or the CA, and it builds none of them. The
products below change often: check their documentation for the
version in use before relying on a line (`rules/version-check.md`).

## The Ways

On demand means one of these models
(`rules/accounts.md` → Which Model a Host Uses):

- **Directory:** SSSD or `nslcd` resolves every directory user,
  mkhomedir creates the home, and the principal is the directory
  user name. Without an LDAP directory: SSSD's `id_provider = idp`
  reads users and groups from Keycloak or Entra ID over their REST
  APIs (SSSD 2.11.0 and later,
  <https://sssd.io/release-notes/sssd-2.11.0.html>; a Technology
  Preview in RHEL 10), or Kanidm serves as IdP and directory in
  one. Test a certificate login before relying on either.
- **Role account:** the CA puts the person's IdP groups into the
  principals, and each role account's principals file lists the
  groups it admits.
- **Agent:** vendor software such as Smallstep SSH, Google OS
  Login or Teleport. Install one only when the user asks for that
  product.

For a few people, the accounts can be created ahead instead:
`rules/accounts.md` → Team Accounts.

## Who May Log In

With an IdP behind the CA, access is limited in three places:

- **Who gets a certificate** (the CA): only the IdP groups meant
  for server access.
- **Which names it carries** (the IdP): Hostwarden cannot see the
  IdP. Ask the user to confirm that people cannot edit the claims
  that become principals, such as their email or username: a
  person who can rename themselves `root` gets a certificate for
  root (`rules/accounts.md` → Certificate Logins). What the CA
  itself lets people get is read as `rules/ssh-ca-issuing.md`
  says.
- **Who may log in here** (the host): the directory's access rule
  (`rules/accounts-probe.md` → Where Accounts Come From).

**Offboarding:** the person is disabled in the IdP first, so no
new certificate is issued, then the certificates still valid are
revoked in the hosts' revocation list (`rules/ssh-ca.md` →
Terms); otherwise the last one lasts to its end.

## Connecting Hosts to the Directory

Across hosts as `rules/accounts.md` → Changes Across Hosts says.
The IdP and the directory go in `memory/network.md`. Per server,
each step asked:

1. **Client:** SSSD with the LDAP backend from the distribution's
   packages (`rules/os/<family>.md`), LDAPS to the directory, and
   the access rule. For authentik's LDAP provider
   (<https://integrations.goauthentik.io/infrastructure/sssd/>):
   `ldap_user_name = cn`, and `default_shell` set, since
   authentik has no `loginShell`. `sssd.conf` is root-only `0600`;
   its bind password is the user's to write (`rules/secrets.md`).
2. **NSS and PAM:** `authselect select sssd` on RHEL and Fedora;
   `libnss-sss` and `libpam-sss` on Debian and Ubuntu. mkhomedir
   as `rules/accounts-probe.md` → Home Directory at First Login
   says. Then `getent passwd <name> && id -Gn <name>` must show
   the person and their groups.
3. **Sudo:** the same `%group` file on every host
   (`rules/accounts.md` → Changing Accounts or Sudo Rules).
4. **sshd:** the user CA's trust (`rules/ssh-ca.md` → User CA
   Trust) and `AuthorizedPrincipalsFile none`
   (`rules/accounts.md` → Certificate Logins). The directives go
   through the user, never into `sshd_config` by Hostwarden. On
   the first host, the principals `ssh-keygen -L -f <certificate>`
   shows must contain the name `getent passwd` finds; where they
   do not, `rules/ssh-ca-issuing.md` → When a Login Fails on the
   Principal. The access test uses the certificate of a person who
   never logged in there, and the home must appear.
5. **Memory:** the `Accounts:` line (`rules/accounts.md` →
   Memory), and the host's SSH CA lines (`rules/ssh-ca.md` →
   Memory).
