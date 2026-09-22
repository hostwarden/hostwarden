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
Show the value to the user to compare with the certificate their
browser shows for the same host, and record it in server memory as
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
