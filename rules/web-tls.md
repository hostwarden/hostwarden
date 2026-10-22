# Web server TLS and headers

The profile for nginx, Apache, Caddy and HAProxy wherever
Hostwarden installs, configures or changes one of them as a web
server or reverse proxy. It covers what the server offers on the
wire and what it passes on; the application behind it owns its
own content. Everything below is the default for what Hostwarden
sets up. A change the user asked for touches only what it names:
an existing setting outside it, such as TLS 1.0 for a legacy
client or a plain-HTTP site, is reported and offered, never
rewritten, and the security audit rates it. The stricter choices are
the user's (→ Stricter, on request).

Order of a change: `rules/version-check.md` for the version to
install, `rules/port-check.md` and `rules/firewall-changes.md` for
the ports 80 and 443, `rules/backups.md` before an edit, then the
config test and the reload as `rules/service-reload.md` says. Test
the result from the host itself with the probes in
`.agents/skills/hostwarden-security/references/web-tls.md`.

## The profile

Mozilla's **Intermediate** profile (Server Side TLS, 6.0):

- TLS 1.2 and 1.3 only.
- TLS 1.2 offers six suites: ECDHE with AES-128-GCM, AES-256-GCM
  or ChaCha20-Poly1305, with an ECDSA or RSA certificate. Every
  connection has forward secrecy and an AEAD cipher. The TLS 1.3
  suites are the three AEAD ones.
- The server does not impose a cipher order.
- Groups as the generator names them for the installed version.
- Session tickets off where the server lets them be switched off
  (stateless tickets weaken forward secrecy unless the key
  rotates).
- Certificate: ECDSA on P-256 or P-384, or RSA of at least 3072
  bits. Mozilla accepts RSA 2048; a new RSA key is made with 3072.
