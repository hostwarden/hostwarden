# Class questions

The questions below sharpen the classes of
`.claude/agents/hostwarden-reviewer.md`, which says when the
reviewer reads them (→ How you work, step 5) and what a question
turns up has to meet to be a finding (→ What counts as a finding).
Each one comes from defects a review once missed; the cases in
parentheses are those defects. The reviewer reads only the sections
of the classes it goes through.

Each class holds at most twelve questions. A missed finding is
worked in as `.claude/rules/pull-requests.md` → Sharpening the
reviewer says: an existing question is widened, or two are merged,
before one is added.

## 1. A missing variant

1. Every form of one input or method: long, short, clustered and
   `=` options, deprecated and alias spellings, quoted and unquoted
   `ssh host cmd`, sibling tools of the same job, other key types,
   states, drivers, middleware front ends, search roots, both
   address families, every manager the file supports elsewhere
   (classic LXC beside Incus), each variant of a write method
   that keeps its state somewhere else (a journal, a database, an
   API backend), and every tool that opens its own connections
   (ansible, salt, parallel, pssh, a guest manager), read at every
   depth of a command line an agent writes on its own (`sudo`,
   `env`, a tool's own connection), not only the ssh family at the
   top — never a chain built to evade the guard
   (`.claude/rules/repo-release.md` → Guard findings).
2. A lookup, preflight, shortcut or substitution that decides a
   later step, or a report of what an action would do (`--check`,
   a notice): does it resolve by the same name, along the same
   path, by the condition the action itself decides by rather than
   a simpler one that agrees in the usual case (a tag's name where
   the action checks its signature), and for every address family
   that step uses — each file `ssh -G` lists, each include, the
   server split DNS, a routing domain or a scoped resolver picks,
   aliases, jump hosts, other users' endpoints, AAAA as well as A,
   the view a fixed source address matches, every maintainer
   script a package operation runs (of each version, removal
   included, not only the one named), every mount a container will
   start with rather than its image's own data directory? Can an
   input it does
   not compare still change the result, such as a Host or Match
   block, a value from an effective-configuration dump (`sshd -T`)
   included, which changes per account, address or group when read
   outside the context it is applied to? Where it lists the values
   it judges, does the list hold every value the guarded step
   overrides or reads, not only those the prompting finding named
   (HostKeyAlias beside HostName and Port)? Does an address used in
   place of a name skip the name's own routing (a jump host, a
   port)? When one side of a comparison is widened or normalised —
   a second address family, a fold to lower case — is every side?
3. A method with several forms, of which only some need a resource
   a step discovers (SSH signing with an agent key, a key file or
   a program): which forms need it, does the command that uses the
   resource decide whether it
   is available, and does a failed or sandbox-denied discovery of
   it still let the forms that do without it proceed?
4. Every name a thing has: does the step change or check every field
   a user sees as its name (hostname, display name, label), match
   every name memory knows a host by, DNS aliases included, against
   an access list on every branch and every hop, and, where a step
   changes what a connection goes by, does every later step that
   reads the connection's identity still get the one it needs?
5. A parser of text someone else writes — Markdown, a command line,
   a heredoc, a memory or topology line, an access list, a
   structured file read as text: does it follow the format for
   every construct a reader sees? CommonMark for fenced and
   indented code and HTML comments, their opening and closing
   lines, inside list items and quotes, checked against the spec;
   every layout JSON allows (a value on a line of its own); a `;`,
   `&&` or `|` inside a matched quote pair (`ssh host "a && b"`);
   every optional clause the format documents between a token and
   its delimiter, and a documented value with a space in it, an
   argument recovered from a joined command line included; a `*`
   kept as a wildcard, never word-split or globbed. Where it finds
   where a user's own words end or a suffix begins, does it key on
   line structure and the suffix's documented forms, never on
   characters the words may contain (a spaced hyphen, parentheses
   before a provenance suffix)? Does every function or
   gate that reads the same raw text — a prefilter, a fast path —
   agree on where a construct starts and ends, and is extracted
   text judged as commands only where the command receiving it
   executes it?
6. A filter that withholds free text: can the same text reach the
   output in another form — a section id, a key, an error message
   that quotes it — and does the filter print only the fields it
   names rather than withhold the ones it knows?
