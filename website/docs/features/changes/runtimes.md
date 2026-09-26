---
sidebar_position: 7
description: Installs language runtimes and sets up restricted
  accounts for CI/CD deployments.
---

# Language runtimes and deploy users

```
 ❯ Install the latest stable Node.js on web1
 ❯ Set up deployment for the shop on web1
```

## Language runtimes

`hostwarden-runtimes` installs, upgrades, reports on and removes
Node.js, Python, Ruby, Go, Java and the other runtimes
[mise](https://mise.jdx.dev) carries, from mise unless you name
another way, and sets up the shell so they are found over SSH. A
question about installed versions installs nothing. Appliances get
no runtime.

## Deploy users

`hostwarden-deploy-user` sets up, audits or removes an account for
CI/CD deployments: its own SSH key, a restricted shell, no
password, a directory it owns, and sudo only as narrow as the
deployment needs — never root or a person's account. Installing
the key is yours; Hostwarden hands you the block to add.