- Issued by ACME and renewed automatically (`certbot`, `acme.sh`,
  Caddy's own). The profile recommends a 90-day lifetime.
- OCSP stapling on where the certificate names an OCSP responder;
  a certificate without one has nothing to staple.
- Port 80 does one thing: redirect to HTTPS on the same host.

Take the directives from Mozilla's generator,
`https://ssl-config.mozilla.org`, for the server and version on
the host, and compare them with what is below; the generator
follows the guidelines, this file follows the generator.
**Modern** (TLS 1.3 only) is a choice for a surface whose clients
are known to support it; the user makes it (→ Stricter, on
request).

A host under configuration management gets the change through it
(`rules/config-management-changes.md`), not by editing the file.

## Per server

Directives are from the servers' own documentation; the nginx,
Apache and HAProxy shapes passed their config tests. `<six suites>` is the
colon-separated list of the six ECDHE names the generator prints.

**nginx**
([ssl module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)):

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers <six suites>;
ssl_prefer_server_ciphers off;
ssl_session_tickets off;
server_tokens off;

server {
    listen 80 default_server;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl default_server;
    ssl_reject_handshake on;
    return 421;
}
server {
    listen 443 ssl;
    server_name web1.example.com;
    ssl_certificate     /etc/ssl/web1.example.com.pem;
    ssl_certificate_key /etc/ssl/web1.example.com.key;
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Content-Type-Options nosniff always;
}
```

The first five lines sit at `http` level (a file in `conf.d/` is
in it): nginx picks the protocols before it reads the SNI name, so
a setting only in the named server would not reach the handshake.
A distribution's `nginx.conf` often sets some of them already;
change those lines, since a second one is an error.
`ssl_reject_handshake` (1.19.4) refuses an SNI name the server does
not serve, and `return 421` answers a request that completes TLS
with a valid name and an unknown `Host`. Where the certificate names a
responder, `ssl_stapling on`, `ssl_stapling_verify on`, a `resolver`
and `ssl_trusted_certificate` go in. `add_header` is inherited only by a level
that sets none of its own; repeat the lines in a `location` that adds one.

**Apache**, at server level, outside any virtual host
([mod_ssl](https://httpd.apache.org/docs/current/mod/mod_ssl.html)):

```apache
SSLProtocol -all +TLSv1.2 +TLSv1.3
SSLCipherSuite <six suites>
SSLHonorCipherOrder off
SSLSessionTickets off
ServerTokens Prod
ServerSignature Off
Header always set Strict-Transport-Security "max-age=63072000"
Header always set X-Content-Type-Options "nosniff"
```

`SSLUseStapling on` needs an `SSLStaplingCache` at server level
(OCSP stapling, where the certificate names a responder). Port 80
carries `Redirect permanent / https://web1.example.com/`.

**Caddy**
([tls directive](https://caddyserver.com/docs/caddyfile/directives/tls)):
the defaults already are TLS 1.2 and 1.3, and Caddy gets and
renews certificates and redirects HTTP to HTTPS itself. Leave
`protocols`, `ciphers` and `curves` unset; the documentation
advises against changing them.

```caddyfile
web1.example.com {
    header Strict-Transport-Security "max-age=63072000"
    header X-Content-Type-Options nosniff
    reverse_proxy 127.0.0.1:8080
}
```

**HAProxy**
([configuration](https://docs.haproxy.org/3.0/configuration.html)):

```haproxy
global
    ssl-default-bind-ciphers <six suites>
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
defaults
    mode http
frontend fe
    bind :80
    bind :443 ssl crt /etc/ssl/web1.example.com.pem strict-sni
    http-request redirect scheme https code 301 unless { ssl_fc }
    http-after-response set-header Strict-Transport-Security "max-age=63072000"
    http-after-response set-header X-Content-Type-Options nosniff
```

`http-after-response` also covers the answers HAProxy makes itself,
a 503 without a backend among them (HAProxy 2.2 and later; a plain
`http-response` misses them). `mode http` is required: without it
the `http-request` and `http-after-response` lines are ignored with only a
warning, so read the
warnings of `haproxy -c`, not just its exit status. `strict-sni`
refuses a name no certificate matches. Curves go in
`ssl-default-bind-curves` from the generator.

## Behind a proxy

A reverse proxy at the edge is the only one that sets what the
backend learns about the client:

- It **overwrites** `X-Forwarded-For`, `Forwarded` and `X-Real-IP`
  with what it saw, never appends to a client's value. nginx:
  `proxy_set_header X-Forwarded-For $remote_addr;`. HAProxy:
  `http-request del-header X-Forwarded-For` (and the other two)
  before `option forwardfor`. Apache's mod_proxy adds its own
  headers (`ProxyAddHeaders`); `RequestHeader unset X-Forwarded-For
  early` removes the client's first. Caddy ignores the incoming
  values of its `X-Forwarded-*` headers unless `trusted_proxies`
  lists the sender, so set that only behind a proxy the user
  names.
- A host name the server does not serve gets an error, not the
  default site: nginx's reject handshake and default server above,
  HAProxy's `strict-sni` plus `http-request deny deny_status 421
  unless <acl on hdr(host)>`, an Apache catch-all virtual host listed first
  for each address and port that returns 421, a Caddy site block per name.
- No version in `Server` and no `X-Powered-By`
  (`server_tokens off`, `ServerTokens Prod`; the application's own
  header is reported, not removed).

## Headers

The proxy sets these on every response it serves itself or
forwards:

| Header | Value |
| --- | --- |
| `Strict-Transport-Security` | `max-age=63072000` |
| `X-Content-Type-Options` | `nosniff` |

`includeSubDomains` only when every subdomain answers on HTTPS
too, and never `preload` (→ Stricter, on request). A strict
`Content-Security-Policy`, `Referrer-Policy`, `Permissions-Policy`
and the cross-origin headers belong to the application, which
knows what its pages load; a proxy that sets them for an
application it does not know breaks it. For a backend that serves
no HTML, `Content-Security-Policy: default-src 'none';
frame-ancestors 'none'` is safe to add at the proxy.

Do not add `X-XSS-Protection`, `Expect-CT`, `Feature-Policy` or
`Public-Key-Pins`: deprecated or gone, and an existing one is
reported, not removed.

## Stricter, on request

These are the user's to choose. Hostwarden neither sets them by
default nor warns for lacking them; at most an INFO line. After a
first web server or proxy is set up on a host, if no decision covers them,
say in one line that they exist and ask which, if any, to record;
when none apply, record nothing (`rules/decisions.md` → Writing
one, → Proposing, which stop it from asking again once answered):

- **HSTS preload.** `max-age=63072000; includeSubDomains; preload`
  and submission to the browsers' list. It binds every subdomain
  to HTTPS in the browser, and leaving the list takes months to
  reach users. Check every subdomain first.
- **Encryption past the proxy.** The proxy re-encrypts to its
  backends and verifies their certificate (nginx
  `proxy_pass https://` with `proxy_ssl_verify on`, HAProxy
  `server … ssl verify required ca-file …`, Apache
  `SSLProxyEngine on` and `SSLProxyVerify require`, Caddy's
  `transport http { tls }`), and database connections verify the
  server (PostgreSQL `sslmode=verify-full`). Without this decision,
  nothing is changed or reported about it.
- **Internal is no reason.** The profile applies to every listener
  on a non-loopback address, a VPN or private network included.
  Without this decision, a plain HTTP listener reachable only from
  a private network is INFO, and TLS settings a reachable listener
  does offer are rated as everywhere.
- **Modern profile.** TLS 1.3 only.
- **Caching limits.** `no-store` on responses with personal data,
  credentials or tokens, nothing `public` that depends on who asks,
  and a shared cache that stores only what the origin marks
  cacheable, never by extension or path. The application
  sets the headers; the proxy's own cache, where one is enabled,
  honours them and adds no rule of its own.

A recorded decision names which of these it settles, as
`rules/decisions.md` → The entry shows: `Settles: web-tls →
Stricter, on request (HSTS preload)`. The security check reads it.