7. A transform meant to change only layout or to strip one kind of
   character: does every byte whose meaning depends on context
   survive it — a run of spaces inside a code span, an escape, a
   code span that stays open across a line end — and is it checked
   against how the source format encodes those characters (JSON or
   URL escapes), not only a plain-text example?
8. A step that handles one kind of change or outcome in a set: does
   it cover every kind — a record added, edited, deleted or renamed,
   a verification written for the add case — and does treating two
   alike undo what one of them accomplished (an issue closed as
   duplicate, not planned or completed)?
9. An exclusion, filter or special handling meant for one kind of
   entry: is it matched by that kind — a link, a name, an address
   range such as link-local — rather than a whole directory or an
   interface name; when an entity skips one handling because it
   takes another, do the two cover disjoint cases; and when a gate
   is wired into a new call site, can the site's value arise each
   way the gate tells apart (named by the user, chosen by
   Hostwarden)? Does an exemption for commands whose arguments are
   data leave in one that takes an option pointing it at another
   machine (`systemctl -H`)?
10. Several fact types, entry forms, models or states in one store:
    does every consumer read each type that bears on its question,
    each documented entry form of a memory line (name → dir, name
    with no memory), each state git holds a path in when a list of
    paths is built from it (staged only, beside modified in the
    tree), an explicit check for the model presented as the plain
    default, and a matched field that stores the value, not only a
    property of it such as a prefix length?
11. A list of what a step needs (a delegation, a certificate chain,
    a mail setup, the login methods a host offers): does it hold
    every record the protocol requires in the rule's own example,
    such as glue for a nameserver inside the delegated zone, and
    where the list is judged by what it lacks (no key), is it also
    checked for what the next step needs (a password method before
    a keyless host is accepted)?
12. A summary derived by comparing several hosts' fields: is the
    documented state where none of them contributes anything
    defined?

## 2. A conclusion the evidence does not carry

1. Present is not in use. Is a file, bundle or unit taken as
   running, a value on disk or in a dump as what the process uses
   now, a unit chosen because its config file exists rather than
   because systemd reports it enabled or active, a dump's object
   taken as enabled where its flag is missing? Does the probe skip
   comments and read only the files and sections the program loads
   (the PAM stack sshd includes, the domains SSSD enables), and
   establish that the daemon is configured to use a file before it
   rates its content — though not its mode, owner or place?
2. Whose it is. Does the evidence tie the fact to the object it is
   recorded for — a certificate to the key sshd pairs it with by
   content (`HostCertificate`), not by file name; an address to the
   stored range it is said to lie in, proven rather than assumed
   because only one range is recorded; a NAT upstream to its owner;
   a neighbour entry to the target rather than an intermediary
   (proxy ARP, a gateway); an ssh error line to the target host
   rather than a jump host that printed it; a relative path to the
   directory each command that uses it runs from; one host's
   observation to a whole site or range?
3. More than one candidate: two backends, managers or loggers
   active at once, where "the first one found wins" is a defect; a
   single-capture extraction (`sed -n … | head -n1`, a greedy
   regex) over text that can hold several instances; two fields
   that answer one question, where the one their source says
   decides must win and the output show that one; a fallback to
   "the first matching record" after a disambiguation that failed,
   which claims only what it shows.
4. What it leaves open. A grant is rated from the grant, not from
   `sudo -n true`, with each narrowing field read; an option
   counted as a restriction is judged by what it leaves open (an
   exclusion of loopback only, a wildcard allowlist); an option
   read as deciding is checked against the documented options that
   void it (dnsmasq's `local-service` beside `interface`,
   `except-interface`, `listen-address`, `auth-server`), with the
   lines a wrapper such as Pi-hole adds in every mode judged
   together with the one its own mode writes.
5. A match or comparison on text: is the word matched in the field
   the rule is about, not anywhere on the line where a URL, key file
   or free-text value can hold it; is a regex documented for one
   substring (a hostname label) applied to that substring; does a
   match on a compound value confirm the fact it stands for (a site
   code after a host moved); does a character class meant for one
   type (an address) reject another built from the same characters
   (a hostname), and a word of the right characters that is not the
   thing (`latest` for a version); and are both sides of a
   comparison resolved and normalised the same way (not a raw
   `ssh -G` field against a resolved name; DNS names without regard
   to case or a final dot; a stored remote URL that git rewrote on
   the way in, `insteadOf`, against the URL a user typed)?
