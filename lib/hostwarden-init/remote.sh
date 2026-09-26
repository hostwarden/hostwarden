# lib/hostwarden-init/remote.sh — what bin/hostwarden-init needs to
# give the workspace a remote: the checks on its URL, the suggestion
# the question offers, and publish. Sourced by bin/hostwarden-init
# after lib/mode.sh; never run on its own. Reads CREATE, SCRIPT_DIR
# and ERRF from it.
# shellcheck shell=sh

# show <url> — <url> fit to print (hostwarden_redact); an scp-style
# address without a user, host:path, keeps only its host too.
show() {
  case $1 in
  *://*|*@*|/*|./*|../*) printf '%s\n' "$1" | hostwarden_redact ;;
  *:*) printf '%s:...\n' "${1%%:*}" ;;
  *) printf '%s\n' "$1" ;;
  esac
}

# resolve_url <url> — the address git and ssh really reach for
# <url>: git's insteadOf rewrites applied, and an ssh host alias
# replaced by the HostName the user's ssh configuration gives it,
# so a github-work alias is checked as github.com.
resolve_url() {
  ru=$(git ls-remote --get-url -- "$1" 2>/dev/null) || ru=$1
  case $ru in
  ssh://*) ru_host=$(printf '%s\n' "$ru" |
      sed -E 's#^ssh://([^/@]*@)?([^/:]+).*#\2#') ;;
  *://*|/*|./*|../*) printf '%s\n' "$ru"; return ;;
  *:*) ru_host=$(printf '%s\n' "$ru" | sed -E 's#^([^@:/]*@)?([^:/]+):.*#\2#') ;;
  *) printf '%s\n' "$ru"; return ;;
  esac
  ru_real=$(ssh -G -- "$ru_host" 2>/dev/null |
    awk '$1 == "hostname" { print $2; exit }')
  if [ -z "$ru_real" ] || [ "$ru_real" = "$ru_host" ]; then
    printf '%s\n' "$ru"; return
  fi
  ru_esc=$(printf '%s' "$ru_host" | sed 's/[].[\*^$#]/\\&/g')
  printf '%s\n' "$ru" | sed -E \
    -e "s#^(ssh://([^/@]*@)?)$ru_esc([:/])#\\1$ru_real\\3#" \
    -e "t" -e "s#^([^@:/]*@)?$ru_esc:#\\1$ru_real:#"
}

# github_slug <url> — owner/repo of a github.com URL, or nothing.
github_slug() {
  printf '%s\n' "${1%%[?#]*}" | sed -n -E \
    's#^(https://|ssh://)?([^@/]+@)?github\.com[:/]([^/]+/[^/]+)$#\3#p' |
    sed 's#\.git$##; s#/$##'
}

