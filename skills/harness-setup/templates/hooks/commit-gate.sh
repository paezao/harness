#!/usr/bin/env bash
# PreToolUse(Bash|PowerShell): "no receipt, no commit".
# Commits go through .claude/harness/commit.sh, which commits exactly the tree
# verify.sh checked. This hook blocks the ways around it: plain `git commit`, and
# merges, cherry-picks, reverts and pulls that would create a commit on their own.
# It does not need to know which checkout a command targets: commit.sh runs inside
# that checkout and reads its receipt.
# Not covered: rebase, am, git aliases and commands inside script files. CI is the backstop.
set -u
input=$(cat)

lib="$(dirname "$0")/../harness/lib.sh"
if [ ! -f "$lib" ]; then
  echo "commit-gate.sh: $lib is missing, so no command was checked." >&2
  exit 1
fi
. "$lib"

block() {
  echo "Commit blocked: $1" >&2
  exit 2
}

E=$'(["\'[:space:]]|$)'
GIT='^([^[:space:]]*[/\\])?git(\.exe)?([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+'
NO_COMMIT="[[:space:]](--no-commit|-[[:alpha:]]*n[[:alpha:]]*)${E}"
STOP="[[:space:]]--(abort|quit|skip)${E}"

s=""
has() { [[ $s =~ $1 ]]; }

segments=$(printf '%s\n' "$input" | harness_command | harness_segments)

while IFS= read -r s; do
  [ -n "$s" ] || continue

  if has "${GIT}commit${E}"; then
    block "plain \`git commit\` is not used here. Run \`bash .claude/harness/commit.sh <the same arguments>\` with the Bash tool, from the checkout you are committing in. It commits exactly the files verify.sh checked."
  fi

  if has "${GIT}(merge|cherry-pick|revert)${E}"; then
    if has "[[:space:]]--continue${E}"; then
      block "finish it with \`bash .claude/harness/commit.sh\` after verify.sh passes, not with --continue."
    fi
    has "$STOP" && continue
    if has "${GIT}merge${E}"; then
      has "[[:space:]]--(no-commit|ff-only|squash)${E}" && continue
      block "\`git merge\` would create a commit nobody verified. Use \`git merge --no-commit\` (or --ff-only), run verify.sh, then commit.sh."
    fi
    has "$NO_COMMIT" && continue
    block "this would create a commit nobody verified. Add --no-commit, run verify.sh, then commit.sh."
  fi

  if has "${GIT}pull${E}"; then
    has "[[:space:]](--ff-only|--no-commit|--rebase(=[^[:space:]]*)?|-[[:alpha:]]*r[[:alpha:]]*)${E}" && continue
    # The project's own git config may already rule out merge commits.
    [ "$(git config --get pull.ff 2>/dev/null)" = only ] && continue
    case "$(git config --get pull.rebase 2>/dev/null)" in true|merges|interactive) continue ;; esac
    block "\`git pull\` may create a merge commit nobody verified. Use \`git pull --ff-only\` (or --rebase)."
  fi
done <<EOF
$segments
EOF
exit 0
