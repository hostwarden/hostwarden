---
sidebar_position: 6
description: How Hostwarden keeps a hallucinated command off a live server.
---

# Against hallucinated commands

LLMs can "hallucinate" — confidently produce commands with wrong
flags, incorrect file paths, or syntax that doesn't exist on the
server's specific OS and version. On a live system, a hallucinated
command can be dangerous. Hostwarden reduces this risk with multiple
layers.

## Distro-specific rule files

Instead of relying on the LLM's memory, Hostwarden loads a verified
rule file for each platform (Debian, RHEL, SUSE, Alpine, FreeBSD,
macOS). These files contain the correct commands, package managers,
firewall tools, and common pitfalls for each distro. The LLM reads
the file and follows it — it doesn't have to guess.

## Verify before running

Hostwarden is instructed to check `--help`, man pages, or upstream
docs before running any command. This catches wrong flags and syntax
before they reach the server.

## Server memory

Each server's OS, version, installed services, and configuration are
recorded in a memory file. On subsequent connections, the LLM reads
facts instead of guessing.

## Test before apply

Commands with a dry-run, test, or validation mode are checked that
way first.

## Human review

Every command is shown to you before it runs. You are the final
safeguard.

No approach eliminates hallucinations entirely. The goal is to
minimize what the LLM needs to recall from training data by putting
verified facts in front of it at every step.
