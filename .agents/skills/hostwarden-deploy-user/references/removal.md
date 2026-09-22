# Removing a deploy user

Reached when the user asks to take a deployment setup out.
Five steps, one of which only they can do.

## Removing a Deploy User

When the user asks to remove a deployment setup:

1. Remove the sudoers file:
   `rm /etc/sudoers.d/deploy`, on FreeBSD
   `rm /usr/local/etc/sudoers.d/deploy`
2. Remove the user and home directory:
   - Linux: `userdel -r deploy`
   - FreeBSD: `pw userdel deploy -r`
   - macOS, in this order: `dseditgroup -o edit -d deploy -t
     user com.apple.access_ssh` if it was added there, then
     `dscl . -delete /Users/deploy`, then remove
     `/Users/deploy`.
3. Ask the user to remove the CI secret.
4. Update server `memory.md` — remove deploy
   entries.
5. Log the removal per `rules/changelog.md`.
