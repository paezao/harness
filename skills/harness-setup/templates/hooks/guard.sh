#!/usr/bin/env bash
# PreToolUse(Bash|PowerShell): block a short list of destructive commands outright.
# Deterministic on purpose. It reads only the command, one simple command at a time
# (see harness_segments in lib.sh), so the same words inside a quoted string, a grep
# pattern or the tool-call description do not trigger it.
# A net for accidents, not a wall: a command hidden in a script file is not seen.
# Extend the patterns for your project.
set -u
input=$(cat)

lib="$(dirname "$0")/../harness/lib.sh"
if [ ! -f "$lib" ]; then
  echo "guard.sh: $lib is missing, so no command was checked." >&2
  exit 1
fi
. "$lib"

# Branches nobody pushes to directly.
protected='main|master|production|prod'

block() {
  echo "Blocked by .claude/hooks/guard.sh: $1. ${2:-Ask the developer to run it themselves if it is really intended.}" >&2
  exit 2
}
block_harness() {
  block "changing the harness's own files from the shell" \
    "Use the Edit or Write tool instead, so the developer is asked to approve the change."
}

# --- building blocks ------------------------------------------------------
Q=$'["\']?'                        # optional quote around an argument
E=$'(["\'[:space:]]|$)'            # end of an argument
NQ=$'[^[:space:]"\']'              # one character of an unquoted argument
CMD='^([^[:space:]]*[/\\])?'       # optional path in front of the command word
GIT="${CMD}git(\.exe)?([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+"

# Recursive deletes
RM="${CMD}(rm|rmdir|del|erase|rd|ri|Remove-Item)[[:space:]]"
RECURSIVE="[[:space:]](-[[:alnum:]]*[rR][[:alnum:]]*|--recursive)${E}"
ROOT='(([A-Za-z]:)?[/\\]\*?|[A-Za-z]:|(~|\$HOME|\$\{HOME\}|\$env:USERPROFILE|\$env:HOME|\.|\.\.)([/\\]\*?)?|\*)'
ROOT_ARG="[[:space:]]${Q}${ROOT}${Q}([[:space:]]|\$)"

# Pushes
FORCE="[[:space:]](--force|--force-with-lease(=[^[:space:]]*)?|--force-if-includes|--mirror|-[[:alpha:]]*f[[:alpha:]]*)${E}"
PLUS_REFSPEC="[[:space:]]${Q}\+[^[:space:]]"
PROTECTED_REF="[[:space:]:]${Q}(refs/heads/)?(${protected})${E}"
BARE_PUSH="push([[:space:]]+-[^[:space:]]+)*([[:space:]]+[^-[:space:]][^[:space:]]*)?([[:space:]]+-[^[:space:]]+)*[[:space:]]*\$"
HEAD_REF="[[:space:]]${Q}(HEAD|@)${E}"

# Discarding work
TREE_ARG="[[:space:]]${Q}(\.|\./|:/|\*)${Q}([[:space:]]|\$)"
DRY_RUN="[[:space:]](-[[:alpha:]]*n[[:alpha:]]*|--dry-run)${E}"
CLEAN_FORCE="[[:space:]](-[[:alpha:]]*f[[:alpha:]]*|--force)${E}"
STAGED="[[:space:]](--staged|-[[:alpha:]]*S[[:alpha:]]*)${E}"
WORKTREE="[[:space:]](--worktree|-[[:alpha:]]*W[[:alpha:]]*)${E}"

# Secret env files: .env and .env.<name>, but not the checked-in examples.
SAFE_ENV='\.env\.(example|sample|template|dist|defaults)'
ENV_FILE="\.env(\.[[:alnum:]_-]+)*"
SECRET="(^|[^[:alnum:]_.-])${ENV_FILE}${Q}([[:space:]]|\$)"
SECRET_LAST="(^|[^[:alnum:]_.-])${ENV_FILE}${Q}[[:space:]]*\$"
READER="${CMD}(cat|less|more|head|tail|type|bat|nl|tac|strings|xxd|od|hexdump|base64|cut|sort|source|\.|Get-Content|gc)(\.exe)?[[:space:]]"
SEARCHER="${CMD}(grep|egrep|fgrep|rg|ag|awk|sed|Select-String|sls)(\.exe)?[[:space:]]"
COPY_SECRET="${CMD}(cp|mv|scp|rsync|copy|move|cpi|mi|Copy-Item|Move-Item)([[:space:]]+-[^[:space:]]+)*[[:space:]]+${Q}(${NQ}*[/\\])?${ENV_FILE}${Q}[[:space:]]"
REDIRECT_SECRET="<[[:space:]]*${Q}(${NQ}*[/\\])?${ENV_FILE}${Q}([[:space:]]|\$)"

# The harness's own files: hooks, scripts, receipts and settings.
HARNESS_PATH="${NQ}*\.claude([/\\](hooks|harness|receipts|settings(\.local)?\.json)${NQ}*|[/\\]?)"
HARNESS_ARG="[[:space:]]${Q}${HARNESS_PATH}${Q}([[:space:]]|\$)"
HARNESS_LAST="[[:space:]]${Q}${HARNESS_PATH}${Q}[[:space:]]*\$"
WRITER="${CMD}(rm|rmdir|mv|chmod|chown|truncate|touch|tee|dd|del|erase|rd|ri|ren|move|copy|sc|ac|clc|ni|mi|rni|cpi|Remove-Item|Move-Item|Rename-Item|Copy-Item|Set-Content|Add-Content|Clear-Content|Out-File|New-Item)[[:space:]]"
DEST_WRITER="${CMD}(cp|install|rsync|ln)[[:space:]]"
IN_PLACE="${CMD}(sed|perl|ruby)[[:space:]]"
IN_PLACE_FLAG="[[:space:]]-[[:alpha:]]*i([^[:alpha:]]|\$)"
REDIRECT_HARNESS=">>?[[:space:]]*${Q}${HARNESS_PATH}${Q}([[:space:]]|\$)"
# After `cd .claude/harness`, a relative path is a harness file too.
IN_HARNESS_DIR='[/\\]\.claude[/\\](hooks|harness|receipts)([/\\]|$)'
REDIRECT_RELATIVE=$'>>?[[:space:]]*["\']?[^/&[:space:]"\']'

