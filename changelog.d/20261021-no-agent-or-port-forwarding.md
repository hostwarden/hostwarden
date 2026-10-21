### Security

- **Hostwarden's SSH calls never forward your agent, your display or
  a port.** `memory/ssh_config` sets `ForwardAgent no`,
  `ForwardX11 no` and `ClearAllForwardings yes` ahead of your own
  `~/.ssh/config`, so a `ForwardAgent yes`, a `ForwardX11 yes` or a
  forwarding under `Host *` no longer reaches a managed server. A
  port forwarding a session needs goes through the shared
  connection's socket, and the security audit reports
  `AllowAgentForwarding yes` as INFO.
