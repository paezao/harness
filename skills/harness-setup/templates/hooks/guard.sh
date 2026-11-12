#!/usr/bin/env bash
# PreToolUse(Bash): block a short list of destructive commands outright.
# Deterministic on purpose; extend the patterns for your project.
set -u
input=$(cat)

block() {
  echo "Blocked by .claude/hooks/guard.sh: $1. Ask the developer to run it themselves if it is really intended." >&2
  exit 2
}

match() { printf '%s' "$input" | grep -Eq "$1"; }

match 'rm[[:space:]]+-[[:alpha:]]*[rR][[:alpha:]]*[fF]?[[:alpha:]]*[[:space:]]+(/|~|\$HOME|\.)([[:space:]"]|$)' \
  && block "recursive delete of /, ~ or the project root"
match 'git[[:space:]]+push[^"]*(--force([^-]|$)|--force-with-lease|[[:space:]]-f([[:space:]"]|$))' \
  && block "force push"
match 'git[[:space:]]+push[^"]*[[:space:]:](main|master|production|prod)([[:space:]"]|$)' \
  && block "direct push to a protected branch"
match 'git[[:space:]]+reset[[:space:]]+--hard' \
  && block "git reset --hard discards work"
match 'git[[:space:]]+clean[[:space:]]+-[[:alpha:]]*f' \
  && block "git clean deletes untracked files"
match 'git[[:space:]]+(commit|push)[^"]*--no-verify' \
  && block "skipping git hooks"
match '(^|[^[:alnum:]])(cat|less|more|head|tail|type)[[:space:]]+[^"]*\.env([[:space:]"]|$)' \
  && block "reading .env"
exit 0
