---
sidebar_position: 2
description: How Hostwarden recognizes several DNS names that
  point to the same server.
---

# Names and aliases

When several DNS names point to the same server, Hostwarden finds
out and keeps their memory in one place.

## Matching an alias

The name ssh connects to resolves to the same address, on the same
SSH port, and the host key matches. The first hostname becomes the
canonical name; the others become symlinks that share its memory.
Each alias can have its own SSH user. The same address on another
port is another machine.

## What gets recorded

Each host records its `FQDN:`. A name without a dot that matches
several servers brings a question before anything is reached. A
`.local` name is asked of mDNS and of DNS separately, and a
disagreement stops for you instead of being taken as an alias.