6. A test or form borrowed from another rule — a memory label, a
   mail header, a `verified <date>` line: do its exclusions hold for
   the new question, and does the condition under which the first
   file writes the form carry over?
7. A decision list: does the "next case" a branch sends on to have
   a trigger that occurs in the state the branch leaves, and does a
   branch added for a rare case stay out of the common case it was
   carved from?
8. A check that parses a hand-written record: does it require every
   field the rule spells out, closing words included, with content
   after each label, and count distinct items rather than matches?
9. A check that fails when no item matches: does it first establish
   that there are items, where an empty set is valid? A failed read
   that leads to a create, or a lookup answered "not found": does
   the branch it lands on hold only absence, or also no access, a
   server failure and a failed read? A record that a step was announced or
   planned: is there evidence it ran before it is named as a cause?
10. A drift report that compares hosts with each other where the
    question is each host against a recorded standard: does it miss
    every host sharing the same wrong value?
11. Where an answer came from. A column or flag read as its source:
    does the tool document it as the protocol, or only as where the
    answer arrived? A second tool asked to confirm or explain a
    first one's answer (`dig` after the system resolver): does it
    ask the same server or scope — the one split DNS or a VPN's
    scoped resolver routes the name to — rather than a default? A
    probe meant to answer without credentials: can its input (a URL
    with userinfo) carry one, so the answer is the account's rather
    than the public's? Prose that offers a related field in place
    of an unavailable one (a WAN interface's address for the
    gateway's next hop): are the two normally the same value?
12. A model of what a shell command reads or writes — a pipeline
    feed judged as commands, a parser that mimics `printf`: which
    operands and inputs does the command transform
    and which does it pass as they stand (`printf` decodes escapes
    in its format and in a `%b` argument, in no other argument);
    does an operand
    (`sh script.sh`), an option or a redirection (`< file`) make
    the reader take its text from somewhere other than the stream
    attributed to it; and what does each stage between producer and
    consumer that the model leaves out (`tr`, `sed`, a quoting
    shell) do to the value on its way? For the taboo guard, only a
    feed an agent writes on its own counts, never a script file
    built to carry a command past it
    (`.claude/rules/repo-release.md` → Guard findings).

## 3. A step that reads data nothing produces

1. A privilege gate or a field a rating covers — a root-only test,
   a `sudo -n true` reused from another rule, the members of a named
   group for doas as for sudoers: does it test the command the block
   runs, or does a narrower grant report as unread what it could
   have read? Where a narrower privilege fills what a bundle
   skipped, does the step say "must" wherever the rule it serves
   does, and does each consumer that ends on a sentinel reach it?
2. A variable or pattern: is it set in the same call on every
   branch, or does it count on another file's block; which other
   commands set the same flag (a local shell as well as an SSH
   one), and do they share the behaviour it switches on; and
   what does the tool do with it unset?
3. A procedure that branches by job, mode or tier: does every job a
   caller can hand it — one carrying findings, a fix range, an
   escalation — land on a defined branch of every step, and does a
   step that starts on what a command prints (the files that made
   the tier full) have a branch for where it prints nothing?
4. A script now run on its own that another script only called: does
   the new call get the `PATH`, environment (`MISE_ENV`) and working
   directory the caller set up? A hook that starts sourcing a
   library or changes the value it accepts: does every fixture tree
   that copies the hook copy the library and set the new value, and
   does a fixture a new check reads hold a value that takes the
   check's real path, not a placeholder it skips on (`-` for
   `VERSION`)? Does a setting a call makes (a locale) reach
   each command in it that crosses into a new environment — every
   one `rules/locale.md` → Where it is set names, and `jexec` for a
   FreeBSD jail?
5. A loop that reuses one scratch file or variable, or a cleanup
   that sweeps a directory by age: is it emptied before each item,
   an item with no output included, and what else lives in the
   swept directory that must outlast the sweep (a cached login
   method beside askpass notes)?
6. A hand-off that says another flow records the answer: does that
   flow run again for this host in practice? A memory line that
   switches a behaviour on: which step writes it for every kind of
   object the behaviour reaches — a VM and a stopped guest beside a
   running container?
