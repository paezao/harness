#!/usr/bin/env bash
# Records a verifier's verdict for exactly the current tree.
#   bash .claude/harness/review.sh PASS|BLOCK [reviewer]
# Run by the skeptic or design-skeptic as the last step of a review, never by the
# worker or the main session. In the strict profile commit.sh refuses to commit
# without a PASS whose fingerprint matches the tree, so any edit after the review
# means reviewing again.
set -u

verdict=${1:-}
case "$verdict" in
  PASS|BLOCK) ;;
  *) echo "usage: review.sh PASS|BLOCK [reviewer]" >&2; exit 2 ;;
esac

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "review: not inside a git repository." >&2; exit 1; }
cd "$root" || exit 1
. .claude/harness/lib.sh

mkdir -p .claude/receipts
{
  echo "# Review receipt"
  echo
  echo "verdict: $verdict"
  echo "fingerprint: $(harness_fingerprint)"
  echo "reviewer: ${2:--}"
  echo "time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > .claude/receipts/review.md
echo "review: $verdict recorded for the current tree"