# anon_url <url> — where anyone could read <url> without a
# credential: its https address, with the user info, the query and
# the fragment taken out, where a token would sit. git:// is
# anonymous by design and keeps its scheme. A path on this machine
# or a mount gives nothing: nobody else reaches it.
anon_url() {
  set -- "${1%%[?#]*}"
  case $1 in
  git://*) printf '%s\n' "$1" ;;
  http://*|https://*) printf '%s\n' "$1" | sed -E 's#^(https?://)[^/@]*@#\1#' ;;
  ssh://*) printf '%s\n' "$1" |
    sed -E 's#^ssh://([^/@]*@)?([^/:]+)(:[0-9]+)?/#https://\2/#' ;;
  /*|./*|../*|file://*) ;;
  *:*) printf '%s\n' "$1" | sed -E 's#^([^@:/]*@)?([^:/]+):/?#https://\2/#' ;;
  esac
}

# readable_anonymously <url> — git can list <url> with nothing of
# the user's: no configuration, credential helper, .netrc or prompt.
# Then anyone can, and the repository is public.
readable_anonymously() {
  ra_home=$(mktemp -d) || return 1
  if (unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_SSH_COMMAND
      HOME=$ra_home XDG_CONFIG_HOME=$ra_home GIT_CONFIG_NOSYSTEM=1 \
      GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 \
      GIT_ASKPASS=false SSH_ASKPASS=false \
      git -c credential.helper= -c http.lowSpeedLimit=1 \
        -c http.lowSpeedTime=20 ls-remote -- "$1" >/dev/null 2>&1); then
    rm -rf "$ra_home"; return 0
  fi
  rm -rf "$ra_home"; return 1
}

# suggest_url — the address the question below offers for a new
# workspace: hostwarden-workspace under the account gh is signed in
# to, in the protocol gh clones with, or nothing.
suggest_url() {
  command -v gh >/dev/null 2>&1 || return 0
  su_login=$(gh api user --jq .login 2>/dev/null) || return 0
  [ -n "$su_login" ] || return 0
  su_host=github.com
  if [ "$(gh config get git_protocol -h "$su_host" 2>/dev/null)" = ssh ]; then
    echo "git@$su_host:$su_login/hostwarden-workspace.git"
  else
    echo "https://$su_host/$su_login/hostwarden-workspace.git"
  fi
}

# publish <url> — give the workspace <url> as its remote, commit it
# and push it. Refused: a remote of another address already there,
# a public repository, one that already holds commits (that is a
# workspace to join, with --clone). A missing one is created private
# where --create asks for it and gh can; otherwise the steps to
# create it are printed, and it returns 3. Run again after a
# failure, it picks up where it stopped.
publish() {
  url=$1
  cur=$(git -C memory remote get-url origin 2>/dev/null) || cur=
  if [ -n "$cur" ] && [ "$cur" != "$url" ]; then
    echo "hostwarden-init: memory/ already syncs with $(show "$cur")." >&2
    return 1
  fi
  # The hooks refuse a commit and a push unscanned once there is a
  # remote; saying so first leaves nothing half done.
  if ! command -v betterleaks >/dev/null 2>&1; then
    echo "hostwarden-init: betterleaks is not installed, and nothing leaves" >&2
    echo "  this machine unscanned. Install it" >&2
    echo "  (https://github.com/betterleaks/betterleaks) and run this again." >&2
    return 1
  fi
  hostwarden_git_batch memory

  # gh knows the visibility of a GitHub repository its account can
  # see. One it cannot see is absent or private to someone else, so
  # never public, but neither is proven: git's own read decides
  # whether it exists. Anywhere else, and wherever gh gave no
  # answer, a read without any credential is the test: what anyone
  # can list is public.
  real=$(resolve_url "$url")
  slug=$(github_slug "$real")
  vis=
  if [ -n "$slug" ] && command -v gh >/dev/null 2>&1 \
      && gh auth status --hostname github.com >/dev/null 2>&1; then
    if ! vis=$(gh repo view "$slug" --json visibility --jq .visibility \
        2>"$ERRF"); then
      if grep -q 'Could not resolve to a Repository' "$ERRF"; then
        vis=unseen
      else
        vis=
      fi
    fi
  fi
  anon=$(anon_url "$real")
  if [ "$vis" = PUBLIC ] || { [ -z "$vis" ] && [ -n "$anon" ] \
      && readable_anonymously "$anon"; }; then
    echo "hostwarden-init: $(show "$url") is public: anyone can read it, and the" >&2
    echo "  workspace holds hostnames, addresses and the layout of your" >&2
    echo "  network. Make it private or choose another, then run this again." >&2
    return 1
  fi
  if [ "$vis" = INTERNAL ]; then
    echo "hostwarden: $slug is internal: every member of its GitHub"
    echo "  enterprise can read it."
  fi

  if [ -z "$cur" ]; then
    # Only stdout lists refs: a redirect or a new host key is
    # reported on stderr, which is kept for the failure message.
    if refs=$(git ls-remote -- "$url" 2>"$ERRF"); then
      if [ -n "$refs" ]; then
        echo "hostwarden-init: $(show "$url") already holds commits. To join the" >&2
        echo "  workspace in it, use --clone; to publish this one, give an" >&2
        echo "  empty repository." >&2
        return 1
      fi
    elif [ "$vis" = unseen ] && [ -n "$CREATE" ]; then
      # gh refuses a name that exists after all, and says so.
      if ! gh repo create "$slug" --private \
          --description "Hostwarden workspace" >/dev/null 2>"$ERRF.gh"; then
        echo "hostwarden-init: gh could not create $slug:" >&2
        sed 's/^/  /' "$ERRF.gh" >&2
        echo "  What git said when reading it:" >&2
        hostwarden_redact < "$ERRF" | sed 's/^/    /' >&2
        rm -f "$ERRF.gh"
        return 1
      fi
      rm -f "$ERRF.gh"
      echo "hostwarden: created $slug on GitHub, private"
    elif [ -n "$vis" ] && [ "$vis" != unseen ]; then
      echo "hostwarden-init: $slug exists, but git cannot reach it:" >&2
      hostwarden_redact < "$ERRF" | sed 's/^/  /' >&2
      return 1
    else
      echo "hostwarden-init: $(show "$url") does not exist, or git cannot" >&2
      echo "  reach it. What git said:" >&2
      hostwarden_redact < "$ERRF" | sed 's/^/    /' >&2
      echo "  Where that names the cause — credentials, a host key, the" >&2
      echo "  network — deal with it; where the repository is missing," >&2
      echo "  create it private and empty — no README, licence or" >&2
      echo "  .gitignore. Then run this again:" >&2
      if [ -n "$slug" ]; then
        echo "    gh repo create $slug --private" >&2
        echo "  or https://github.com/new, Visibility: Private." >&2
      else
        echo "  in your git host's web interface, visibility private, or on" >&2
        echo "  a server of your own: git init --bare <path>." >&2
      fi
      return 3
    fi
    git -C memory remote add origin "$url" || return 1
  fi
  sh "$SCRIPT_DIR/hostwarden-sync" commit "Start the shared workspace" \
    || return 1
  branch=$(git -C memory symbolic-ref --short HEAD) || return 1
  if ! git -C memory push --quiet -u origin "$branch" 2>"$ERRF"; then
    hostwarden_redact < "$ERRF" >&2
    return 1
  fi
  echo "hostwarden: memory/ now syncs with $(show "$url")"
}