7. A check that fetches objects by ID from a remote, or a test that
   saves a ref and removes it: does the flow keep them reachable
   until its last run — across a squash, a force-push, a deleted
   branch — looking a removed tag up by the commit it saved rather
   than by name, and say what is due when one is gone?
8. A condition defined by lookup that a later section says an
   exception resolves, or a source added to the list a procedure
   works through: does the definition read the exception, and does
   the source hold every value the procedure reads (an installed
   version before a Tier 1 check runs on it)?
9. Every option a question or plan offers — the "no" of a yes/no,
   DHCP beside a static address, no scheme, no name typed: does each
   get its own effect and produce the value a later step reads as
   settled?
10. A value handed between functions or steps across a lossy
    transport (a shell `read` loop, a fixed-width field): does it
    reach the consumer as that consumer parses it?
11. A command that works only under one configuration value (BIND's
    `update-policy local`): does the text confirm that value before
    it runs the command? A rule that counts a write a command makes
    without naming its path (a package's post-install files under a
    protected path): which step finds those writes out before the
    command runs, and what happens where none can?
12. A step gated on an absence (no memory directory yet, nothing
    done to the target): can a mandatory earlier or concurrent step
    of the same flow, a read-only inspection or a rescue login, make
    it false first?

## 4. A contradiction with another file, or a lost safeguard

1. A blanket skip or requirement derived from a rule (read-only,
   unsupported, a marker, a check), a decision record's included,
   or a new condition on a definition the same file states (a
   priority level): does it keep the rule's exceptions and
   carve-outs, and the definition's own cases, without widening or
   narrowing them, and at the grain the rule set — a host or a
   step, where it says to carry on after a blocked one — in every
   flow that applies it? A field exempted from a comparison, such as an
   immutability check, is held to the moves the rule names, not any
   value; a field the rule empties on a transition is checked for
   its value after it, not only for a change.
2. "Every connection" or "each host" through a fixed pipeline, a
   step in a skill that assumes SSH, or a numbered step that reads
   "each changed file": does a mode that narrows the flow — local
   mode (`AGENTS.md`, `rules/first-connection.md`), a focus that
   reads only named files — reach every paragraph and every
   numbered step that repeats the broad framing?
3. A line that sorts a new kind of thing into a bucket (an override,
   a fact, a decision): does the bucket's definition, and
   `AGENTS.md`'s split between development and operations, take it?
4. A question added to a flow that runs everywhere: does every
   caller — a scheduled or `-p` run, an agent — have someone to ask,
   and what happens where nobody answers?
5. A condition that restates where a probe applies: does it copy
   the probe's rule in full, exceptions (a VM with a passed-through
   disk) included?
6. A second caller that writes a completion marker, one a fallback
   hands half of a bundled write-and-check included: does it run
   every step the marker's definition names?
7. A value another component rewrites at start (a hypervisor,
   cloud-init, DHCP): is it written in the form that component
   keeps?
8. A decision record on a two-party step (build and sign, read and
   write): does it follow the cited skill on which party does which
   half?
9. Access control and the blacklist: is the check repeated for a
   name resolved to a more specific form (a suffix, a search domain),
   for an address a new step connects by, and for each later action
   on the same host in the same run (a cleanup, a closing log line)
   against the list as it now reads?
10. A new check, or a limit on a fact, against the rules around it:
    does another rule forbid its caller to read the store it needs,
    and does calling a fact "never known" because one store cannot
    hold it contradict the principle that a value may be asked as
    well as observed?
11. An indirection across files: when a pointer sends the reader to
    B "instead of" A, does B still use A's mechanisms by name; when
    one rule reads a fact through a reference field, does a second
    rule matching that fact resolve the reference first?
12. A step that names two remedies for one defect: does a cap in the
    cited rule make one of them unreachable in every case?

## 5. A platform or privilege path left out

1. A path or source written for one platform, such as Alpine's log
   file: what does the check print where it is not written?
2. A step or form decision that names one file as where a setting
   lives: does every family keep it there, or does the family file
   name another store (`rc.conf`, `scutil`, UCI)?
3. A step reused by pointing at another step (a read-back, a
   verification): does every case that points there have its shell,
   files and tools (Windows, WSL, an appliance)?
4. `sh` syntax added to a call body (`export`, `VAR=value`): does
   the body go to `sh -s`, or to the account's login shell, which
   may be csh (`rules/os-detection.md`)? A parser that mimics a
   builtin (`echo`): which shell runs the real one (dash, bash,
   zsh), and which of that shell's options switch the behaviour it
   mimics on or off (`-e`, `xpg_echo`)?
