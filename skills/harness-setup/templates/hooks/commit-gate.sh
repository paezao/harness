#!/usr/bin/env bash
# PreToolUse(Bash): "no receipt, no commit".
# Blocks `git commit` unless .claude/receipts/latest.md is a passing receipt
# whose fingerprint matches the current working tree.
set -u
input=$(cat)

printf '%s' "$input" | grep -Eq '(^|[^[:alnum:]_-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([^[:alnum:]-]|$)' || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root"
. .claude/harness/lib.sh

receipt=.claude/receipts/latest.md
if [ ! -f "$receipt" ]; then
  echo "Commit blocked: no change receipt. Run \`bash .claude/harness/verify.sh\` first (or /ship)." >&2
  exit 2
fi
if ! grep -q '^status: pass' "$receipt"; then
  echo "Commit blocked: the latest receipt is failing. Fix the failures, re-run verify.sh." >&2
  exit 2
fi
expected=$(sed -n 's/^fingerprint: //p' "$receipt")
actual=$(harness_fingerprint)
if [ "$expected" != "$actual" ]; then
  echo "Commit blocked: files changed since the last passing verify. Re-run \`bash .claude/harness/verify.sh\`." >&2
  exit 2
fi
exit 0
