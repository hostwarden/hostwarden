# Web server TLS and headers — Linux, FreeBSD and macOS

What a web server or reverse proxy on the host offers on the wire,
measured against `rules/web-tls.md`. Read-only: it connects to the
host's own listeners from the host itself and changes nothing. It
runs wherever nginx, Apache (`apache2`, `httpd`), Caddy or HAProxy
listens on any port, one without a TLS port included, whose plain
HTTP listener the rating below still covers; elsewhere the line
reads `Web TLS  n/a (no web server)`.

## Find what to probe

Listeners: the address and port of each socket of those four
processes (root needed for the process names, as in
`references/listening-services.md`); 443 on loopback where that
cannot be read, and say so. Probe the address the socket is bound
to, loopback for a wildcard, so a server bound to one interface
address, or another server on the same port of loopback, is not
mistaken for it. Names: the `server_name` lines of
`nginx -T`, the names `apachectl -S` prints, the site blocks of the
Caddyfile or the `crt` files of HAProxy where readable; otherwise
the names in the subject alternative names of the certificate a
port serves without SNI. A decision or the host's memory may name
more. Probe each name on each listener.

## Probes

`LC_ALL=C`, set at the top of the call. `openssl` here must be
OpenSSL: the `/usr/bin/openssl` of macOS is LibreSSL, which rejects
`@SECLEVEL`, so use a Homebrew `openssl` there, and where none is
installed skip the three refusal probes and say so. Set `addr`,
`port` and `h` per name, `hport` for a plain HTTP listener (80 by
default); write an IPv6 `addr` bracketed everywhere, `[::1]`, since
`s_client` and `curl` both need it. `--noproxy '*'` keeps `curl` off
any proxy the environment sets, so every probe reaches the listener:

```sh
port=443; hport=80; addr=127.0.0.1; h=web1.example.com
c() { openssl s_client -connect "$addr:$port" -servername "$h" "$@" </dev/null 2>&1; }
echo "tls1.3: $(c -tls1_3 | grep -E '^New,')"
echo "tls1.2: $(c -tls1_2 | grep -E '^New,')"
echo "tls1.1: $(c -tls1_1 -cipher 'DEFAULT:@SECLEVEL=0' | grep -E '^New,')"
echo "tls1.0: $(c -tls1 -cipher 'DEFAULT:@SECLEVEL=0' | grep -E '^New,')"
echo "legacy-suites: $(c -tls1_2 -cipher 'ALL:-ECDHE+AESGCM:-ECDHE+CHACHA20:@SECLEVEL=0' | grep -E '^New,')"
c | openssl x509 -noout -subject -issuer -enddate
c | openssl x509 -noout -text | grep -E 'Public Key Algorithm|Public-Key:|NIST CURVE'
echo "stapling: $(c -status | grep -i 'OCSP response')"
curl --noproxy '*' -s -o /dev/null -D - -H "Host: $h" "http://$addr:$hport/" | grep -iE '^(HTTP|location)'
curl --noproxy '*' -sk --resolve "$h:$port:$addr" -o /dev/null -D - "https://$h:$port/" | grep -iE '^(HTTP/|server:|x-powered-by:|strict-transport-security:|x-content-type-options:|x-xss-protection:|expect-ct:|feature-policy:|public-key-pins:)'
echo "unknown-sni: $(curl --noproxy '*' -sk -o /dev/null -w '%{http_code}' --resolve "example.invalid:$port:$addr" "https://example.invalid:$port/")"
echo "unknown-host: $(curl --noproxy '*' -sk -o /dev/null -w '%{http_code}' --resolve "$h:$port:$addr" -H 'Host: example.invalid' "https://$h:$port/")"
```

A port where the TLS probes get no handshake and the HTTP probe an
answer is a plain HTTP listener: rate it by the last rows of the
table, and treat the TLS probes as not run for it. A `New, TLSv1.3, Cipher is …`
line is an accepted protocol or
suite; `New, (NONE), Cipher is (NONE)` is a refusal, and so is a
line that is missing together with an `alert` from the server.
A usage error or no output at all is no result: report the probe as
not run, never as passed. `@SECLEVEL=0` lets the local OpenSSL
offer what it would otherwise refuse to send, so the refusal is
the server's. `curl` is missing on some hosts; without it the
header and redirect lines read `not checked`.

## Rating

| Finding | Rating |
| --- | --- |
| Certificate expired or within 7 days | **CRITICAL** |
| TLS 1.0 or 1.1 accepted | **WARN** |
| A TLS 1.2 suite outside ECDHE with AES-GCM or ChaCha20 accepted | **WARN** |
| TLS 1.3 refused | **WARN** |
| Certificate: RSA below 2048 bits | **WARN** |
| Certificate: RSA 2048 to 3071 bits | **INFO** |
| Certificate expires within 30 days | **WARN** |
| No `Strict-Transport-Security` on an HTTPS answer | **WARN** |
| `max-age` below 15552000 (six months) | **INFO** |
| Port 80 serves content, no redirect | **WARN** public, else **INFO** |
| No `X-Content-Type-Options: nosniff` | **INFO** |
| A version in `Server`, or any `X-Powered-By` | **INFO** |
| A legacy header (→ the probe's list) | **INFO** |
| An unknown SNI or `Host` gets a page (2xx, 3xx) | **INFO** |
| No OCSP response where the certificate names a responder | **INFO** |
| Plain HTTP listener on a private address | **INFO** |

The certificate's own expiry is also a housekeeping line; this
audit reports it with the rest of the served chain rather than
asking twice. `Cipher is` on a refused probe never rates; only an
accepted one does. Whether a private address counts as public is
read from the address, never assumed; a listener on a private
address that is reachable from the internet through a forward is
not seen from the host, and the report says the probe could only
read the host's own view.

A recorded decision settles what `rules/web-tls.md` → Stricter,
on request lists and what it names, and nothing else
(`rules/decisions.md` → Rating findings): the finding reads
`DECIDED`. Without a decision on "Internal is no reason", a plain
HTTP listener reachable only from a private network stays INFO;
with it, that listener is a **WARN**. The stricter choices are
never more than INFO without a decision.

## Report line

One line per name and port, in the report's Checks section:

    Web TLS  WARN — web1.example.com:443 accepts TLS 1.1
    Web TLS  OK — web1.example.com:443, TLS 1.2/1.3, ECDSA P-256,
             HSTS 2y, no version in Server

Unprivileged, the names and ports may be incomplete
(`references/unprivileged.md`); the line says which were probed.