5. A GitHub write action (reopen, edit, set a link) made a hard
   prerequisite: does a contributor working from a fork have the
   permission, or is there a fallback?
6. A capability check that reads one tool's version: is that the
   binary the feature invokes (git's `gpg.ssh.program`, ssh-keygen
   unless set), or a sibling from the same package (`ssh -V`) that
   can differ on `PATH`?
7. A file replaced through a temporary file and `mv`: which of its
   mode, owner, group and read-only state does the replacement
   keep, with each platform's `mktemp` defaults, and which did the
   old file's readers count on?

## 6. A tool that does not work as written

1. An on/off field (0/1, true/false, a flag): is it compared with
   every spelling of on and off and with its default when missing,
   rather than the tool's truthiness (jq counts `0` as true), and
   does off count as off everywhere it is read?
2. An input or placeholder required exactly once: does every
   optional branch (no revocation list, no principals file) still
   satisfy it?
3. A value filter over each field: does it accept every shape the
   product stores the field in (a list, a nested object)?
4. Two steps behind one guard: does a retry, with the first step
   now a no-op, still run the second?
5. An API that returns one status for two states (GitHub's 404 for
   "does not exist" and "no access"): does a check that
   authenticates with the credential under test tell them apart?
6. A command run for its status through `||`: does it already print
   output on the failing branch (`grep -c`, `wc`), so the fallback
   adds to it?
7. An "add" shown as the way to change a value: where the target
   can already hold one, does it append beside it rather than
   replace it?
8. An output compared literally with another value: run the
   command and read the exact bytes of one line — leading and
   trailing whitespace, blank fields — not only whether the right
   field appears.
9. Output captured to a file with `2>&1`: can stderr — a banner,
   ssh's own lines, a warning — arrive ahead of the first line or
   inside a section something parses, and does the parser read
   stdout alone where it has to?
10. A timeout or wait sized for one holder (a lock, a manager
    read): do callers queue behind each other, so the n-th waits n
    times as long and gives up while the resource is still in
    legitimate use?

## 7. A literal where a recorded value belongs

1. A default shown in an example: does the example say so?
2. A vendored or copied tool whose defaults name a path or setting:
   does the repository use that default, and does every documented
   invocation (its docstring, `--help`) work here without the flag
   the caller passes?
3. A new `Host` block or connection for an endpoint (a rescue
   system, a bridge): does it carry the port that endpoint's sshd
   listens on, or the one a reference set up for it? Where a step
   overrides only some keywords of a configuration merged from
   several sources (`ssh_config`, includes, patterns), what do the
   untouched keywords still inherit, during the override and after
   it is removed?
4. A whole block removed to retire one of its lines: does it also
   carry settings that must stay?
5. A program or path taken from the invoking user's `PATH` or
   environment for something root runs (a Bash for a root script):
   who can replace what it points to, on every OS the step covers,
   and is a trusted path required instead?
6. An environment or configuration selected for one phase of a
   command (a signing agent for the commit of `git pull`): does an
   earlier phase of the same command (the fetch, over SSH) read it
   too, and change what it authenticates with?

## 8. An identity key that is not unique or not stable

1. A key that decides two things are one (a name, an address, a
   destination): does another rule already say which extra field, a
   port or a verified key, it needs, and are both sides normalised
   the same way (case, a final dot), not only the one read at start?
2. A token or line that grants a pass (a skip, an approval, a review
   line): is it bound to this head or this pull request, and is the
   evidence it relies on bound to the exact object its fields name?
3. A value read back to detect "newer than recorded": is its stored
   granularity fine enough to tell two events apart?
4. A short identifier beside the value it abbreviates (a key tag, a
   short fingerprint): is the value compared, or only the
   identifier?
5. An ID derived from a value the store lets one owner record twice,
   or a slug that folds several characters into one: can two valid
   values collide, and does every place and loop that builds or
   references the same ID use the same scheme?

## 9. Untrusted data or a secret reaching a command or the transcript

1. An allowlist that prints a trusted tool's arguments whole: can
   one hold free text (a comment, a log prefix, a description), and
   what guards it once no keyword filter does?
