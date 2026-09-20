# Removing a deploy user

Reached when the user asks to take a deployment setup out.
Five steps, one of which only they can do.

## Removing a Deploy User

When the user asks to remove a deployment setup:

1. Remove the sudoers file:
   `rm /etc/sudoers.d/deploy`
2. Remove the user and home directory:
   - Linux: `userdel -r deploy`
   - FreeBSD: `pw userdel deploy -r`
3. Ask the user to remove the CI secret.
4. Update server `memory.md` — remove deploy
   entries.
5. Log the removal per `rules/changelog.md`.
