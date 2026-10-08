### Security

- **The guard denies a redirect onto a computed target.** An arrow
  in the echo text of a nested remote check is a redirect to the
  shell, and the next word names the file it truncates: one such
  check printed nothing and replaced `/usr/bin/nvim` as root. A
  redirect onto a `$( )` or backtick lookup and an arrow onto any
  expansion or lookup are now blocked in every permission mode; a
  plain `> "$VAR"` stays allowed. The rules add that empty output
  from a check that must print is a finding, and that a check which
  only reads runs with the least privilege its data needs.