2. A redaction that keeps part of a URL, or a pattern that pulls
   paths from a command line: can what it keeps carry a secret —
   userinfo, a path segment or query, an option value that only
   looks like a path — does it
   match every address form the same value can take (an scp-style
   `user@host:path` beside a URL), and is a path tested on the host
   before it is printed?
3. A read of a whole configuration or inventory dump: can it carry
   credentials or user data, does the step read only the keys it
   needs, and does a new read of a source the file already flags as
   secret-bearing reuse the file's filtered command?
4. An allowlist of fields for an appliance or config read: does
   each hold only machine-set values, or does one (a `desc`, a
   `name`, a label) hold typed text?
5. A read that selects lines by a key whose value holds typed data
   (a `local-data` record, a zone dump): does it also filter by the
   type the checks need, so a TXT token never prints?
6. A charset or length check treated as a secret filter: would a
   short alphanumeric credential pass it?
7. A file read because its name or path passed a check of form (a
   version file under a path that came from outside, read as root):
   what else can that name point to — a symlink, a credential file
   whose content happens to match the version pattern — and what
   proves the file at it is the one the check assumes, before its
   content reaches the output?

## 10. Stored state never revisited

1. A long-running reader of stored state (a watch, a daemon loop):
   does it run the expiry short-lived commands run as a side effect?
2. A value an event makes stale (a re-probe, a rename, a new login's
   agent socket): does the owning rule say to write the new value,
   and does every path that triggers the event, the automatic one
   included, reach that write? Where a written configuration
   selects a value from the environment, does it store the
   variable (`${SSH_AUTH_SOCK}`) or a snapshot of it that the next
   consumer reads stale?
3. A condition checked once before a hand-off, a verdict cached
   across several gates of one run, or a derived value stored (a
   path a script computed): what makes it true again, or derives it
   again, when what it was checked against changes — the script
   itself included — who is told, and can a cached "safe" outlive
   the state it described at the gate right before a connection?
4. A session that ends after any step: can a later one find the
   full text of each item still to act on?
5. A move or rename of a stored object: is every pointer to the old
   place rewritten, the files inside that name their own path
   included, rather than reached through a stand-in a later step
   removes?
6. An age rule on a stored date: does the run that re-checks the
   fact also move the date?
7. A cache judged fresh by mtimes (`find -newer`): does a deleted or
   renamed input make it stale?
8. A marker a crashed or denied step never clears (a lock, a
   presence entry): does its reader age it out on its own?
9. Multi-writer state read by picking a record by age or identity:
   does the code that removes records pick by the same rule?
10. A flow that moves between two machines behind one name (a rescue
    system, then the new OS): is a condition settled against the
    first used after the second has taken over?
11. A shared file written before a connection that may fail: is the
    write undone when the connection never succeeds?
12. A removal of a record kept in a store chosen per machine or per
    backend (a password in a keychain, a file store, a manager):
    does the removal empty every store that could still answer for
    it, including the one it was first written to, not only the one
    the current record names?

## 11. A failed read becoming "none" or "OK"

1. A "known" flag set before the read it vouches for, or an absence
   that decides a delete: does a failed or undecodable answer turn
   into a confident "none", or "could not ask the store" into "not
   there"?
2. A `while read` loop over a user-edited file: does it keep a last
   line with no trailing newline (`|| [ -n "$var" ]`)?
3. A status hidden by what runs after it — a remote command's
   trailer (`…; true`), an EXIT trap added under `set -e`, a
   manager's exec that returns its own status, not the guest
   command's (`qm guest exec`): does a failed action
   still reach the caller, on each failing path the script has
   (`${x:?}`, `set -u`), under macOS `/bin/sh` (bash 3.2) as well?
4. An empty answer that has several causes — no record, a server
   failure, a timeout, a setting simply not set, a neighbour entry
   that is FAILED or INCOMPLETE: does each get its own meaning, and
   its own row where the check reports rows, so silence is never
   read as confirmation?
5. Several lookups combined into one result (one per address
   family): can a failure in one hide behind a success in another?
6. A pipeline's status: whose exit status does `a | grep …` return,
   so a producer's failure (a Secrets Manager read) hides behind
   the filter; and does a helper that ends in `grep` and matches
   nothing exit 1, so that, assigned under `set -e`, its empty
   answer ends the caller?