s=""
has()  { [[ $s =~ $1 ]]; }
# Same, ignoring case: PowerShell cmdlets and parameters are case-insensitive.
ihas() {
  local rc
  shopt -s nocasematch
  [[ $s =~ $1 ]]
  rc=$?
  shopt -u nocasematch
  return $rc
}

# Start where the command starts, so branch checks look at the right checkout.
cwd=$(printf '%s\n' "$input" | harness_field cwd) && [ -n "$cwd" ] && cd "$cwd" 2>/dev/null

segments=$(printf '%s\n' "$input" | harness_command | harness_segments)

while IFS= read -r s; do
  [ -n "$s" ] || continue

  # Follow `cd dir && ...` so later commands are judged in that directory.
  if [[ $s =~ ^cd[[:space:]]+(.*[^[:space:]])[[:space:]]*$ ]]; then
    dir=${BASH_REMATCH[1]}
    dir=${dir#[\"\']}
    dir=${dir%[\"\']}
    cd "$dir" 2>/dev/null
    continue
  fi

  if ihas "$RM" && has "$RECURSIVE" && ihas "$ROOT_ARG"; then
    block "recursive delete of /, ~, the project root or everything in it"
  fi

  if has "${GIT}push${E}"; then
    if has "$FORCE" || has "$PLUS_REFSPEC"; then
      block "force push"
    fi
    if has "$PROTECTED_REF" || has "[[:space:]]--all${E}"; then
      block "direct push to a protected branch"
    fi
    if has "${GIT}${BARE_PUSH}" || has "$HEAD_REF"; then
      gitdir=""
      if [[ $s =~ git(\.exe)?[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
        gitdir=${BASH_REMATCH[2]}
        gitdir=${gitdir#[\"\']}
        gitdir=${gitdir%[\"\']}
      fi
      branch=$(git ${gitdir:+-C "$gitdir"} rev-parse --abbrev-ref HEAD 2>/dev/null)
      if [[ $branch =~ ^(${protected})$ ]]; then
        block "direct push from the protected branch '$branch'"
      fi
    fi
  fi

  has "${GIT}reset[[:space:]](.*[[:space:]])?--hard${E}" \
    && block "git reset --hard discards work"
  if has "${GIT}clean${E}" && has "$CLEAN_FORCE" && ! has "$DRY_RUN"; then
    block "git clean deletes untracked files (add -n for a dry run)"
  fi
  if has "${GIT}checkout[[:space:]]" && has "$TREE_ARG"; then
    block "git checkout of the whole tree discards work"
  fi
  if has "${GIT}restore[[:space:]]" && has "$TREE_ARG"; then
    if ! has "$STAGED" || has "$WORKTREE"; then
      block "git restore of the whole tree discards work"
    fi
  fi
  has "${GIT}stash[[:space:]]+clear${E}" \
    && block "git stash clear deletes every stash"

  has "${GIT}(commit|push|merge)[[:space:]](.*[[:space:]])?--no-verify${E}" \
    && block "skipping git hooks"
  has "${GIT}commit[[:space:]](.*[[:space:]])?-[[:alpha:]]*n[[:alpha:]]*${E}" \
    && block "skipping git hooks (commit -n)"
  has "${CMD}git(\.exe)?[[:space:]](.*[[:space:]])?-c[[:space:]]+core\.hooksPath=" \
    && block "skipping git hooks"

  # Secret env files. Drop the checked-in examples first so `cp .env.example .env` passes.
  full=$s
  while [[ $s =~ $SAFE_ENV ]]; do
    s=${s/"${BASH_REMATCH[0]}"/_SAFE_}
  done
  if ihas "$READER" && has "$SECRET"; then
    block "reading a secret env file"
  fi
  if ihas "$SEARCHER" && has "$SECRET_LAST"; then
    block "reading a secret env file"
  fi
  if ihas "$COPY_SECRET" || has "$REDIRECT_SECRET"; then
    block "reading a secret env file"
  fi
  s=$full

  # The harness's own files: changing them from the shell skips the developer's approval.
  if ihas "$WRITER" && has "$HARNESS_ARG"; then
    block_harness
  fi
  if has "$DEST_WRITER" && has "$HARNESS_LAST"; then
    block_harness
  fi
  if has "$IN_PLACE" && has "$IN_PLACE_FLAG" && has "$HARNESS_ARG"; then
    block_harness
  fi
  if has "${GIT}(rm|mv)[[:space:]]" && has "$HARNESS_ARG"; then
    block_harness
  fi
  has "$REDIRECT_HARNESS" && block_harness
  if [[ $PWD =~ $IN_HARNESS_DIR ]]; then
    if ihas "$WRITER" || has "$DEST_WRITER" || has "$REDIRECT_RELATIVE" \
      || { has "$IN_PLACE" && has "$IN_PLACE_FLAG"; }; then
      block_harness
    fi
  fi
done <<EOF
$segments
EOF
exit 0
