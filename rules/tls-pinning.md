# TLS Pinning

An appliance's web API that Hostwarden calls from the workstation
usually answers with a self-signed certificate. Pin the
certificate's public key instead of switching the check off: curl
then accepts that one key and nothing else. It is reached through
the appliance files that call an API from the workstation, never by
detection.

## Reading the pin

Once per host, from the workstation:

```
openssl s_client -connect <host>:443 -servername <host> \
    </dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | base64
```

Use the port the appliance's web UI listens on where it is not 443.

**What the user compares is not that value.** The pin hashes the
public key; a browser's certificate viewer shows the hash of the
whole certificate, and the two differ for the same certificate. So
read the certificate's fingerprint in the same call and show that
one for comparison:

```
openssl s_client -connect <host>:443 -servername <host> \
    </dev/null \
  | openssl x509 -noout -fingerprint -sha256
```

Once the user confirms that fingerprint against what their browser
shows for the same host, record the pin in server memory as
`API pin: sha256//<hash>`. The pin is a public key's hash, not a
secret.

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