7. A failure recorded so that a later check can see it: does the
   record survive the condition that caused the failure (a marker
   written to the same full disk), and what does the later check
   read where the record could not be written?

## 12. Side effects in the wrong order

1. A pre-flight check that a target is free: does it test the exact
   string the later write uses, after the same derivation?
2. An actor elected by listing holders and then writing its own
   mark, a counter read, checked and appended, a shared key a first
   run creates, a stale lock taken over by removing it: can two
   callers pass the check before either writes — or one remove the
   lock the other has just taken — and how soon does the loser find
   out?
3. A step that writes state a reader depends on, or a task bundled
   into the same call as a pipeline step: does an earlier step in
   the same flow already depend on it, and does a later pipeline
   step depend on the result of the step the task rides with,
   read-only tasks included?
4. A command that reaches a host through a variable or a file an
   agent plausibly writes on its own (a loop over `$h`, a bundle
   held in a variable, `GIT_SSH_COMMAND`, a script under
   `memory/tools/`): can a hook that must judge it before it runs
   (the taboo guard, the impact hook) read it, or does it see only
   the variable's name? For the taboo guard alone, a construction
   built only to evade it is no finding
   (`.claude/rules/repo-release.md` → Guard findings).
5. A flow that offers a choice (apply a community script's
   defaults, or ask first): was anything the choice covers already
   used or written before the offer, so that the "no" comes too
   late?

## 15. A claim a step breaks

1. A broken claim is dropped rather than narrowed where
   `.claude/rules/instruction-authoring.md` → Claims says; the
   finding says which.
2. A gate meant to judge a change from outside it (a required
   review, a review-record check): does the change supply the gate
   itself — its script, workflow or config?
3. A pointer — reuse a helper, "the same way X does", a mechanism
   cited by name, a promise that a question "gets asked again"
   later: does the target, read in full, do everything the sentence
   asks, with the trigger the sentence assumes, and does naming it
   leave unmentioned a check a reader must not skip?
4. "Each", "every" or "always" about a named set — every guest,
   every appliance, "across all N", several sources a value is
   always available from, every caller a gate is wired into: does
   each member's own file keep it, with no carve-out (cannot be
   entered, wrong OS, blacklisted) or documented fallback; does a
   grep of the set show N; do the names come from the skill the
   claim describes rather than a neighbouring bullet? The same
   holds for a mechanism (which client, which TLS check) as for an
   access level.
5. A decision record's absolute — every guest, every pull request
   reviewed, never posted, touched only by one process: does the
   governing rule or the feature's reference have an exception, a
   tier that skips, an alternate path (GitHub or local) or a stated
   condition?
6. One round trip that does a whole job, or a journal line for every
   actor: does every platform the page covers finish in that call,
   and does the rule's own example show a write that fails or is
   skipped?
7. What a check verifies or blocks — a missing tool that blocks the
   commit, a matcher a record's Confirmation names, a validation
   pattern beside a requirement, a counter that limits attempts:
   does it test every item the sentence covers, and the requirement
   rather than only its syntax, and does the counter move only on
   the event it limits (a password handed to ssh, not a lookup
   that found none)?
8. A new pipeline step that fires on a memory state: can a skill that
   runs the pipeline reach that state and do the same work again?
9. A plan or schedule (a cron entry, a maintenance window) read as
   proof the action is under way: does the mechanism that runs it
   need a trigger nothing confirms fired?
10. A field, fact or exit status prose reads from a command's
    output: does the command as invoked — its flags, its filter, the
    pipeline around it — produce it and carry it to the reader, in
    the order the prose reads it, checked against its code?
11. A step that claims to reject a bad value rather than guess: does
    the command it hands the value to fail loudly, or fall back to a
    default?
12. A rule that hands a read-only flow a step that edits the store
    that flow protects: is the flow's guarantee checked first?

## 16. A repository convention

1. A change that follows a cited precedent — a `/simplify` proposal
   to merge options, "as X does": does the precedent's own scope
   cover this case, such as interview options that share a
   downstream action but report different things the operator
   knows?
2. A change that adds, alters or drops an item another file lists
   by name (a recommendation, listed on
   `website/docs/running-it/tailoring/recommendations.md`): does
   that file change in the same commit
   (`.claude/rules/instruction-authoring.md` → For people and for
   the agent)?
