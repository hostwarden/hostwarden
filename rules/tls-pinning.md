# TLS Pinning

An appliance's web API that Hostwarden calls from the workstation
usually answers with a self-signed certificate. Pin the
certificate's public key instead of switching the check off: curl
then accepts that one key and nothing else. It is reached through
the appliance files that call an API from the workstation, never by
detection.

## Reading the pin

Once per host, from the workstation:

**Fetch the certificate once**, into the scratch directory, and
derive both values from that one file. A second connection can be
answered by a different certificate — a rotation, or someone in the
middle — and the user would then confirm one certificate while the
pin recorded belongs to another:

```
c=$(mktemp)
openssl s_client -connect <host>:443 -servername <host> </dev/null \
  | openssl x509 -outform pem > "$c"
openssl x509 -in "$c" -noout -fingerprint -sha256
openssl x509 -in "$c" -pubkey -noout | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | base64
rm -f "$c"
```

Use the port the appliance's web UI listens on where it is not 443.

**What the user compares is the fingerprint, not the pin.** The pin
hashes the public key, a browser's certificate viewer shows the hash
of the whole certificate, and the two differ for the same
certificate. Show the fingerprint, and once the user confirms it
against what their browser shows for the same host, record the pin
from the same file in server memory as `API pin: sha256//<hash>`.
The pin is a public key's hash, not a secret.

## Using it

Pass `-k --pinnedpubkey 'sha256//<hash>'` on every call. `-k` only
drops the check of the certificate's chain and name, which a
self-signed certificate fails; the pin is still checked, and a
different key fails the call.

## When it no longer matches

A call that fails on the pin is a stop, not a retry, and never a
reason to drop `--pinnedpubkey`. The certificate changed: the user
says why — a renewal, a new certificate they installed, a reset
appliance — and only then is the pin read again and recorded anew.
A change nobody can explain is a finding to report.
