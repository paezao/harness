#!/usr/bin/env bash
# Runs every command in .claude/harness/acceptance, in order.
# Writes .claude/receipts/latest.md; the receipt carries the tree fingerprint
# only when every command passed. Exit code: 0 all passed, 1 otherwise.
set -u

root=$(git rev-parse --show-toplevel) || { echo "verify: not a git repo" >&2; exit 1; }
cd "$root"
. .claude/harness/lib.sh

acceptance=.claude/harness/acceptance
[ -f "$acceptance" ] || { echo "verify: missing $acceptance" >&2; exit 1; }

mkdir -p .claude/receipts
log=.claude/receipts/latest.log
receipt=.claude/receipts/latest.md
: > "$log"

status=pass
rows=""
while IFS= read -r cmd || [ -n "$cmd" ]; do
  case "$cmd" in ''|'#'*) continue ;; esac
  printf '\n=== %s\n' "$cmd" >> "$log"
  start=$(date +%s)
  bash -c "$cmd" >> "$log" 2>&1
  rc=$?
  secs=$(( $(date +%s) - start ))
  if [ "$rc" -eq 0 ]; then mark=pass; else mark="FAIL ($rc)"; status=fail; fi
  printf '%-10s %4ss  %s\n' "$mark" "$secs" "$cmd"
  rows="${rows}| \`${cmd}\` | ${mark} | ${secs}s |"$'\n'
  # Stop at the first failure; later steps usually depend on earlier ones.
  [ "$status" = fail ] && break
done < "$acceptance"

# Fingerprint after the commands ran, so formatters run by acceptance are included.
fingerprint=$(harness_fingerprint)

{
  echo "# Change receipt"
  echo
  echo "status: $status"
  [ "$status" = pass ] && echo "fingerprint: $fingerprint"
  echo "time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
  echo
  echo "| command | result | time |"
  echo "|---|---|---|"
  printf '%s' "$rows"
  echo
  echo "## Diff"
  echo
  echo '```'
  git diff HEAD --stat 2>/dev/null || true
  git ls-files --others --exclude-standard | sed 's/^/new: /'
  echo '```'
} > "$receipt"

if [ "$status" = pass ]; then
  echo "verify: all passed - receipt at $receipt"
  exit 0
fi
echo "verify: FAILED - last 40 lines of $log:" >&2
tail -n 40 "$log" >&2
exit 1
